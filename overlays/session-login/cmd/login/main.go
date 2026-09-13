package main

import (
	"context"
	_ "embed"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"syscall"

	"github.com/gofrs/flock"
	"github.com/gookit/config/v2"
	"github.com/gookit/config/v2/toml"
	"github.com/rotisserie/eris"
	"github.com/shirou/gopsutil/v4/process"
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
	Proot struct {
		Bind []struct {
			HostPath      string `mapstructure:"host_path"`
			GuestLocation string `mapstructure:"guest_location"`
		} `mapstructure:"bind"`
		ExtraArgs  []string `mapstructure:"extra_args"`
		BinaryPath string   `mapstructure:"binary_path"`
	} `mapstructure:"proot"`
	LoginInnerBinaryPath string   `mapstructure:"login_inner_binary_path"`
	PendingArtifacts     []string `mapstructure:"pending_artifacts"`
}

func main() {
	defer func() {
		_ = logger.Sync()
	}()
	config.AddDriver(toml.Driver)
	cmd := &cli.Command{
		Name:  "login",
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
			if err := installPendingArtifacts(cmd.Bool("dry-run")); err != nil {
				return err
			}
			env := os.Environ()
			env = append(env, "HOME="+cfg.User.Home)
			env = append(env, "USER="+cfg.User.Name)
			env = append(env, "PROOT_TMP_DIR="+filepath.Join(cfg.InstallationDir, "tmp"))
			env = append(env, "PROOT_L2S_DIR="+filepath.Join(cfg.InstallationDir, ".l2s"))
			env = append(env, "PATH="+filepath.Join(cfg.InstallationDir, "bin"))
			target := cfg.LoginInnerBinaryPath
			if _, err := os.Stat(target); err != nil {
				return eris.Wrap(err, "failed to find target")
			}
			if _, err := os.Stat(cfg.Proot.BinaryPath); err != nil {
				return eris.Wrap(err, "failed to find proot binary")
			}
			args := []string{filepath.Base(cfg.Proot.BinaryPath)}
			for _, b := range cfg.Proot.Bind {
				if _, err := os.Stat(b.HostPath); err == nil {
					args = append(args, "-b", b.HostPath+":"+b.GuestLocation)
				}
			}
			args = append(args, cfg.Proot.ExtraArgs...)
			args = append(args, target)
			if cmd.Bool("dry-run") {
				sugar.Infof("dry-run: exec %s %s", cfg.Proot.BinaryPath, strings.Join(args, " "))
				return nil
			}
			return syscall.Exec(cfg.Proot.BinaryPath, args, env)
		},
	}
	if err := cmd.Run(context.Background(), os.Args); err != nil {
		sugar.Fatal(err)
	}
}

func installPendingArtifacts(dryRun bool) error {
	processes, err := process.Processes()
	if err != nil {
		return eris.Wrap(err, "list processes failed")
	}
	for _, proc := range processes {
		name, err := proc.Name()
		if err == nil && name == filepath.Base(cfg.Proot.BinaryPath) {
			return nil
		}
	}
	baseDir := filepath.Join(cfg.InstallationDir, "run", "nixos")
	if err := os.MkdirAll(baseDir, 0o755); err != nil {
		return eris.Wrap(err, "failed to create run/nixos directory")
	}
	if err := os.Chmod(baseDir, 0o755); err != nil {
		return eris.Wrap(err, "failed to set permissions on run/nixos directory")
	}
	sugar.Debug("Creating lock file " + filepath.Join(baseDir, "install-pending-artifacts.lock"))
	lock := flock.New(filepath.Join(baseDir, "install-pending-artifacts.lock"))
	ok, err := lock.TryLock()
	if err != nil {
		return eris.Wrap(err, "try lock failed")
	}
	if !ok {
		return eris.New("lock busy")
	}
	defer lock.Unlock()
	for _, path := range cfg.PendingArtifacts {
		newPath, targetPath := path+".new", path
		if _, err := os.Stat(newPath); err != nil {
			if errors.Is(err, os.ErrNotExist) {
				continue
			}
			return eris.Wrapf(err, "stat %s failed", newPath)
		}
		if dryRun {
			sugar.Infof("dry-run: rename %s to %s", newPath, targetPath)
		} else {
			if err := os.Rename(newPath, targetPath); err != nil {
				sugar.Errorf("rename %s to %s failed: %v", newPath, targetPath, err)
				continue
			}
		}
	}
	return nil
}
