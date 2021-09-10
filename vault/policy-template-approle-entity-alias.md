# Workflow to Templatize Vault Policies for AppRoles utilizing Entities and Aliases


## Description: In the scenario where you need to create a single Vault policy template to automatically match an an entity (Approle in this example) to a secret mount (KV in this example) using entity aliases.



## Steps:

## Step 0: Let's assume the following names for the policy, entity, and AppRole:

Policy Name: `template` 
Entity Name: `foo`
Approle Name: `bar`

## Step 1: create our entity name in the desired format

`vault write identity/entity name="foo"`

## Step 2: create our approle role

`vault write auth/approle/role/bar token_policies="template" token_ttl=72h token_max_ttl=124h`

## Step 3: Retrieve the role-id, as we need to use this as an alias on our entity


`vault read auth/approle/role/bar/role-id`

## Step 4: Add this role-id as an alias of our original entity
where name is our approle role-id and canonical_id is the id of our original entity 

```

MOUNT_ACCESSOR=$(vault auth list -format=json | jq -r '.["approle/"].accessor')

vault write identity/entity-alias name="ROLE_ID" \
        canonical_id="ENTITY_ID" \
        mount_accessor=$MOUNT_ACCESSOR
```

example:

```
vault write identity/entity-alias name="81e85331-efe2-3a6d-ad62-a7310226ed5b" \
        canonical_id="1b698db1-e89e-cb0b-6fc7-0d743507b631" \
        mount_accessor=$MOUNT_ACCESSOR
Key             Value
---             -----
canonical_id    1b698db1-e89e-cb0b-6fc7-0d743507b631
id              f307166c-d67a-1937-b8c6-430511994e79
```

## Step 5: Get our approle secret-id and login through the approle to get a token

```
 vault write -f auth/approle/role/bar/secret-id
Key                   Value
---                   -----
secret_id             e4c0586a-15c1-e49a-280b-874ae5deb5e4
secret_id_accessor    e80abfa6-3ad3-ee0d-226c-6f37a1808061
secret_id_ttl         0s


$ vault write auth/approle/login role_id="81e85331-efe2-3a6d-ad62-a7310226ed5b" \
  secret_id="e4c0586a-15c1-e49a-280b-874ae5deb5e4"
Key                     Value
---                     -----
token                   s.kaJY9zm3GDN2AjZbvt5KimEb
token_accessor          YbxuDowEMbFNKdIKbSiT3YW9
token_duration          72h
token_renewable         true
token_policies          ["default" "template"]
identity_policies       []
policies                ["default" "template"]
token_meta_role_name    bar
```

## Step 6: Review our associated policy

```
vault policy read template
path "kv/data/{{identity.entity.name}}/*" {
  capabilities = [ "create", "update", "read", "delete", "list" ]
}
```

## Step 7: Create KV/ Secret
```
 vault secrets enable -version=2 kv
 vault kv put kv/foo/apikey webapp="12344567890"
```

## Step 8: Login with Token and retrieve secret. 

```
vault login s.kaJY9zm3GDN2AjZbvt5KimEb

vault kv get kv/foo/apikey                       
====== Metadata ======
Key              Value
---              -----
created_time     2021-09-02T12:20:19.521834147Z
deletion_time    n/a
destroyed        false
version          1

===== Data =====
Key       Value
---       -----
webapp    12344567890
vault token lookup                           
Key                 Value
---                 -----
accessor            YbxuDowEMbFNKdIKbSiT3YW9
creation_time       1630584942
creation_ttl        72h
display_name        approle
entity_id           1b698db1-e89e-cb0b-6fc7-0d743507b631
expire_time         2021-09-05T12:15:42.559032475Z
explicit_max_ttl    0s
id                  s.kaJY9zm3GDN2AjZbvt5KimEb
issue_time          2021-09-02T12:15:42.559046788Z
meta                map[role_name:bar]
num_uses            0
orphan              true
path                auth/approle/login
policies            [default template]
renewable           true
ttl                 71h52m42s
type                service
```


