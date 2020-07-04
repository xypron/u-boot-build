#!/bin/sh

GUID='11111111-2222-3333-4444-123456789abc'
HELLOPATH=../denx/lib/efi_loader/helloworld.efi
PREPPATH=prepare

rm -rf $PREPPATH
mkdir $PREPPATH
cd $PREPPATH

openssl req -x509 -sha256 -newkey rsa:2048 -subj /CN=TEST_PK/ -keyout PK.key \
  -out PK.crt -nodes -days 365
cert-to-efi-sig-list -g $GUID PK.crt PK.esl
sign-efi-sig-list -t "2020-04-01" -c PK.crt -k PK.key PK PK.esl PK.auth

touch PK_null.esl
sign-efi-sig-list -t "2020-04-02" -c PK.crt -k PK.key PK PK_null.esl \
  PK_null.auth

openssl req -x509 -sha256 -newkey rsa:2048 -subj /CN=TEST_KEK/ -keyout KEK.key \
  -out KEK.crt -nodes -days 365
cert-to-efi-sig-list -g $GUID KEK.crt KEK.esl
sign-efi-sig-list -t "2020-04-03" -c PK.crt -k PK.key KEK KEK.esl KEK.auth

openssl req -x509 -sha256 -newkey rsa:2048 -subj /CN=TEST_db/ -keyout db.key \
  -out db.crt -nodes -days 365
cert-to-efi-sig-list -g $GUID db.crt db.esl
sign-efi-sig-list -t "2020-04-04" -c KEK.crt -k KEK.key db db.esl db.auth

openssl req -x509 -sha256 -newkey rsa:2048 -subj /CN=TEST_db1/ -keyout db1.key \
  -out db1.crt -nodes -days 365
cert-to-efi-sig-list -g $GUID db1.crt db1.esl
sign-efi-sig-list -t "2020-04-05" -c KEK.crt -k KEK.key db db1.esl db1.auth

sign-efi-sig-list -t "2020-04-06" -a -c KEK.crt -k KEK.key db db1.esl \
  db1-update.auth

openssl req -x509 -sha256 -newkey rsa:2048 -subj /CN=TEST_dbx/ -keyout dbx.key \
  -out dbx.crt -nodes -days 365
cert-to-efi-sig-list -g $GUID dbx.crt dbx.esl
sign-efi-sig-list -t "2020-04-05" -c KEK.crt -k KEK.key dbx dbx.esl dbx.auth

cp $HELLOPATH .

sbsign --key db.key --cert db.crt helloworld.efi
hash-to-efi-sig-list helloworld.efi db_hello.hash
sign-efi-sig-list -t "2020-04-07" -c KEK.crt -k KEK.key db db_hello.hash \
  db_hello.auth

cd ..

virt-make-fs --partition=gpt -s +1M -t vfat $PREPPATH sandbox.img
rm -rf $PREPPATH
