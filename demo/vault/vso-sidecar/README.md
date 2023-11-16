# Deploying VSO + Sidecar on Openshift/K8s


0. Ensure that the kubernetes cluster has no previos deployments of vault or VSO, including no pods, secrets, clusterroles, clusterrolebindings..etc 

1. Create a kubernetes namespace

```
kubectl create namespace vso
```

2. Create a vault namespace

```
vault namespace create vso
```

3. Export the following 

```
export TF_VAR_vault_namespace="vso";
export TF_VAR_vault_public_address="https://vault.hashicorp.cloud:8200";
export TF_VAR_vault_admin_token="XXXXXXX";
export TF_VAR_kubernetes_endpoint="https://kubernetes.hashicorp.com";
export TF_VAR_kubernetes_namespace="vso"
```

4. Ensure your kubeconfig path and context are correct in `providers.tf` for both the kubernetes and helm providers.

5. Deploy using terraform 

```
terraform init

terraform apply
```

6. Check if deployment is successful

```
kubectl get pod
NAME                                                             READY   STATUS    RESTARTS   AGE
ault-agent-injector-58c7998447-m575m                            1/1     Running                      0          12m
vso-vault-secrets-operator-controller-manager-75748c45df-btj2t   2/2     Running   0          19m
```

7. Deploy sample app and secret CRD and check that it was created

```
$ kubectl apply -f app-op.yml
$ kubectl get secret         
NAME                          TYPE                                  DATA   AGE
sh.helm.release.v1.vault.v1   helm.sh/release.v1                    1      16m
sh.helm.release.v1.vso.v1     helm.sh/release.v1                    1      6m56s
vault                         kubernetes.io/service-account-token   3      9m26s
vault-kv-app                  Opaque                                3      14s
vso-cc-storage-hmac-key       Opaque                                1      6m19s
```




