package main

import (
	"os"

	"github.com/rdavison/messaging-service/internal/app"
	"github.com/urfave/cli/v2"
)

func main() {
	app := &cli.App{
		Name:  "messaging-svc",
		Usage: "A command line interface for messaging-svc",
		Commands: []*cli.Command{
			{
				Name:  "apiserver",
				Usage: "starts the API server",
				Action: func(c *cli.Context) error {
					app.DefaultAPIServer()
					return nil
				},
			},
			{
				Name:  "processor",
				Usage: "starts the message processor",
				Action: func(c *cli.Context) error {
					app.DefaultProcessor()
					return nil
				},
			},
		},
	}

	app.Run(os.Args)
}
