package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
)

func main() {
	// Open the file
	file, err := os.Open("example.txt")
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close() // Ensure file is closed after use

	// Create a scanner
	scanner := bufio.NewScanner(file)

	// Read line by line
	for scanner.Scan() {
		fmt.Println(scanner.Text())
	}

	// Check for errors during scanning
	if err := scanner.Err(); err != nil {
		log.Fatal(err)
	}
}   