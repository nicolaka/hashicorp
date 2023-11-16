
#auth_ldap_ca6f4819
#identity.entity.aliases.auth_ldap_ca6f4819.name
# Grant access to active directory (ad) secret engine
path "ldap/static-role"
{
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "ldap/role"
{
  capabilities = ["create", "read", "update", "delete", "list"]
}
# Grant access to active directory (ad) secret engine
path "ldap/static-cred/{{identity.entity.aliases.auth_ldap_ca6f4819.name}}"
{
  capabilities = ["read"]
}

# Grant access to active directory (ad) secret engine
path "ldap/static-role/{{identity.entity.aliases.auth_ldap_ca6f4819.name}}"
{
  capabilities = [ "read", "list"]
}

path "ldap/rotate-role/{{identity.entity.aliases.auth_ldap_ca6f4819.name}}"
{
  capabilities = ["create", "update"]
}


# Grant access to active directory (ad) secret engine
path "ldap/library/*"
{
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "ldap/library/domain-admins"
{
  capabilities = ["create", "read", "update", "delete", "list"]
}

# List, create, update, and delete key/value secrets
path "windows-local-accounts/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}