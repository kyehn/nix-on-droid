package main

import (
	"context"
	_ "embed"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/gofrs/flock"
	"github.com/gookit/config/v2"
	"github.com/gookit/config/v2/toml"
	"github.com/rotisserie/eris"
	"github.com/urfave/cli/v3"
	"go.uber.org/zap"
)

//go:embed config.toml
var configString string

var (
	logger   *zap.Logger
	sugar    *zap.SugaredLogger
	cfg      Config
	logLevel = zap.NewAtomicLevelAt(zap.InfoLevel)
)

func init() {
	zapConfig := zap.NewDevelopmentConfig()
	if os.Getenv("STC_DEBUG") != "" {
		logLevel.SetLevel(zap.DebugLevel)
	}
	zapConfig.Level = logLevel
	var err error
	logger, err = zapConfig.Build()
	if err != nil {
		panic(err)
	}
	sugar = logger.Sugar()
}

type Config struct {
	InstallationDir string `mapstructure:"installation_dir"`
	ProcessCompose  struct {
		Enable     bool     `mapstructure:"enable"`
		BinaryPath string   `mapstructure:"binary_path"`
		ConfigPath string   `mapstructure:"config_path"`
		ExtraArgs  []string `mapstructure:"extra_args"`
	} `mapstructure:"process_compose"`
}

func main() {
	defer func() {
		_ = logger.Sync()
	}()
	config.AddDriver(toml.Driver)
	err := config.LoadStrings(config.Toml, configString)
	if err != nil {
		sugar.Fatal(err)
	}
	err = config.BindStruct("", &cfg)
	if err != nil {
		sugar.Fatal(err)
	}
	cmd := &cli.Command{
		Name:  "switch-to-configuration",
		Usage: "NixOS switch-to-configuration program",
		Commands: []*cli.Command{
			{
				Name:   "switch",
				Usage:  "make the configuration the boot default and activate now",
				Action: doSystemSwitch,
			},
			{
				Name:   "dry-activate",
				Usage:  "show what would be done if this configuration were activated",
				Action: doSystemSwitch,
			},
			{
				Name:   "boot",
				Usage:  "make the configuration the boot default",
				Action: unsupportedAction,
			},
			{
				Name:   "test",
				Usage:  "activate the configuration, but don't make it the boot default",
				Action: unsupportedAction,
			},
			{
				Name:   "check",
				Usage:  "run pre-switch checks and exit",
				Action: unsupportedAction,
			},
		},
	}
	if err = cmd.Run(context.Background(), os.Args); err != nil {
		sugar.Fatal(err)
	}
}

func unsupportedAction(ctx context.Context, cmd *cli.Command) error {
	return eris.New("unsupported action: " + cmd.Name)
}

