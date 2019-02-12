## abt-did-workshop

Simple workshop for developers to quickly develop, design and debug the DID flow.

## Initialize

```bash
make init
```

## Run 

```bash
make run
```

## Usage

1. Go to `localhost:4000` you will see a page to generate a DID. In this page you need to choose the claims you want and the algorithms to generate a DID.
2. Click the *GENERATE* button, a QR code will be displayed to you. The QR code is a JSON object that contains the callback url and a challenge signed by the secret key of the generated DID. The challenge can be decoded as:
```json
{
  "alg": "Ed25519",
  "typ": "JWT"
}
{
  "iss": "Newly generated APP DID",
  "iat": "timestamp when the challenge is signed",
  "nbf": "not before time",
  "exp": "expire time"
}
```
3. Assume that you have a wallet to parse this challenge. Specifically, the wallet should 
  1. validate if the challenge is correctly signed 
  2. generate a user DID based on the APP DID according to BIP32
4. The wallet should send a `POST` method to the callback url with following data:
```json
{
  "user_pk": "the public key of the user did",
  "challenge": "the log on challenge"
}
```
The challenge is decoded as:
```json
{
  "alg": "Ed25519 or SECP256K1",
  "typ": "JWT"
}
{
  "iss": "user_did",
  "iat": "timestamp when the challenge is signed",
  "nbf": "not before time",
  "exp": "expire time"
}
```
5. In stead of using a mobile app to send the logon request as in step 4, you can directly `curl` it like: 
```bash
curl -H "Content-Type: application/json" \
    -X POST \
    -d '{"user_pk":"5a2c9a8bbf97fc96293d03b1ecf134a6682da9b6da518ad4d7b337311cae90d2","challenge":"eyJhbGciOiJFZDI1NTE5IiwidHlwIjoiSldUIn0.eyJleHAiOiIxNTQ5NTY3NDk1IiwiaWF0IjoiMTU0OTU2NTY5NSIsImlzcyI6ImRpZDphYnQ6ejFYbUcxN3EzRFRqY3BIUEN4MlZ5ZXBhVjE2dmhDdHJkZmQiLCJuYmYiOiIxNTQ5NTY1Njk1In0.kwPUzhKt79uiOHao9tvuPrhNwSM5jeTry2laoLqbO6dVMfsQGizJqpyJ7qhVPsuwqXXZm4K_nDlc3iU8ssZGBg"}' \
    http://192.168.1.8:4000/api/logon/
```
6. After send the logon request, you will get a response like following. If you decode the above challenge, you will find the requested claims inside of it.
```json
{
  "app_pk":"15a5621ffcf7bd3aba7459b6ce4bdd5acd2f1ca0bd59d86076c32bc5ea8a180e",
  "challenge":"eyJhbGciOiJFZDI1NTE5IiwidHlwIjoiSldUIn0.eyJjYWxsYmFjayI6Imh0dHA6Ly8xOTIuMTY4LjEuOC9sb2dvbi8iLCJyZXF1ZXN0ZWQiOlt7ImlkIjoiYmlydGhkYXkiLCJ0aXRsZSI6IkJpcnRoZGF5IChtdXN0IGJlIG92ZXIgMjEpIiwidHlwZSI6ImRhdGUifSx7ImZvcm1hdCI6IiMjIy0jIy0jIyMjIiwiaWQiOiJTU04iLCJ0aXRsZSI6IlNvY2lhbCBTZWN1cml0eSBOby4iLCJ0eXBlIjoic3RyaW5nIn1dLCJleHAiOiIxNTQ5NTc4NjA3IiwiaWF0IjoiMTU0OTU3NjgwNyIsImlzcyI6ImRpZDphYnQ6ek5LRzliYmFNbVJSWHNiRW1teENITDlBZkVWazZCcUI4SFBOIiwibmJmIjoiMTU0OTU3NjgwNyJ9._soIgZ2bRa_ACqnitIzld86a3qH1rwzf67GaVmu9BZf9iaIZsYJmhzn-McQvFgNqwjtcVjZAvptiTiDPthSgCg"
}
```
7. Now render the requested claims and show them to users.
