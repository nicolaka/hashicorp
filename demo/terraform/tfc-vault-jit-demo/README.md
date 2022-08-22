# Terraform Cloud Just-In-Time Workload Identity Demo

Summary: this is a quick demo for Terraform Enterprise/Cloud workload identity feature. When enabled & configured, Terraform Cloud will generate a unique workload identity (JWT) and inject it in `tfc-agent` where Terraform is executed. This identity can then be leveraged to automatically authenticate the Vault, AWS, GCP, AzureRM Terraform providers. 

The demo will use this new feature to automatically retrieve secrets from Vault using the Vault Terraform provider.

> Note: There are a couple of manual/UI steps that can be automated by using Terraform. The goal of the demo is to showcase the feature, so feel free to automate as you see fit.

### Requirements / Assumptions

- Vault running and accessible from your environment
- Vault Token
- Vault can access Terraform Cloud (Outbound HTTPs connection)
- Docker locally installed
- Terraform locally installed 
- TFC Workspace 


### Workflow

1. The first step is to configure Vault. We will need to create a new auth backend of type `jwt` that points to Terraform Cloud. We're also creating a role that will be bound to workloads associated with the Terraform workspace we'll be using. Finally, we're creatinga sample KVv2 secret engine mounted at `/secret` with a sample secret named `secret` that we will later use in our demo. 

```
# export VAULT_ADDR=<your vault addr>
# export VAULT_TOKEN=<your vault token>
# cd vault
```

You need to update the `vault/main.tf` file with your Terraform Cloud Organization and Workspace Names on Line 26:

```
sub = "organization:YOUR_TFC_ORK_NAME:workspace:YOUR_TFC_WORKSPACE_NAME:run_phase:*"
```

Once you do, you can run `terraform apply`.

```
# terraform init
# terraform apply --auto-approve   

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following
symbols:
  + create

Terraform will perform the following actions:

  # vault_jwt_auth_backend.tfc-jwt will be created
  + resource "vault_jwt_auth_backend" "tfc-jwt" {
      + accessor           = (known after apply)
      + bound_issuer       = "https://app.terraform.io"
      + id                 = (known after apply)
      + local              = false
      + namespace_in_state = true
      + oidc_discovery_url = "https://app.terraform.io"
      + path               = "jwt"
      + tune               = (known after apply)
      + type               = "jwt"
    }

  # vault_jwt_auth_backend_role.tfc-role will be created
  + resource "vault_jwt_auth_backend_role" "tfc-role" {
      + backend                      = "jwt"
      + bound_audiences              = [
          + "vault.workload.identity",
        ]
      + bound_claims                 = {
          + "sub" = "organization:XXXXX:workspace:XXXXX:run_phase:*"
        }
      + bound_claims_type            = "glob"
      + clock_skew_leeway            = 0
      + disable_bound_claims_parsing = false
      + expiration_leeway            = 0
      + id                           = (known after apply)
      + not_before_leeway            = 0
      + role_name                    = "tfc-role"
      + role_type                    = "jwt"
      + token_policies               = [
          + "tfc-policy",
        ]
      + token_type                   = "default"
      + user_claim                   = "terraform_full_workspace"
      + user_claim_json_pointer      = false
      + verbose_oidc_logging         = false
    }

  # vault_kv_secret_v2.secret will be created
  + resource "vault_kv_secret_v2" "secret" {
      + cas                 = 1
      + data                = (sensitive value)
      + data_json           = (sensitive value)
      + delete_all_versions = true
      + disable_read        = false
      + id                  = (known after apply)
      + metadata            = (known after apply)
      + mount               = "secret"
      + name                = "secret"
      + path                = (known after apply)
    }

  # vault_mount.secret will be created
  + resource "vault_mount" "secret" {
      + accessor                     = (known after apply)
      + audit_non_hmac_request_keys  = (known after apply)
      + audit_non_hmac_response_keys = (known after apply)
      + default_lease_ttl_seconds    = (known after apply)
      + description                  = "KV Version 2 secret engine mount"
      + external_entropy_access      = false
      + id                           = (known after apply)
      + max_lease_ttl_seconds        = (known after apply)
      + options                      = {
          + "version" = "2"
        }
      + path                         = "secret"
      + seal_wrap                    = (known after apply)
      + type                         = "kv"
    }

  # vault_policy.tfc-policy will be created
  + resource "vault_policy" "tfc-policy" {
      + id     = (known after apply)
      + name   = "tfc-policy"
      + policy = <<-EOT
            # Used to generate child tokens in vault
            path "auth/token/create" {
              capabilities = ["update"]
            }
            # Used by the token to query itself
            path "auth/token/lookup-self" {
              capabilities = ["read"]
            }
            # Actual secrets the token should have access to
            path "secret/*" {
              capabilities = ["read"]
            }
        EOT
    }

Plan: 5 to add, 0 to change, 0 to destroy.
vault_policy.tfc-policy: Creating...
vault_mount.secret: Creating...
vault_jwt_auth_backend.tfc-jwt: Creating...
vault_policy.tfc-policy: Creation complete after 0s [id=tfc-policy]
vault_mount.secret: Creation complete after 0s [id=secret]
vault_kv_secret_v2.secret: Creating...
vault_kv_secret_v2.secret: Creation complete after 0s [id=secret/data/secret]
vault_jwt_auth_backend.tfc-jwt: Creation complete after 1s [id=jwt]
vault_jwt_auth_backend_role.tfc-role: Creating...
vault_jwt_auth_backend_role.tfc-role: Creation complete after 1s [id=auth/jwt/role/tfc-role]

Apply complete! Resources: 5 added, 0 changed, 0 destroyed.
```

