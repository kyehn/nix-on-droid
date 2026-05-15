package main

import (
	"context"
	_ "embed"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"

	"github.com/gofrs/flock"
	"github.com/gookit/config/v2"
	"github.com/gookit/config/v2/toml"
	"github.com/rotisserie/eris"
	"github.com/urfave/cli/v3"
	"go.uber.org/zap"
)

var (
	//go:embed config.toml
	configString string
	logger       *zap.Logger
	sugar        *zap.SugaredLogger
	cfg          Config
	logLevel     = zap.NewAtomicLevelAt(zap.InfoLevel)
)

func init() {
	zapConfig := zap.NewDevelopmentConfig()
	switch strings.ToLower(os.Getenv("LOG_LEVEL")) {
	case "debug":
		logLevel.SetLevel(zap.DebugLevel)
	case "info", "":
		logLevel.SetLevel(zap.InfoLevel)
	case "warn", "warning":
		logLevel.SetLevel(zap.WarnLevel)
	case "error":
		logLevel.SetLevel(zap.ErrorLevel)
	case "dpanic":
		logLevel.SetLevel(zap.DPanicLevel)
	case "panic":
		logLevel.SetLevel(zap.PanicLevel)
	case "fatal":
		logLevel.SetLevel(zap.FatalLevel)
	default:
		logLevel.SetLevel(zap.InfoLevel)
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
	User            struct {
		Name  string `mapstructure:"name"`
		Home  string `mapstructure:"home"`
		Shell string `mapstructure:"shell"`
	} `mapstructure:"user"`
	Environment []struct {
		Name  string `mapstructure:"name"`
		Value string `mapstructure:"value"`
	} `mapstructure:"environment"`
	ProcessCompose struct {
		Enable     bool     `mapstructure:"enable"`
		BinaryPath string   `mapstructure:"binary_path"`
		ConfigPath string   `mapstructure:"config_path"`
		ExtraArgs  []string `mapstructure:"extra_args"`
	} `mapstructure:"process_compose"`
	FallbackShell string `mapstructure:"fallback_shell"`
	FirstRun      struct {
		Enable      bool `mapstructure:"enable"`
		Environment []struct {
			Name  string `mapstructure:"name"`
			Value string `mapstructure:"value"`
		} `mapstructure:"environment"`
		Commands []struct {
			Argv0 string   `mapstructure:"argv0"`
			Argv  []string `mapstructure:"argv"`
		} `mapstructure:"commands"`
	} `mapstructure:"first_run"`
}

func main() {
	defer func() {
		_ = logger.Sync()
	}()
	config.AddDriver(toml.Driver)
	cmd := &cli.Command{
		Name:  "login-inner",
		Usage: "System for the initialization of NixOS",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:  "config",
				Usage: "Path to config file",
			},
			&cli.BoolFlag{
				Name:  "verbose",
				Usage: "Enable debug logging",
			},
			&cli.BoolFlag{
				Name:  "dry-run",
				Value: false,
				Usage: "show what would be done",
			},
		},
		Before: func(ctx context.Context, cmd *cli.Command) (context.Context, error) {
			if cmd.Bool("verbose") {
				logLevel.SetLevel(zap.DebugLevel)
			}
			if err := config.LoadStrings(config.Toml, configString); err != nil {
				return ctx, err
			}
			if configFile := cmd.String("config"); configFile != "" {
				if err := config.LoadFilesByFormat(config.Toml, configFile); err != nil {
					return ctx, err
				}
			}
			if err := config.BindStruct("", &cfg); err != nil {
				return ctx, err
			}
			return ctx, nil
		},
		Action: func(ctx context.Context, cmd *cli.Command) error {
			dryRun := cmd.Bool("dry-run")
			if err := os.Setenv("HOME", cfg.User.Home); err != nil {
				return err
			}
			if err := os.Setenv("USER", cfg.User.Name); err != nil {
				return err
			}
			for _, env := range cfg.Environment {
				if dryRun {
					sugar.Infof("dry-run: env %s=%s", env.Name, env.Value)
				} else {
					if err := os.Setenv(env.Name, env.Value); err != nil {
						return err
					}
				}
			}
			if cfg.ProcessCompose.Enable {
				pathValue := filepath.Dir(cfg.ProcessCompose.BinaryPath)
				if oldPath := os.Getenv("PATH"); oldPath != "" {
					pathValue += string(os.PathListSeparator) + oldPath
				}
				if err := os.Setenv("PATH", pathValue); err != nil {
					return err
				}
				processComposeArgs := []string{cfg.ProcessCompose.BinaryPath, "--config", cfg.ProcessCompose.ConfigPath, "up"}
				processComposeArgs = append(processComposeArgs, cfg.ProcessCompose.ExtraArgs...)
				if dryRun {
					sugar.Info(strings.Join(processComposeArgs, " "))
				} else {
					command := exec.Command(processComposeArgs[0], processComposeArgs[1:]...)
					command.Stdout = os.Stdout
					command.Stderr = os.Stderr
					command.Stdin = nil
					if err := command.Run(); err != nil {
						sugar.Error("run process-compose failed")
						return err
					}
				}
			}
			if cfg.FirstRun.Enable {
				if err := doFirstRun(dryRun); err != nil {
					return err
				}
			}
			target := cfg.User.Shell
			if _, err := os.Stat(target); err != nil {
				if _, err := os.Stat(cfg.FallbackShell); err == nil {
					sugar.Warn("failed to find login target, use fallback shell: " + cfg.FallbackShell)
					target = cfg.FallbackShell
				} else {
					return eris.New("failed to find login target")
				}
			}
			if dryRun {
				sugar.Info("exec: ", target)
			} else {
				return syscall.Exec(target, []string{filepath.Base(target)}, os.Environ())
			}
			return nil
		},
	}
	if err := cmd.Run(context.Background(), os.Args); err != nil {
		sugar.Fatal(err)
	}
}

