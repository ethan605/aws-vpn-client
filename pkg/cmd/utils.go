package cmd

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"net"
	"os"
	"strconv"
)

func generateRandHex() (string, error) {
	bytes := make([]byte, 12)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}

	return hex.EncodeToString(bytes), nil
}

func lookupRemoteIP(remoteAddress string) (string, error) {
	remoteIPs, err := net.DefaultResolver.LookupIP(context.Background(), "ip4", remoteAddress)
	if err != nil {
		return "", err
	}

	return remoteIPs[0].String(), nil
}

func getBoolEnvOrDefault(envName string, defaultValue bool) bool {
	if envValue, ok := os.LookupEnv(envName); ok {
		if value, err := strconv.ParseBool(envValue); err == nil {
			return value
		}
	}

	return defaultValue
}

func getStringEnvOrDefault(envName string, defaultValue string) string {
	if value, ok := os.LookupEnv(envName); ok {
		return value
	}

	return defaultValue
}
