package main

import (
	"log"

	"github.com/ethan605/aws-vpn-client/pkg/cmd"
)

func main() {
	cmd := cmd.ParseConfigs()
	err := cmd.ConnectVPN()

	if err != nil {
		log.Fatal(err)
	}
}