func setUser(dryRun bool) error {
	currentUID := os.Getuid()
	currentGID := os.Getgid()
	passwdPath := "/etc/passwd"
	groupPath := "/etc/group"
	if _, err := os.Stat(passwdPath); err == nil {
		if dryRun {
			sugar.Infof("dry-run: replace 65534 with %d in %s", currentUID, passwdPath)
		} else {
			if err := replaceAllInFile(passwdPath, "65534", strconv.Itoa(currentUID)); err != nil {
				return eris.Wrap(err, "failed to update passwd")
			}
		}
	}
	if _, err := os.Stat(groupPath); err == nil {
		if dryRun {
			sugar.Infof("dry-run: replace 65534 with %d in %s", currentGID, groupPath)
		} else {
			if err := replaceAllInFile(groupPath, "65534", strconv.Itoa(currentGID)); err != nil {
				return eris.Wrap(err, "failed to update group")
			}
		}
	}
	if dryRun {
		sugar.Infof("dry-run: chown %s to %d:%d", cfg.User.Home, currentUID, currentGID)
	} else {
		if err := os.Chown(cfg.User.Home, currentUID, currentGID); err != nil {
			return eris.Wrap(err, "failed to chown user home")
		}
	}
	return nil
}

func replaceAllInFile(path, oldValue, newValue string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	updated := strings.ReplaceAll(string(data), oldValue, newValue)
	if updated == string(data) {
		return nil
	}
	info, err := os.Stat(path)
	if err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), filepath.Base(path)+".tmp-*")
	if err != nil {
		return err
	}
	tmpName := tmp.Name()
	defer func() {
		_ = tmp.Close()
		_ = os.Remove(tmpName)
	}()
	if _, err := tmp.WriteString(updated); err != nil {
		return err
	}
	if err := tmp.Chmod(info.Mode().Perm()); err != nil {
		return err
	}
	if err := tmp.Sync(); err != nil {
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	if err := os.Rename(tmpName, path); err != nil {
		return err
	}
	return nil
}

func doFirstRun(dryRun bool) error {
	baseDir := filepath.Join(cfg.InstallationDir, "run", "nixos")
	if err := os.MkdirAll(baseDir, 0o755); err != nil {
		return eris.Wrap(err, "failed to create run/nixos directory")
	}
	if err := os.Chmod(baseDir, 0o755); err != nil {
		return eris.Wrap(err, "failed to set permissions on run/nixos directory")
	}
	sugar.Debug("Creating lock file " + filepath.Join(baseDir, "first-run.lock"))
	lock := flock.New(filepath.Join(baseDir, "first-run.lock"))
	ok, err := lock.TryLock()
	if err != nil {
		return err
	}
	if !ok {
		return eris.New("lock busy")
	}
	defer lock.Unlock()
	for _, env := range cfg.FirstRun.Environment {
		if dryRun {
			sugar.Infof("dry-run: env %s=%s", env.Name, env.Value)
		} else {
			if err := os.Setenv(env.Name, env.Value); err != nil {
				return err
			}
		}
	}
	if err := setUser(dryRun); err != nil {
		return err
	}
	for _, commandArgs := range cfg.FirstRun.Commands {
		command := exec.Command(commandArgs.Argv0, commandArgs.Argv...)
		command.Stdout = os.Stdout
		command.Stderr = os.Stderr
		command.Stdin = nil
		if dryRun {
			sugar.Infof("dry-run: %s %s", commandArgs.Argv0, strings.Join(commandArgs.Argv, " "))
		} else {
			if err := command.Run(); err != nil {
				return eris.Wrap(err, "First run failed")
			}
		}
	}
	return nil
}
