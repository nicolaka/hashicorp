# Deploying Terraform Cloud Agents on K8s

0. [Create an agent pool and retrieve the agent token](https://developer.hashicorp.com/terraform/cloud-docs/agents/agent-pools#create-an-agent-pool) from Terrform Cloud/Enterprise  
1. Create a Kubernetes secret containing the TFC agent token:

```
kubectl create secret generic tfc-agent-token-secret --type=string --from-literal=TFC_AGENT_TOKEN=<YOUR TOKEN>
```

2. Deploy the TFC-agent:

```
kubectl apply -f tfc-agent-deploy.yaml
deployment.apps/tfc-agent-deployment created

kubectl get pod
NAME                                   READY   STATUS    RESTARTS        AGE
tfc-agent-deployment-9b8bcb49c-x4wrp   1/1     Running   2 (6m24s ago)   8m22s
```