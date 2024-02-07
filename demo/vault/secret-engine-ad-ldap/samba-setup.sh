#!/bin/sh

set -e

sleep 5

samba-tool user add vault-bind P@ssword1
samba-tool user add vault-reset P@ssword1
samba-tool group addmembers "Domain Admins" "vault-reset"

samba-tool user add Alice P@ssword1
samba-tool user add Bob P@ssword1
samba-tool user add my-application P@ssword1
samba-tool user add privileged-account P@ssword1
samba-tool group add "security"
samba-tool group addmembers "security" "Alice"

samba-tool group add "engineering"
samba-tool group addmembers "engineering" "Bob"

exit 0 