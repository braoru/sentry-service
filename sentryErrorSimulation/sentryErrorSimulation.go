package main

import (
	"crypto/aes"
	"fmt"
	"github.com/getsentry/raven-go"
	"net/http"
	"os"
)

var DSN string

func init() {
	raven.SetDSN(DSN)
}

func main() {
	fmt.Println("********************")
	fmt.Println("*   Test Sentry    *")
	fmt.Println("********************")

	testSentryFile()

	testSentryURL()

	testSentryAES()
}

func testSentryFile() {
	fmt.Println("\n\n>>>>> Open inexistant file")
	f, err := os.Open("filename.txt")
	if err != nil {
		raven.CaptureErrorAndWait(err, nil)
		fmt.Printf("Test Sentry open file:\n%s", err)
	}
	f.Close()
}

func testSentryAES() {
	fmt.Println("\n\n>>>>> Encipher with wrong AES key size")
	var key = make([]byte, 15)
	var plaintext = make([]byte, 100)
	var ciphertext = make([]byte, 100)

	var aesBlock, err = aes.NewCipher(key)
	if err != nil {
		raven.CaptureErrorAndWait(err, nil)
		fmt.Printf("Test Sentry AES:\n%s", err)
	}

	aesBlock.Encrypt(ciphertext, plaintext)
	fmt.Printf("Plaintext: %x\nCiphertext: %x\n")
}

func testSentryURL() {
	fmt.Println("\n\n>>>>> Connect to http://not.a.real.url/")

	resp, err := http.Get("http://not.a.real.url/")
	if err != nil {
		raven.CaptureErrorAndWait(err, nil)
		fmt.Printf("Test Sentry wrong URL:\n%s", err)
	}
	fmt.Println(resp)
}