2. Now moving to configure TFC. We need to add 4 *Environment Variables* in the workspace that you created. These enviornment variables are required to both enable this feature and configure which Vault role this workspace can use. Update your workspace with the following environment variables:

```
VAULT_NAMESPACE = <VAULT NAMESPACE IF YOURE USING ONE>
TFC_WORKLOAD_IDENTITY_AUDIENCE = vault.workload.identity
VAULT_ADDR = < VAULT URL>
TFC_VAULT_RUN_ROLE = tfc-role
```


3. Next, we need to create a `tfc-agent` pool. Head to Settings > Agents -> create a pool --> create token --> save the token. 

4. Now back on your local environment, we need to build and launch a custom TFC agent that has custom hook scripts that are used to authenticate into Vault using the workload identity token generated. You can either build the Docker image manually or leverage an image I precreated.

If you want to build your own Docker image to the following, otherwise skip to Step #5

```
# cd tfc-agent
# docker built -t <docker-repo/docker-image:latest> .

For example:

# docker build -t nicolaka/tfc-jit-agent:latest .
[+] Building 1.0s (9/9) FINISHED
 => [internal] load build definition from Dockerfile                                                                                           0.0s
 => => transferring dockerfile: 180B                                                                                                           0.0s
 => [internal] load .dockerignore                                                                                                              0.0s
 => => transferring context: 2B                                                                                                                0.0s
 => [internal] load metadata for docker.io/hashicorp/tfc-agent:latest                                                                          0.8s
 => [auth] hashicorp/tfc-agent:pull token for registry-1.docker.io                                                                             0.0s
 => [internal] load build context                                                                                                              0.0s
 => => transferring context: 1.05kB                                                                                                            0.0s
 => [1/3] FROM docker.io/hashicorp/tfc-agent:latest@sha256:0ef6e3ea5fe1cb2e337d4b92faef0f198d4f083b8c1c4c166f40d4de5e60a0dc                    0.0s
 => CACHED [2/3] RUN mkdir /home/tfc-agent/.tfc-agent                                                                                          0.0s
 => CACHED [3/3] ADD --chown=tfc-agent:tfc-agent hooks /home/tfc-agent/.tfc-agent/hooks                                                        0.0s
 => exporting to image                                                                                                                         0.0s
 => => exporting layers                                                                                                                        0.0s
 => => writing image sha256:3f15ac5098574dda4e9be43f9f5f25906b0c7f8fe81008b12561f6363e3d0956                                                   0.0s
 => => naming to docker.io/nicolaka/tfc-jit-agent:latest
```

5. Now we can run the TFC agent locally, you can do that using the following command. You can substitute `nicolaka/tfc-jit-agent` with the Docker image name that you created if you want to use that image.

```
# export TFC_AGENT_TOKEN = <THE TFC AGENT TOKEN YOU GENERATED>
# export TFC_AGENT_NAME  = <whatever you wanna call this agent>
# docker run -d -e TFC_AGENT_TOKEN -e TFC_AGENT_NAME --name tfc-agent nicolaka/tfc-jit-agent:latest
```

You can check if the agent is running as expected and you can check in the TFC portal to check if it's been registered correctly. 

```
# docker logs -f tfc-agent
2022-08-16T19:38:31.281Z [INFO]  agent: Starting: name=nk-tfc-agent-2 version=1.3.0
2022-08-16T19:38:31.293Z [INFO]  core: Starting: version=1.3.0
2022-08-16T19:38:31.786Z [INFO]  core: Agent registered successfully with Terraform Cloud: agent.id=agent-XXXX agent.pool.id=apool-XXX
2022-08-16T19:38:31.901Z [INFO]  agent: Core version is up to date: version=1.3.0
2022-08-16T19:38:31.901Z [INFO]  core: Waiting for next job
```

6. Now you can configrue the workspace to use this agent pool as an execution mode. Go to the worksapce in TFC, then go to Settings > General > Execution Mode > Agent > select the agent pool that you just created.

7. Now it's time to run the main terraform demo that leverages the Vault Terraform provider to retrieve the secret that we created in Vault in step 1. From the root directory, update the `main.tf` file to include your TFC Organization Name and TFC Workspace Name. 



```
# terraform init
# terraform apply --auto-approve   
Running apply in Terraform Cloud. Output will stream here. Pressing Ctrl-C
will cancel the remote apply if it's still pending. If the apply started it
will stop streaming the logs, but will not stop the apply running remotely.

Preparing the remote apply...

To view this run in a browser, visit:
https://app.terraform.io/app/XXXX/runs/run-XXXX

Waiting for the plan to start...

Terraform v1.2.6
on linux_amd64
Executing pre-plan hook...
Preparing Vault provider auth...
Vault provider auth prepared
Initializing plugins and modules...
data.vault_kv_secret_v2.secret_data: Reading...
data.vault_kv_secret_v2.secret_data: Read complete after 0s [id=secret/data/secret]

Changes to Outputs:
  + vault_kv = {
      + "foo" = "bar"
      + "zip" = "zap"
    }

You can apply this plan to save these new output values to the Terraform
state, without changing any real infrastructure.

------------------------------------------------------------------------

Cost Estimation:

Resources: 0 of 0 estimated
           $0.0/mo +$0.0

------------------------------------------------------------------------

Preparing Vault provider auth...
Vault provider auth prepared

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

vault_kv = tomap({
  "foo" = "bar"
  "zip" = "zap"
})


```

This shows the output of the run showing the k/v secret that it successfully retrieved from Vault! 
