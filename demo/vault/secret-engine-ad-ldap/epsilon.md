# Epsilon Demo Workflow

---------
Demo Workflow

- Setup
- Enabling LDAP Auth Method
```
 vault auth enable ldap
 vault write auth/ldap/config \
  binddn="cn=vault-bind,cn=Users,dc=hashicorp,dc=com" \
  bindpass="P@ssword1" \
  url=ldaps://dc:636 \
  userdn="dc=hashicorp,dc=com" \
  userattr="sAMAccountName" \
  groupdn="cn=Users,dc=hashicorp,dc=com" \
  groupattr="cn" \
  username_as_alias="true" \
  insecure_tls="true"
```

- Enabling LDAP Secret Engine

```
vault secrets enable ldap

vault write ldap/config \
          binddn="cn=vault-reset,cn=Users,dc=hashicorp,dc=com" \
          bindpass="P@ssword1" \
          url=ldaps://dc:636 \
          userdn="dc=hashicorp,dc=com" \
          userattr="sAMAccountName" \
          groupdn="cn=Users,dc=hashicorp,dc=com" \
          groupattr="cn" \
          insecure_tls=true \
          schema=ad \
          password_policy=default


vault write sys/policies/password/default policy=@password-policy.hcl   

vault policy write windows-admins windows-admins.hcl
vault write auth/ldap/groups/windows-admins policies=windows-admins





```

- Alice is a Domain SysAdmin and wants to check out a service account for 4 hours
  -> LDAP Secret Engine Service Account Check Out Library

```
vault write ldap/library/domain-admins \
      service_account_names="domain-admin-1,domain-admin-2" \
      ttl=4h \
      max_ttl=8h \
      disable_check_in_enforcement=false

vault write ldap/library/domain-admins/check-out ttl=30m

```

- Alice is a Windows SysAdmin and wants to retieve her AD password.
  -> LDAP Secret Engine Password Retrievel


```
vault write ldap/static-role/alice \
   dn='cn=alice,cn=Users,dc=hashicorp,dc=com' \
   username="alice" \
   rotation_period="24h"

vault write ldap/static-role/dave \
   dn='cn=alice,cn=Users,dc=hashicorp,dc=com' \
   username="dave" \
   rotation_period="24h"

vault read ldap/static-cred/alice
```


- Alice is a Windows SysAdmin and wants to rotate her AD password.
  -> LDAP Secret Engine Password Rotation

vault read ldap/static-cred/alice
vault read ldap/rotate-role/alice


- Alice is a Windows SysAdmin and wants to retrieve Windows account credentials for a specific Windows machine.
-> KV Secret Engine storing the credentials of the Windows machine (Local Account)

- Bob is a Linux SysAdmin and wants to retrieve the Linux SSH keys for a specific Linux Machine. (Local Account)
-> SSH Secret Engine



WORKING



$ vault policy write security security-policy.hcl
$ vault policy write engineering engineering-policy.hcl

$ vault write auth/ldap/groups/security policies=security
$ vault write auth/ldap/groups/engineering policies=engineering

# Testing that LDAP works  
$ vault login -method=ldap username=Alice password=P@ssword1





vault write ldap/config \
          binddn="cn=vault-reset,cn=Users,dc=hashicorp,dc=example" \
          bindpass="P@ssword1" \
          url=ldaps://dc:636 \
          userdn="dc=hashicorp,dc=example" \
          userattr="sAMAccountName" \
          groupdn="cn=Users,dc=hashicorp,dc=example" \
          groupattr="cn" \
          insecure_tls=true \
          schema=ad \
          password_policy=default


vault write ldap/static-role/Alice \
   dn='cn=Alice,cn=Users,dc=hashicorp,dc=example' \
   username="Alice" \
   rotation_period="24h"