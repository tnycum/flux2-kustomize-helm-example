# Runbook

This runbook follows https://github.com/fluxcd/flux2-kustomize-helm-example and is adapted to run on AKS.

**Be sure to tear down AKS environments after you are finished with them to avoid incurring additional charges**

## Tools used

### Local

You'll need to install these prerequisites locally for this demo to work.

- Flux CLI - Required for the 'flux bootstrap' command
- Azure CLI - Required for communicating with the Azure API and getting the AKS credentials
- kubectl - To be able to interact with the Kubernetes API
- k9s - (optional) a nice terminal UI layer on top of kubectl

### Remote

- Github - to host repository
- Azure Kubernetes Service (AKS)
- kustomize - built-into k8s; a way to override kubernetes YAML per environment
- helm - package manager for kubernetes

Notable apps deployed into AKS include:

- Flux - Continuous Delivery, deploys controllers for Helm, Git, Kustomize, Notification (not used). See https://fluxcd.io/flux/components/
- nginx-ingress-controller - Routes traffic entering cluster to correct backend
- PodInfo - Microservices demo app that shows basic UI and pod metadata
- cert-manager - Not really used but enables getting certs from letsencrypt

### Tool Alternatives

- ArgoCD - FluxCD with a UI. Very reasonable alternative. For some pros and cons check out [this Gitlab post about why they selected Flux](https://about.gitlab.com/blog/2023/02/08/why-did-we-choose-to-integrate-fluxcd-with-gitlab/#why-flux%3F) for their integration.
- Gitlab - Basically equivalent to Github. However, our group's Gitlab instance has IP restrictions that prevent it from working with this demo.
- minikube - Rather than use AKS, you can set up local kubernetes environments with minikube or [kind](https://kind.sigs.k8s.io/docs/user/quick-start/). AKS was used because of difficulties working around zscaler messing with certificates.

## Instructions

Fork the [original git repository](https://github.com/fluxcd/flux2-kustomize-helm-example) into your own Github project. Then, [setup a classic Personal Access Token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-personal-access-token-classic) with all of the permissions granted within the `repo` block.

```sh
# Get AZ creds
az login
```

Create a `terraform/terraform.tfvars` file with these contents:

```sh
subscription_id     = "<azure-subscription-id>"
resource_group_name = "<azure-resource-group>"
aks_name_prefix     = "<arbitrary prefix for AKS clusters>"
```

Now create the AKS cluster using `terraform`:

```sh
# Create AKS cluster
cd terraform
terraform init
terraform apply
# answer 'y' at the prompt
```

Setup your `~/.kube/config` file with authentication tokens to the AKS clusters we built:

```sh
az aks get-credentials --resource-group "$(tf output -raw resource_group_name)" --name "$(tf output -raw kubernetes_cluster_name)"

# Validation
# List contexts (should show staging and production, plus any other previously defined contexts outside of this demo)
kubectl config get-contexts

# Switch contexts, so kubectl commands target one AKS cluster or another
kubectl config use-context <context-name>
```

Bootstrap the AKS cluster using Flux!

```sh
# https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-personal-access-token-classic
# Give all permissions under 'repo'
export GITHUB_TOKEN=<access-token>
export GITHUB_USER=<github-username>
export GITHUB_REPO=flux2-kustomize-helm-example # or change to whatever the name of your repo is

# `cd` to project root if still in Terraform directory

# Validate all of the prerequisites are ok
flux check --pre

# This will deploy all of the Flux resources AND GitOps applications in this repository into the staging AKS cluster.
# Note - name of kubeconfig context must match context below
flux bootstrap github \
    --context="$(tf output -raw kubernetes_cluster_name)" \
    --owner=${GITHUB_USER} \
    --repository=${GITHUB_REPO} \
    --branch=main \
    --personal \
    --path=clusters/staging

# The deployment into production will look like:
flux bootstrap github \
    --context="$(tf output -raw kubernetes_cluster_name_prod)" \
    --owner=${GITHUB_USER} \
    --repository=${GITHUB_REPO} \
    --branch=main \
    --personal \
    --path=clusters/production
```

There's a lot that happens with this bootstrap command. Files will be committed on your behalf into the git repository inside `clusters/<env>/flux-system`. These contain Kubernetes YAMLs for the Flux deployment (which manages itself via GitOps!), and a file that points to our GitRepo that we'll be syncing deployments from.

A lot of Deployments and Pods should be getting created. Use `kubectl get pods -A --watch` to see it all happen in realtime (or `k9s`). At the end, there is a `PodInfo` application that should be up and running.

To access the `PodInfo` application in the browser:

```sh
kubectl -n ingress-nginx port-forward svc/ingress-nginx-controller 8080:80

# To view the application in the browser:
# edit /etc/hosts and add:
# 127.0.0.1 podinfo.production
# 127.0.0.1 podinfo.staging
# Browse to http://podinfo.staging:8080

# Or, just use curl:
# replace 'staging' with 'production' as necessary
curl -H "Host: podinfo.staging" http://localhost:8080
{
  "hostname": "podinfo-59489db7b5-lmwpn",
  "version": "6.2.3"
}
```

If you want to test a change to the `PodInfo` application and see it propogate, you can modify `apps/<env>/podinfo-values.yaml`.

For example, this is a new `podinfo-values.yaml` for production that changes the image version and UI message:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: podinfo
  namespace: podinfo
spec:
  chart:
    spec:
      version: ">=1.0.0"
  values:
    ingress:
      hosts:
        - host: podinfo.production
          paths:
            - path: /
              pathType: ImplementationSpecific
    ui:
      message: "This is a new message"
    image:
      tag: 6.7.0
```

Other Helm values to change are found [here](https://artifacthub.io/packages/helm/podinfo/podinfo).

Once you `git add`, `git commit`, and `git push` the change, Flux should automatically apply it to the cluster within a few minutes.

## How does it all work

### The clusters directory

After the bootstrap command runs per environment, there are files created in `clusters/<env>/flux-system`. The `gotk-sync.yaml` is the interesting one.

It defines a `GitRepository` type pointed at our Github repo. This, combined with the Flux `git-controller`, syncs the repo every minute.

There is also a `Kustomization` in `gotk-sync.yaml` pointed to our cluster environment that deploys all the apps in the environment from `apps.yaml` and the controllers in `infrastructure.yaml`. However, there is explicit ordering where apps must wait for infrastructure controllers to be deployed first.

### The infrastructure directory

The `controllers/` directory deploys some Helm Charts for Nginx and `cert-manager`. These use Flux CRDs `HelmRepository` and `HelmRelease`.

- `HelmRepository` - Points to a chart URL
- `HelmRelease` - References `HelmRepository` and supplies Helm values, update frequency, etc.

The configuration here will look for new Helm updates every 12 hours and apply them if it is a chart version "1.x" match (cert-manager) or any version (nginx).

The `configs` directory can mostly be ignored for this demo and just shows some additional flux capabilities. It's just creating a `cert-manager` Issuer with a unique configuration per environment. It also must wait for `controllers` to be created.

### The apps directory

The `apps/` directory leverages Kustomize to deploy unique versions of the `PodInfo` Helm Chart per environment. It has a condition to wait for everything in `infrastructure` to complete before running.

The `apps/base` directory is the basic configuration of the PodInfo Helm chart. This base configuration gets overwritten/merged with any configuration in `apps/staging` or `apps/production`.

## Extending this demo

- A separate repo could have a traditional CI pipeline that builds and pushes a Docker image to an image registry. Then, this repo would separately be updated to control the CD
  - This repo can be automatically updated when new images become available. See [Flux Image Automation](https://fluxcd.io/flux/components/image/). Demo [here](https://fluxcd.io/flux/guides/image-update/)
- Additional apps can be included within the `apps/` directory to deploy
- The Ingress controller should be tied to an Azure load balancer to avoid port-forwarding
- Could add [SOPS](https://fluxcd.io/flux/guides/mozilla-sops/) to manage any Secrets within this repo securely
- Setup Alerts for successful or failed deployments that use the `Notification Controller`.