func doSystemSwitch(ctx context.Context, cmd *cli.Command) error {
	sugar.Info("Using action: ", cmd.Name)
	if err := os.Setenv("NIXOS_ACTION", cmd.Name); err != nil {
		return err
	}
	sugar.Info("Performing system switch")
	toplevel := filepath.FromSlash(os.Getenv("TOPLEVEL"))
	if toplevel == "" {
		exePath, err := os.Executable()
		if err != nil {
			return eris.New("failed to get executable path")
		}
		exePath, err = filepath.Abs(exePath)
		if err != nil {
			return eris.New("failed to get absolute path")
		}
		base := filepath.Base(exePath)
		if base != "switch-to-configuration" {
			return eris.New("failed to find switch-to-configuration")
		}
		binDir := filepath.Dir(exePath)
		if filepath.Base(binDir) != "bin" {
			return eris.New("switch-to-configuration is not inside bin/")
		}
		toplevel = filepath.Dir(binDir)
	}
	path := filepath.Join(cfg.InstallationDir, "run", "current-system")
	_, err := os.Stat(path)
	if err == nil {
		oldToplevel := path
		if realPath, err := filepath.EvalSymlinks(path); err == nil {
			oldToplevel = realPath
		}
		sugar.Infof("old toplevel path: %s", oldToplevel)
	}
	action := cmd.Name
	dryRun := action == "dry-activate"
	baseDir := filepath.Join(cfg.InstallationDir, "run", "nixos")
	if err := os.MkdirAll(baseDir, 0o755); err != nil {
		return eris.Wrap(err, "failed to create run/nixos directory")
	}
	if err := os.Chmod(baseDir, 0o755); err != nil {
		return eris.Wrap(err, "failed to set permissions on run/nixos directory")
	}
	sugar.Debug("Creating lock file " + filepath.Join(baseDir, "switch-to-configuration.lock"))
	lock := flock.New(filepath.Join(baseDir, "switch-to-configuration.lock"))
	ok, err := lock.TryLock()
	if err != nil {
		return err
	}
	if !ok {
		return eris.New("lock busy")
	}
	defer lock.Unlock()
	command := exec.Command("nix-env", "--profile", "/nix/var/nix/profiles/system", "--set", toplevel)
	command.Stdout = os.Stdout
	command.Stderr = os.Stderr
	command.Stdin = nil
	if dryRun {
		sugar.Info("exec command: ", command.String())
	} else {
		if err := command.Run(); err != nil {
			sugar.Error("set profile failed")
			return err
		}
	}
	if !dryRun {
		if err := symlinkForceSafe(toplevel, filepath.Join(cfg.InstallationDir, "run", "current-system")); err != nil {
			sugar.Error("set /run/current-system failed")
			return err
		}
		if err := symlinkForceSafe(toplevel, filepath.Join(cfg.InstallationDir, "run", "booted-system")); err != nil {
			sugar.Error("set /run/booted-system failed")
			return err
		}
		if err := os.MkdirAll("/nix/var/nix/gcroots", 0o755); err != nil {
			return eris.Wrap(err, "failed to create /nix/var/nix/gcroots directory")
		}
		if err := symlinkForceSafe(toplevel, "/nix/var/nix/gcroots/current-system"); err != nil {
			sugar.Error("set /nix/var/nix/gcroots/current-system failed")
			return err
		}
		if err := os.MkdirAll(filepath.Join(cfg.InstallationDir, "var", "empty"), 0o555); err != nil {
			return eris.Wrap(err, "failed to create /var/empty directory")
		}
		if err := os.Chmod(filepath.Join(cfg.InstallationDir, "var/empty"), 0o555); err != nil {
			return eris.Wrap(err, "failed to set permissions on /var/empty directory")
		}
	}
	if cfg.ProcessCompose.Enable {
		processComposeArgs := []string{cfg.ProcessCompose.BinaryPath, "--config", cfg.ProcessCompose.ConfigPath, "up"}
		processComposeArgs = append(processComposeArgs, cfg.ProcessCompose.ExtraArgs...)
		if dryRun {
			processComposeArgs = append(processComposeArgs, "--dry-run")
			sugar.Info("exec command: ", strings.Join(processComposeArgs, " "))
		}
		command := exec.Command(processComposeArgs[0], processComposeArgs[1:]...)
		pathEnv := filepath.Dir(cfg.ProcessCompose.BinaryPath)
		if currentPath := os.Getenv("PATH"); currentPath != "" {
			pathEnv += string(os.PathListSeparator) + currentPath
		}
		command.Env = append(os.Environ(), "PATH="+pathEnv)
		command.Stdout = os.Stdout
		command.Stderr = os.Stderr
		command.Stdin = nil
		if err := command.Run(); err != nil {
			sugar.Error("run process-compose failed")
			return err
		}
	}
	sugar.Info("finished switching to system configuration")
	return nil
}

func symlinkForceSafe(target, link string) error {
	if file, err := os.Lstat(link); err == nil {
		if file.Mode()&os.ModeSymlink != 0 || !file.IsDir() {
			if err := os.Remove(link); err != nil {
				return err
			}
		} else {
			return eris.New("cannot overwrite directory: " + link)
		}
	} else if !os.IsNotExist(err) {
		return err
	}
	return os.Symlink(target, link)
}
