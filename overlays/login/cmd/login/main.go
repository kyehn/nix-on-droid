package main

import (
	"context"
	_ "embed"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"

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
	User struct {
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
				Value: false,
				Usage: "show what would be done",
			},
			&cli.BoolFlag{
				Name:    "login",
				Aliases: []string{"l"},
				Value:   false,
				Usage:   "login",
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
			target := cfg.User.Shell
			if _, err := os.Stat(target); err != nil {
				return eris.New("failed to find login target")
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
