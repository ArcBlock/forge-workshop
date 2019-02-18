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
curl http://192.168.1.8:4000/api/logon?user_did=did:abt:z1XmG17q3DTjcpHPCx2VyepaV16vhCtrdfd
```
6. After send the logon request, you will get a response like following. If you decode the above challenge, you will find the requested claims inside of it.
```json
{
  "app_pk":"572551333538aef80fa67ec6ba2a7bfe483611d0847892065d868c74fc7ea7ec","challenge":"eyJhbGciOiJFZDI1NTE5IiwidHlwIjoiSldUIn0.eyJyZXF1ZXN0ZWRDbGFpbXMiOlt7Im1ldGEiOnsiZGVzY3JpcHRpb24iOiJQbGVhc2UgcHJvdmlkZSB5b3VyIHByb2ZpbGUgaW5mb3JtYXRpb24uIn0sInBhcmFtZXRlcnMiOlsiYmlydGhkYXkiLCJmdWxsTmFtZSIsInNzbiJdLCJ0eXBlIjoicHJvZmlsZSJ9XSwicmVzcG9uc2VBdXRoIjoiaHR0cDovLzE5Mi4xNjguMS44L2FwaS9sb2dvbi8iLCJleHAiOiIxNTUwMDI1NDc2IiwiaWF0IjoiMTU1MDAyMzY3NiIsImlzcyI6ImRpZDphYnQ6ejExTFNRQzVaOG9UeVZSa05RYnNnZ2VxR1REYlgxTWsxRjhrIiwibmJmIjoiMTU1MDAyMzY3NiJ9.fmQVqtSXGKZfz2fI4r5dPCaHVu3Jg5y_EL-XJcop24UC2PlJbwXWzb7GNyKUXZgnVYocPCgsPQsom1oGlGFBBw"
}
```
7. Now render the requested claims and show them to users.

8. Send claims back
```bash
curl -H "Content-Type: application/json" -X POST -d '{"user_pk":"f5bcf626df396d566f193a5684a2d6e7df724bae4e544930d300b205021c3369","challenge":"eyJhbGciOiJFZDI1NTE5IiwidHlwIjoiSldUIn0.eyJyZXF1ZXN0ZWRDbGFpbXMiOlt7ImJpcnRoZGF5IjoiMTk5My0wOS0yNyIsImZ1bGxOYW1lIjoiQWxpY2UgWHUiLCJzc24iOiIxMjM0NTYiLCJ0eXBlIjoicHJvZmlsZSJ9XSwiZXhwIjoiMTU1MDAzNDk1OSIsImlhdCI6IjE1NTAwMzMxNTkiLCJpc3MiOiJkaWQ6YWJ0OnoxVWJMWGVXaE5YSkozRTE1YWJuVEQxcW40SmdMTEVTMnh0IiwibmJmIjoiMTU1MDAzMzE1OSJ9.9nQfpvCcM3ZbfTSggwjPXZ6NJJpZXN5iYjKMTEpkrtiMC_sqUuC0NYP4jXL9mgoGuXFCgO2ktmbi510I_7_VAg"}' http://192.168.1.8:4000/api/logon/
```
