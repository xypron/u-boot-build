#/bin/sh

openssl req -x509 -sha256 -newkey rsa:2048 -subj /CN=TEST_PK/ -keyout PK.key \
-out PK.crt -nodes -days 365
cert-to-efi-sig-list -g '11111111-2222-3333-4444-123456789abc' PK.crt PK.esl
sign-efi-sig-list -c PK.crt -k PK.key PK PK.esl PK.auth

openssl req -x509 -sha256 -newkey rsa:2048 -subj /CN=TEST_KEK/ -keyout KEK.key \
-out KEK.crt -nodes -days 365
cert-to-efi-sig-list -g '11111111-2222-3333-4444-123456789abc' KEK.crt KEK.esl
sign-efi-sig-list -c PK.crt -k PK.key KEK KEK.esl KEK.auth

openssl req -x509 -sha256 -newkey rsa:2048 -subj /CN=TEST_db/ -keyout db.key \
-out db.crt -nodes -days 365
cert-to-efi-sig-list -g '11111111-2222-3333-4444-123456789abc' db.crt db.esl
sign-efi-sig-list -c KEK.crt -k KEK.key db db.esl db.auth

openssl req -x509 -sha256 -newkey rsa:2048 -subj /CN=TEST_dbx/ -keyout dbx.key \
-out dbx.crt -nodes -days 365
cert-to-efi-sig-list -g '11111111-2222-3333-4444-123456789abc' dbx.crt dbx.esl
sign-efi-sig-list -c KEK.crt -k KEK.key dbx dbx.esl dbx.auth
