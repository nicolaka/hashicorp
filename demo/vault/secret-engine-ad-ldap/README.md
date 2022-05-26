# Demo of AD Secret Engine using Local Vault + SAMBA AD  

### Summary

This is a simple [Vault AD Secret Engine](https://www.vaultproject.io/docs/secrets/ad) and  LDAP auth demo that can be run locally using Docker/Docker Compose. It leverages a Vault image and SAMBA as an AD Domain Controller. 


### Requirements

- Docker 
- Docker Compose
- Vault CLI

### Steps

1. Clone this repo 
2. Start the containers using Docker compose

```
$ docker compose up -d
[+] Running 7/7
 ⠿ vault Pulled                                                                                                        9.2s
   ⠿ df9b9388f04a Already exists                                                                                       0.0s
   ⠿ 2ca83227bb30 Pull complete                                                                                        0.6s
   ⠿ d4c367743969 Pull complete                                                                                        0.7s
   ⠿ 09a252e045e4 Pull complete                                                                                        7.5s
   ⠿ 12e0eadbb248 Pull complete                                                                                        7.5s
   ⠿ 4f8eb2f894be Pull complete                                                                                        7.6s
[+] Running 3/3
 ⠿ Network secret-engine-ad-ldap_default    Created                                                                    0.1s
 ⠿ Container secret-engine-ad-ldap-vault-1  Started                                                                    0.6s
 ⠿ Container secret-engine-ad-ldap-dc-1     Started                                                                    0.7s

$  docker compose ps   
NAME                            COMMAND                  SERVICE             STATUS              PORTS
secret-engine-ad-ldap-dc-1      "/bin/sh -c '/init.s…"   dc                  running             0.0.0.0:389->389/tcp, 0.0.0.0:636->636/tcp
secret-engine-ad-ldap-vault-1   "docker-entrypoint.s…"   vault               running             0.0.0.0:8200->8200/tcp

```

3. Exec into the SAMBA container and run `samba-setup.sh` scripts (manually). Alternatively, you can bake this `samba-setup.sh` script into the image by creating a new Dockerfile.

```
 docker compose exec dc /bin/sh                        
# 
# samba-tool user add vault-bind P@ssword1
samba-tool user add vault-reset P@ssword1
samba-tool group addmembers "Domain Admins" "vault-reset"

samba-tool user add Alice P@ssword1
samba-tool user add Bob P@ssword1
samba-tool user add my-application P@ssword1
samba-tool user add privileged-account P@ssword1
samba-tool group add "security"
samba-tool group addmembers "security" "Alice"

samba-tool group add "engineering"
samba-tool group addmembers "engineering" "Bob"User 'vault-bind' created successfully
# User 'vault-reset' created successfully
# Added members to group Domain Admins
# # User 'Alice' created successfully
# User 'Bob' created successfully
# User 'my-application' created successfully
# User 'privileged-account' created successfully
# Added group security
# Added members to group security
# # Added group engineering
# 

```


4. Set the Vault Address and Token Environment variables:

```
$ export VAULT_ADDR='http://0.0.0.0:8200'
$ export VAULT_TOKEN='root'
$ vault status
Key             Value
---             -----
Seal Type       shamir
Initialized     true
Sealed          false
Total Shares    1
Threshold       1
Version         1.10.1
Storage Type    inmem
Cluster Name    vault-cluster-0eae734e
Cluster ID      64135ce2-1c7c-e282-f61d-dc000549bf54
HA Enabled      false
```

5. Enabling the LDAP auth method and setting it up:

```
$ vault auth enable ldap

$ vault write auth/ldap/config \
  binddn="cn=vault-bind,cn=Users,dc=hashicorp,dc=example" \
  bindpass="P@ssword1" \
  url=ldaps://dc:636 \
  userdn="dc=hashicorp,dc=example" \
  userattr="sAMAccountName" \
  groupdn="cn=Users,dc=hashicorp,dc=example" \
  groupattr="cn" \
  insecure_tls="true"

$ vault policy write security security-policy.hcl
$ vault policy write engineering engineering-policy.hcl

$ vault write auth/ldap/groups/security policies=security
$ vault write auth/ldap/groups/engineering policies=engineering

# Testing that LDAP works  
$ vault login -method=ldap username=Alice password=P@ssword1

Key                    Value
---                    -----
token                  hvs.CAESIF239pePbDSWNnX2u9JLHC4fe_GcPW2FBaaWMsem9iW6Gh4KHGh2cy43RUNzcjBnYk02SEloalhhNEdiQmE0ZGI
token_accessor         gRQrJwDF86Gy1L5xLx88gFaF
token_duration         768h
token_renewable        true
token_policies         ["default" "security"]
identity_policies      []
policies               ["default" "security"]
token_meta_username    Alice

```

6. Password Rotation Demo


```

vault secrets enable ad

vault write ad/config \
          binddn="cn=vault-reset,cn=Users,dc=hashicorp,dc=example" \
          bindpass=P@ssword1 \
          url=ldaps://dc:636 \
          userdn="dc=hashicorp,dc=example" \
          insecure_tls=true

vault policy write my-application my-application-policy.hcl
vault write auth/ldap/groups/engineering policies=security,my-application

vault write ad/roles/my-application \
    service_account_name="my-application@hashicorp.example" \
    ttl=15s \
    max_ttl=30s

$  vault read ad/creds/my-application
Key                 Value
---                 -----
current_password    ?@09AZi6PgJzgyU8cMKWNRRx16NvNzKgUFlUiFAHO56p2pZud6IvBJXgtMEkUnT8
username            my-application

```


7. Service Acccount Check-Out Demo


``` 

$ vault write ad/library/domain-admins \
      service_account_names=privileged-account@hashicorp.example \
      ttl=1h \
      max_ttl=8h \
      disable_check_in_enforcement=false

$ vault write ad/library/domain-admins/check-out ttl=30m
Key                     Value
---                     -----
lease_id                ad/library/domain-admins/check-out/q8IIinNBajmg45mi7vlM8l89
lease_duration          30m
lease_renewable         true
password                ?@09AZzMesYtDA744DJQVZAUarHCPNElkr8BQjAb82xlzZK4YYeYomBC7w6NdgR7
service_account_name    privileged-account@hashicorp.example


# Expected to error if you try to check out a SA because there are none available.
$ vault write ad/library/domain-admins/check-out ttl=30m
Error writing data to ad/library/domain-admins/check-out: Error making API request.

URL: PUT http://0.0.0.0:8200/v1/ad/library/domain-admins/check-out
Code: 400. Errors:

* No service accounts available for check-out.

# Checking in the service account 
$ vault write -f ad/library/domain-admins/check-in

```

