# Vault + Kubernetes Demos

This is a demo that covers the following scenarios:

- Deploying and configuraing Vault + Sidecar on K8s using Helm
- Deploying an application that fetches secrets from Vault's KV Secret Engine (Static Secrets)
- Deploying an application that fetches secrets from Vault's Database Secret Engine (Dynamic Secrets)
- Deploying Vault Secret Operater (VSO) and using it to fetch secrets to pods
- Kubernetes Auth Validation
- Integrating Vault with Cert Manager

### Assumptions

This demo assumes you have the following:

- A Kubernetes Cluster ( I'm using Docker Desktop with k8s v1.20+ with kubectl configrued)
- Helm v3.6+ installed
- Vault CLI is installed  

## Deploying and configuraing Vault + Sidecar on K8s using Helm

1. Adding the Vault Helm Chart.

```
$ helm repo add hashicorp https://helm.releases.hashicorp.com
"hashicorp" has been added to your repositories
```

2. Next, we'll install Vault plus sidecar service. Note that you can configure additional parameters using Helm [configuration options](https://developer.hashicorp.com/vault/docs/platform/k8s/helm/configuration)

```

helm install --create-namespace --namespace vault vault hashicorp/vault --set='server.dev.enabled=true' --set='injector.enabled=true'
NAME: vault
LAST DEPLOYED: Thu Jul  6 23:38:06 2023
NAMESPACE: vault
STATUS: deployed
REVISION: 1
NOTES:
Thank you for installing HashiCorp Vault!

Now that you have deployed Vault, you should look over the docs on using
Vault with Kubernetes available here:

https://www.vaultproject.io/docs/


Your release is named vault. To learn more about the release, try:

  $ helm status vault
  $ helm get manifest vault
```

3. Check if pods have been deployed successfully:

```
$ kubectl get pod -n vault                                             
NAME                                   READY   STATUS    RESTARTS   AGE
vault-0                                1/1     Running   0          19s
vault-agent-injector-574778f7c-gvkmh   1/1     Running   0          20s
```

4. Set up your local vault client to connect to Vault server that you just deployed. 

```

$ kubectl get svc -n vault  
NAME                       TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)             AGE
vault                      ClusterIP   10.96.235.33   <none>        8200/TCP,8201/TCP   113s
vault-agent-injector-svc   ClusterIP   10.99.25.76    <none>        443/TCP             113s
vault-internal             ClusterIP   None           <none>        8200/TCP,8201/TCP   113s
```

You can now use the ClusterIP for the `vault` service. In my case, it's `10.96.235.33`

```
$ export VAULT_ADDR=http://10.96.235.33:8200
$ export VAULT_TOKEN='root'
$ vault status                                        
Key             Value
---             -----
Seal Type       shamir
Initialized     true
Sealed          false
Total Shares    1
Threshold       1
Version         1.14.0
Build Date      2023-03-23T12:51:35Z
Storage Type    inmem
Cluster Name    vault-cluster-e68748a9
Cluster ID      56c546a9-774e-617c-f547-c86a60f7abfc
HA Enabled      false
```

## Deploying an application that fetches secrets from Vault's KV Secret Engine (Static Secrets)

1. Create a secret 

```
vault kv put secret/app/config username="demo" password="k8s-demo"
===== Secret Path =====
secret/data/app/config

======= Metadata =======
Key                Value
---                -----
created_time       2022-12-06T23:00:07.316550095Z
custom_metadata    <nil>
deletion_time      n/a
destroyed          false
version            1
```
3. Create a policy

```
vault policy write app - <<EOF
path "secret/data/app/config" {
capabilities = ["read"]
}
EOF
```

4. Enable & Configure Kuberentes Auth 

```
vault auth enable kubernetes

KUBE_CA_CERT=$(kubectl config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.certificate-authority-data}' | base64 --decode)
KUBE_HOST=$(kubectl config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.server}')

vault write auth/kubernetes/config \
        kubernetes_host="$KUBE_HOST" \
        kubernetes_ca_cert="$KUBE_CA_CERT"
```

5. Create a role 
```
vault write auth/kubernetes/role/app \
        bound_service_account_names=default \
        bound_service_account_namespaces=vault \
        policies=app \
        ttl=24h
```
6. Deploy the app

```
k apply -f 00-app.yaml -n vault
```

```
kubectl get pod -n vault 
NAME                                    READY   STATUS    RESTARTS   AGE
app1-6f9967f5f4-852fb                   2/2     Running   0          6s
vault-0                                 1/1     Running   0          76m
vault-agent-injector-77fd4cb69f-nstgt   1/1     Running   0          76m
```

7. Showcase that the secret was successfully fetched from Vault and was templated correctly: 

```
kubectl exec -n vault \
    $(kubectl get -n vault pod -l app=app -o jsonpath="{.items[0].metadata.name}") \
    --container app -- cat /vault/secrets/app-config.txt ; echo

postgresql://demo:k8s-demo@postgres:5432/wizard
```
----

## Deploying an application that fetches secrets from Vault's Database Secret Engine (Dynamic Secrets)

1. Deploy the application with postgres database

```
$ kubectl apply -f app-db.yaml -n vault
```

### Need to create this ro role
```
$ DB_POD=$(kubectl get -n vault pod -l app=db -o jsonpath="{.items[0].metadata.name}")
$ kubectl exec -n vault -it $DB_POD -- psql -U postgres -d postgres -p 5432
```

### Create a ro user
```
CREATE ROLE ro NOINHERIT;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO "ro";
\q
```

### Vault DB Configuration
```
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=postgres
export SERVICE_IP=$(kubectl get -n vault svc  db -o jsonpath='{.spec.clusterIP}')

vault secrets enable -path db database

vault write db/config/postgres \
     plugin_name=postgresql-database-plugin \
     connection_url="postgresql://{{username}}:{{password}}@$SERVICE_IP:5432/postgres?sslmode=disable" \
     allowed_roles=readonly \
     username="$POSTGRES_USER" \
     password="$POSTGRES_PASSWORD"
```

### (Optional) Rotating Vault Root PW
```
vault write -force db/rotate-root/postgres
```

### Vault DB Role
```
vault write db/roles/readonly \
      db_name=postgres \
      creation_statements=@readonly.sql \
      default_ttl=10m \
      max_ttl=20m
```

### Policy to allow app to access path

```
vault policy write app - <<EOF
path "secret/data/app/config" {
    capabilities = ["read"]
}
path "db/creds/readonly" {
    capabilities = ["read"]
}
EOF
```

- Verifying that the secret had been generated:

```
kubectl exec -n vault \
    $(kubectl get -n vault pod -l app=app-db -o jsonpath="{.items[0].metadata.name}") \
    --container app-db -- cat /vault/secrets/app-config.txt ; echo
password: LaDENbiOlf8Mpz-oKnhC
username: v-kubernet-readonly-8f1Xg1Pb5Mlx4jSq3Bn2-1670368659
```

- Verifying that a user had been created in the DB
```
$ DB_POD=$(kubectl get -n vault pod -l app=db -o jsonpath="{.items[0].metadata.name}")
$ kubectl exec -n vault -it $DB_POD -- psql -U postgres -d postgres -p 5432

postgres=# SELECT usename, valuntil FROM pg_user;
                       usename                       |        valuntil        
-----------------------------------------------------+------------------------
 postgres                                            | 
 v-kubernet-readonly-o7iHahoGCqxMPTHSiQ8Q-1670368832 | 2022-12-06 23:22:37+00
 v-kubernet-readonly-opZvS780gngeWVcINK7W-1670368917 | 2022-12-06 23:24:02+00
(3 rows)
```

- (Optional) Revoking Lease 

```
vault lease revoke -force -prefix lease_id=database/creds/readonly
```

### Uninstalling (Optional, don't do if you're doing the VSO section)


```
# Disable db secret engine mount first..

$ vault secrets disable db  

# Delete deployments

$ kubectl delete -f 01-app-db.yaml -n vault                                           
deployment.apps "app" deleted
deployment.apps "db" deleted
service "db" deleted
configmap "postgres-configuration" deleted
```

# Deploying Vault Secret Operater (VSO) and using it to fetch secrets to pods


1. Deploy Vault Secrets Operator using Helm

```
$ helm install vault-secrets-operator hashicorp/vault-secrets-operator --version 0.1.0 -n vault --values operator-values.yaml

```

2. Deploy the application 

```
$ kubectl apply -f 02-app-op-static.yaml -n vault
```

3. Verify that the application is deployed

```
$ kubectl get pod -n vault
NAME                                                         READY   STATUS    RESTARTS   AGE
app-64b7788bb9-n6nsw                                         2/2     Running   0          19h
app-db-7f6b5c989c-7wwjr                                      2/2     Running   0          19h
app-op-6d8df6f5c4-zgww4                                      1/1     Running   0          5m24s
db-6fd96bf59c-kx5pr                                          1/1     Running   0          19h
vault-0                                                      1/1     Running   0          19h
vault-agent-injector-5dddb46ff-9sh82                         1/1     Running   0          19h
vault-secrets-operator-controller-manager-77b654b4bf-pl8hp   2/2     Running   0          78m
```

4. The application successfully deployed and given that the secret was fetched from Vault and created as a native k8s secret we can verify like this :

```
$  kubectl get secret -n vault             
NAME                                           TYPE                 DATA   AGE
sh.helm.release.v1.vault-secrets-operator.v1   helm.sh/release.v1   1      113m
sh.helm.release.v1.vault.v1                    helm.sh/release.v1   1      20h
vault-db-app                                   Opaque               3      10m
vault-kv-app                                   Opaque               3      10s
vso-cc-storage-hmac-key                        Opaque               1      4h13m


$ kubectl get secret vault-kv-app -o jsonpath="{.data.username}" -n vault | base64 --decode
demo  
$ kubectl get secret vault-kv-app -o jsonpath="{.data.password}" -n vault | base64 --decode
k8s-demo

$ kubectl get secret vault-db-app  -o jsonpath="{.data.username}" -n vault | base64 --decode
v-kubernet-readonly-8Fmw5dOOVSu6FfcswnR5-1688765101

$ kubectl get secret vault-db-app  -o jsonpath="{.data.password}" -n vault | base64 --decode
c5tsUb-EkgBlRYjtpT6G
```

# Kubernetes Auth Validation

- Kuberenetes auth is already configured from first demo. Just need to validate that we can authenticate into vault using a k8s service account.

```
# Generating a JWT token for the app1 service account
JWT=$(kubectl create token app1 -n vault)
# Verifing that using this JWT token we can authenticate into K8s
vault write auth/kubernetes/login role=app1 jwt=$JWT
Key                                       Value
---                                       -----
token                                     hvs.CAESIGiptiMHUPgHOjh_MZAhC31Sf4Bzv45lGToKSQjmkuzcGh4KHGh2cy54SElURHV0aURRdjhXTXBoRHAyeWxwTjY
token_accessor                            u86LGCrwa3zJACZKvbR52EQA
token_duration                            24h
token_renewable                           true
token_policies                            ["app1" "default"]
identity_policies                         []
policies                                  ["app1" "default"]
token_meta_role                           app1
token_meta_service_account_name           app1
token_meta_service_account_namespace      default
token_meta_service_account_secret_name    n/a
token_meta_service_account_uid            9bef8d15-30ad-4c4b-bda2-93e098871527
```

## Integrating Vault with Cert Manager

1. Enabling and Configure PKI in Vault

```
vault secrets enable -path pki-cm pki

vault secrets tune -max-lease-ttl=8760h pki-cm

vault write pki-cm/root/generate/internal \
    common_name=example.com \
    ttl=8760h

vault write pki-cm/config/urls \
    issuing_certificates="https://vault-east-1.theneutral.zone:8200/v1/pki-cm/ca" \
    crl_distribution_points="https://vault-east-1.theneutral.zone:8200/v1/pki-cm/crl"

vault write pki-cm/roles/example-dot-com \
    allowed_domains=example.com \
    allow_subdomains=true \
    max_ttl=72h

vault policy write pki-cm - <<EOF
    path "pki-cm*"                        { capabilities = ["read", "list"] }
    path "pki-cm/roles/example-dot-com"   { capabilities = ["create", "update"] }
    path "pki-cm/sign/example-dot-com"    { capabilities = ["create", "update"] }
    path "pki-cm/issue/example-dot-com"   { capabilities = ["create"] }
EOF
Success! Uploaded policy: pki

- Enable and configure kube auth

vault write auth/kubernetes/role/issuer \
    bound_service_account_names=issuer \
    bound_service_account_namespaces=default \
    policies=pki-cm \
    ttl=20m
Success! Data written to: auth/kubernetes/role/issuer
```

2.  Deploy Cert Manager

```
# v 1.6.1

kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.6.1/cert-manager.crds.yaml

helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.6.1

kubectl get pod -n cert-manager
NAME                                       READY   STATUS    RESTARTS   AGE
cert-manager-57d89b9548-4l2dj              1/1     Running   0          31s
cert-manager-cainjector-5bcf77b697-2g56l   1/1     Running   0          31s
cert-manager-webhook-8687fc66d4-6rsfv      1/1     Running   0          31s
```

3. Congigure Certmanager

```
# Configure Issuer

kubectl create serviceaccount issuer

ISSUER_SECRET_REF=$(kubectl get serviceaccount issuer -o json | jq -r ".secrets[].name")

# Create and update vault-issuer

cat > vault-issuer.yaml <<EOF
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: vault-issuer
  namespace: default
spec:
  vault:
    server: https://vault-east-1.theneutral.zone:8200
    caBundle: "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURPekNDQWlPZ0F3SUJBZ0lVY3BRc2JxWlFVN0NQN205RUhVUmlEbU1PVWY4d0RRWUpLb1pJaHZjTkFRRUwKQlFBd0dERVdNQlFHQTFVRUF4TU5hR0Z6YUdsa1pXMXZMbU52YlRBZUZ3MHlNVEV5TURVeU1EQTVOVFZhRncwegpNVEV5TURNeU1ERXdNalJhTUJneEZqQVVCZ05WQkFNVERXaGhjMmhwWkdWdGJ5NWpiMjB3Z2dFaU1BMEdDU3FHClNJYjNEUUVCQVFVQUE0SUJEd0F3Z2dFS0FvSUJBUUN6Z3ZEUTNaK2orcFVRT3ZQU3JhY0JWZWVURFlGNkRuTEcKWEFyQzZOMjJsQ0RDWEQyZmc3dHVPWTZwZ2U1NGNSMHRmU2d1NkhBeldhUlRKR1NUNGF0bUpVNUpJbEwvM0JXbApjZmt4WDNBSUYvcFE1MGNOOGltM3hYT1JwQ3NDSExkY1I3UXNUWWFZRyswelZwYmNOSTg2UXBLY3lXakY2T0s5CjVHaVE2RmxETGFvdGRVa3k0UWx0b2UxbjRMQ3hrQ2lJS3VmTklCQ0ltNnRrcVVwWkNzZk1FaTYzbWdUdUtreUkKaFhQVlkvZENZSkNJMURGUVEvTVdXb3NyeG5kdTl5MHp0dnN3SGhUaEwrMTQ1ZFRjbXJmRzZPV2YzTlp4VFNMZwoyNTRvbm5XT1NWL0xFWVJVeXZkaGxkSFQ4TkZVSjBuS25hUTl3ZlUwWWxEZmdodXZqZ3hEQWdNQkFBR2pmVEI3Ck1BNEdBMVVkRHdFQi93UUVBd0lCQmpBUEJnTlZIUk1CQWY4RUJUQURBUUgvTUIwR0ExVWREZ1FXQkJTNEEwT1IKZXUySkVCZTViNkpKK3ZzTFBhV3FYekFmQmdOVkhTTUVHREFXZ0JTNEEwT1JldTJKRUJlNWI2SkordnNMUGFXcQpYekFZQmdOVkhSRUVFVEFQZ2cxb1lYTm9hV1JsYlc4dVkyOXRNQTBHQ1NxR1NJYjNEUUVCQ3dVQUE0SUJBUUEzCk1neUl5ZGxMU0E1Uzc0ZGd6L3EvUHVPQTNITDA2blNwWTZIL1NseHhUL3JYcjZnWnc3dWFTWmF3Zjloa0FoYlkKaE5IYVFWbG03NWNEc2kxZ0hobGg1K1o4cWtIMG44ZEp0QmVWZDVTMUFMZmhBMS9BNWpOQlNDYjVyUmlreU9SeAp4QmtiVmQyY0RZUkVLUWlPaE5iVjBzbWR3WERWYmFXNC92bHJQY0xGZkIyRTZIdUdEbGxCODhqK1ZiMFZvb05ECjAwSnI0ZXNCYldJaVc1M1NRRFQ4dWpTdTIrakxReitoTGdYTWpmdWsvZXZXemxrRENMU1J3bWtGRDdmMkkvNTQKSDY4R3ZqWUQrZjAwaVhuV3dNQnFXWlo4SitXTjFWM2ZuMCtuTGtZNjZyTHF5Q0pvR1FDVGVGbUZNdFdDMDgwVgpBUTNNZ0FET2VTQUVoMWpsMU4vMAotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0t"
    path: pki-cm/sign/example-dot-com
    auth:
      kubernetes:
        mountPath: /v1/auth/kubernetes
        role: issuer
        secretRef:
          name: issuer-token-nb6kp
          key: token

EOF

kubectl apply --filename vault-issuer.yaml


# Create app1.example.com CSR

apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-com
  namespace: default
spec:
  secretName: example-com-tls
  issuerRef:
    name: vault-issuer
  commonName: www.app1.example.com
  dnsNames:
  - www.app1.example.com

```

3. Verify Vault Issuer

```
kubectl describe issuer vault-issuer
Name:         vault-issuer
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  cert-manager.io/v1
Kind:         Issuer
Metadata:
  Creation Timestamp:  2021-12-07T02:06:22Z
  Generation:          1
  Managed Fields:
    API Version:  cert-manager.io/v1
    Fields Type:  FieldsV1
    fieldsV1:
      f:status:
        .:
        f:conditions:
    Manager:      controller
    Operation:    Update
    Time:         2021-12-07T02:06:22Z
    API Version:  cert-manager.io/v1
    Fields Type:  FieldsV1
    fieldsV1:
      f:spec:
        .:
        f:vault:
          .:
          f:auth:
            .:
            f:kubernetes:
              .:
              f:mountPath:
              f:role:
              f:secretRef:
                .:
                f:key:
                f:name:
          f:caBundle:
          f:path:
          f:server:
    Manager:         kubectl-create
    Operation:       Update
    Time:            2021-12-07T02:06:22Z
  Resource Version:  375869
  UID:               5577de0f-2d1f-4856-95b3-6832c152ab47
Spec:
  Vault:
    Auth:
      Kubernetes:
        Mount Path:  /v1/auth/kubernetes
        Role:        issuer
        Secret Ref:
          Key:   token
          Name:  issuer-token-nb6kp
    Ca Bundle:   LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURPekNDQWlPZ0F3SUJBZ0lVY3BRc2JxWlFVN0NQN205RUhVUmlEbU1PVWY4d0RRWUpLb1pJaHZjTkFRRUwKQlFBd0dERVdNQlFHQTFVRUF4TU5hR0Z6YUdsa1pXMXZMbU52YlRBZUZ3MHlNVEV5TURVeU1EQTVOVFZhRncwegpNVEV5TURNeU1ERXdNalJhTUJneEZqQVVCZ05WQkFNVERXaGhjMmhwWkdWdGJ5NWpiMjB3Z2dFaU1BMEdDU3FHClNJYjNEUUVCQVFVQUE0SUJEd0F3Z2dFS0FvSUJBUUN6Z3ZEUTNaK2orcFVRT3ZQU3JhY0JWZWVURFlGNkRuTEcKWEFyQzZOMjJsQ0RDWEQyZmc3dHVPWTZwZ2U1NGNSMHRmU2d1NkhBeldhUlRKR1NUNGF0bUpVNUpJbEwvM0JXbApjZmt4WDNBSUYvcFE1MGNOOGltM3hYT1JwQ3NDSExkY1I3UXNUWWFZRyswelZwYmNOSTg2UXBLY3lXakY2T0s5CjVHaVE2RmxETGFvdGRVa3k0UWx0b2UxbjRMQ3hrQ2lJS3VmTklCQ0ltNnRrcVVwWkNzZk1FaTYzbWdUdUtreUkKaFhQVlkvZENZSkNJMURGUVEvTVdXb3NyeG5kdTl5MHp0dnN3SGhUaEwrMTQ1ZFRjbXJmRzZPV2YzTlp4VFNMZwoyNTRvbm5XT1NWL0xFWVJVeXZkaGxkSFQ4TkZVSjBuS25hUTl3ZlUwWWxEZmdodXZqZ3hEQWdNQkFBR2pmVEI3Ck1BNEdBMVVkRHdFQi93UUVBd0lCQmpBUEJnTlZIUk1CQWY4RUJUQURBUUgvTUIwR0ExVWREZ1FXQkJTNEEwT1IKZXUySkVCZTViNkpKK3ZzTFBhV3FYekFmQmdOVkhTTUVHREFXZ0JTNEEwT1JldTJKRUJlNWI2SkordnNMUGFXcQpYekFZQmdOVkhSRUVFVEFQZ2cxb1lYTm9hV1JsYlc4dVkyOXRNQTBHQ1NxR1NJYjNEUUVCQ3dVQUE0SUJBUUEzCk1neUl5ZGxMU0E1Uzc0ZGd6L3EvUHVPQTNITDA2blNwWTZIL1NseHhUL3JYcjZnWnc3dWFTWmF3Zjloa0FoYlkKaE5IYVFWbG03NWNEc2kxZ0hobGg1K1o4cWtIMG44ZEp0QmVWZDVTMUFMZmhBMS9BNWpOQlNDYjVyUmlreU9SeAp4QmtiVmQyY0RZUkVLUWlPaE5iVjBzbWR3WERWYmFXNC92bHJQY0xGZkIyRTZIdUdEbGxCODhqK1ZiMFZvb05ECjAwSnI0ZXNCYldJaVc1M1NRRFQ4dWpTdTIrakxReitoTGdYTWpmdWsvZXZXemxrRENMU1J3bWtGRDdmMkkvNTQKSDY4R3ZqWUQrZjAwaVhuV3dNQnFXWlo4SitXTjFWM2ZuMCtuTGtZNjZyTHF5Q0pvR1FDVGVGbUZNdFdDMDgwVgpBUTNNZ0FET2VTQUVoMWpsMU4vMAotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0t
    Path:        pki-cm/sign/example-dot-com
    Server:      https://vault-east-1.theneutral.zone:8200
Status:
  Conditions:
    Last Transition Time:  2021-12-07T02:06:22Z
    Message:               Vault verified
    Observed Generation:   1
    Reason:                VaultVerified
    Status:                True
    Type:                  Ready
Events:                    <none>

```

4. Verify cert is created successfully. You can also see the cert from the Vault UI.

```
kubectl describe certificate.cert-manager example-com
Name:         example-com
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  cert-manager.io/v1
Kind:         Certificate
Metadata:
  Creation Timestamp:  2021-12-07T02:06:27Z
  Generation:          2
  Managed Fields:
    API Version:  cert-manager.io/v1
    Fields Type:  FieldsV1
    fieldsV1:
      f:spec:
        .:
        f:issuerRef:
          .:
          f:name:
        f:secretName:
    Manager:      kubectl-create
    Operation:    Update
    Time:         2021-12-07T02:06:27Z
    API Version:  cert-manager.io/v1
    Fields Type:  FieldsV1
    fieldsV1:
      f:spec:
        f:privateKey:
      f:status:
        .:
        f:conditions:
        f:notAfter:
        f:notBefore:
        f:renewalTime:
        f:revision:
    Manager:      controller
    Operation:    Update
    Time:         2021-12-07T02:08:19Z
    API Version:  cert-manager.io/v1
    Fields Type:  FieldsV1
    fieldsV1:
      f:metadata:
        f:annotations:
          .:
          f:kubectl.kubernetes.io/last-applied-configuration:
      f:spec:
        f:commonName:
        f:dnsNames:
    Manager:         kubectl-client-side-apply
    Operation:       Update
    Time:            2021-12-07T02:08:19Z
  Resource Version:  376161
  UID:               708b18dd-4422-44e7-ab1f-b3eb3120d6ae
Spec:
  Common Name:  www.app1.example.com
  Dns Names:
    www.app1.example.com
  Issuer Ref:
    Name:       vault-issuer
  Secret Name:  example-com-tls
Status:
  Conditions:
    Last Transition Time:  2021-12-07T02:08:20Z
    Message:               Certificate is up to date and has not expired
    Observed Generation:   2
    Reason:                Ready
    Status:                True
    Type:                  Ready
  Not After:               2021-12-10T02:08:19Z
  Not Before:              2021-12-07T02:07:49Z
  Renewal Time:            2021-12-09T02:08:09Z
  Revision:                2
Events:
  Type    Reason     Age                From          Message
  ----    ------     ----               ----          -------
  Normal  Issuing    43m                cert-manager  Issuing certificate as Secret does not exist
  Normal  Generated  42m                cert-manager  Stored new private key in temporary Secret resource "example-com-9x6pc"
  Normal  Requested  42m                cert-manager  Created new CertificateRequest resource "example-com-fnc5b"
  Normal  Issuing    41m                cert-manager  Fields on existing CertificateRequest resource not up to date: [spec.commonName spec.dnsNames]
  Normal  Reused     41m                cert-manager  Reusing private key stored in existing Secret resource "example-com-tls"
  Normal  Requested  41m                cert-manager  Created new CertificateRequest resource "example-com-6kf2v"
  Normal  Issuing    41m (x2 over 42m)  cert-manager  The certificate has been successfully issued
```

## Deploying Vault Secret Operator




## References

- https://learn.hashicorp.com/tutorials/vault/kubernetes-external-vault?in=vault/kubernetes
- https://learn.hashicorp.com/tutorials/vault/kubernetes-cert-manager?in=vault/kubernetes#configure-an-issuer-and-generate-a-certificate
