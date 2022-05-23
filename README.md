# Quickly provision a GKE cluster using Terraform

I use this module every time I want to quickly spin up a Google Kubernetes Engine cluster for experimentation.

## Architecture

Although this deployment is meant for proof-of-concept and experimental work, it implements many of the Google's [cluster security recommendations](https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster).

* The cluster is [VPC-native](https://cloud.google.com/kubernetes-engine/docs/concepts/alias-ips) as it uses alias IP address ranges;
* It is a [private cluster], that is its worker nodes do not have public IP addresses;
* It is _regional_ as the control nodes are allocated in multiple zones;
* It is _multi-zonal_ as the nodes are allocated in multiple zones;
* It has a _public endpoint_ with access limited to the _list of authorised control networks_;
* It has [Dataplane V2](https://cloud.google.com/blog/products/containers-kubernetes/bringing-ebpf-and-cilium-to-google-kubernetes-engine) enabled so it can enforce Network Policies;
* It uses [preemptible VMs] for worker nodes. This reduces the running cost substantially;
* The worker nodes' outbound Internet access is via [Cloud NAT];
* A [hardened node image with `containerd` runtime](https://cloud.google.com/kubernetes-engine/docs/concepts/using-containerd) is used;
* The nodes use a user-managed [least privilege service account];
* [Shielded GKE nodes] feature is enabled;
* [Secure Boot] and [Integrity Monitoring] are enabled on cluster nodes;
* The cluster is subscribed to _Rapid_ [release channel];
* [Workload Identity] is supported;

[least privilege service account]: https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster#use_least_privilege_sa
[Cloud NAT]: https://cloud.google.com/nat/
[private cluster]: https://cloud.google.com/kubernetes-engine/docs/concepts/private-cluster-concept
[Shielded GKE nodes]: https://cloud.google.com/kubernetes-engine/docs/how-to/shielded-gke-nodes
[release channel]:  https://cloud.google.com/kubernetes-engine/docs/concepts/release-channels
[Secure Boot]: https://cloud.google.com/compute/shielded-vm/docs/shielded-vm#secure-boot
[Integrity Monitoring]: https://cloud.google.com/compute/shielded-vm/docs/shielded-vm#integrity-monitoring
[Workload Identity]: https://cloud.google.com/kubernetes-engine/docs/concepts/workload-identity

## Requirements

* You must have the [necessary permissions](#required-permissions) on some existing *project*;
* The project must be linked to a [Cloud Billing account].

[Cloud Billing account]: https://cloud.google.com/billing/docs/concepts#billing_account

### Required permissions

The `owner` basic role on the project would work. The `editor` might but I have not tested it. 

**Alternatively**, the following roles are required at project level.

* Kubernetes Engine Admin (`roles/container.admin`)
* Service Account Admin (`roles/iam.serviceAccountAdmin`)
* Compute Admin (`roles/compute.admin`)
* Service Usage Admin (`roles/serviceusage.serviceUsageAdmin`)
* Monitoring Admin (`roles/monitoring.admin`)
* Private Logs Viewer (`roles/logging.privateLogViewer`)
* Moar?!

## Quick start

Checkout the repo and create a configuration file `env.auto.tfvars` with the following content.

```hcl
project = "???"
region  = "europe-west2"
zone    = "europe-west2-a"

authorized_networks = [
  {
    cidr_block   = "0.0.0.0/0"
    display_name = "warning-publicly-accessible-endpoint"
  },
]
```

* You _must_ change the `project` name;
* You _may_ change `region` and `zone` to your preferred ones;
* You are _encouraged_ to update the `authorized_networks` list to restrict access to your cluster's end-point.

Now you can deploy with Terraform (`init` ... `plan` ... `apply`). Enjoy! :shipit:

## Configuration

A more in-depth look at this module's configuration options.

### Mandatory variables

The values set for the following variables are applied at Terraform Google provider level.

* `project` is the project ID.
* `region`
* `zone`

### Recommended variables

* `authorized_networks` is the list of objects representing CIDR blocks allowed to access the cluster's "public" endpoint.
   
   ❗ Default is `[]`, which means no access. Check out the _Quick start_ section for a more permissive example. 

   To find your external IP, run `dig -4 TXT +short o-o.myaddr.l.google.com @ns1.google.com`

* `preemptible` is for provisioning preemptible VM instances for GKE nodes. Default is `true`.

### Cloud Router and Cloud NAT Gateway

The nodes with private IP addresses are given outbound access to the Internet via a Cloud NAT Gateway in order to make possible deployments from container registries other than Google's own.

## Example deployment

Once the infrastructure is provisioned with Terraform, you can deploy an example workload.

* _Online Boutique_ application by Google: [GoogleCloudPlatform/microservices-demo]
* My custom, hardened, version of deployment manifests: [olliefr/gke-microservices-demo]

[GoogleCloudPlatform/microservices-demo]: https://github.com/GoogleCloudPlatform/microservices-demo
[olliefr/gke-microservices-demo]: https://github.com/olliefr/gke-microservices-demo

## Future work

The following list is some ideas for future explorations.

* Deploy by impersonating a service account to validate the list of required roles;
* Create a [private cluster with no public endpoint][pcwnpe] and access the endpoint using [IAP for TCP forwarding];
* Provide an option for [Secret management];
* Configure [Artifact registry];
* Enable [Binary Authorization];
* Replace [preemptible VMs] with [spot VMs];
* [Shared VPC] set-up;
* [VPC Service Controls];
* Set up [Config Connector] (or use [Config Controller]);
* Explore [Cloud DNS for GKE] option;
* IPv6 set-up;
* Explore [Anthos Service Mesh] (managed Istio);

[pcwnpe]: https://cloud.google.com/kubernetes-engine/docs/how-to/private-clusters#private_cp
[IAP for TCP forwarding]: https://cloud.google.com/iap/docs/using-tcp-forwarding
[Secret management]: https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster#secret_management
[Artifact registry]: https://cloud.google.com/artifact-registry/docs/overview
[Binary authorization]: https://cloud.google.com/binary-authorization/docs
[preemptible VMs]: https://cloud.google.com/compute/docs/instances/preemptible
[spot VMs]: https://cloud.google.com/compute/docs/instances/spot
[Cloud DNS for GKE]: https://cloud.google.com/kubernetes-engine/docs/how-to/cloud-dns
[Shared VPC]: https://cloud.google.com/vpc/docs/shared-vpc
[VPC Service Controls]: https://cloud.google.com/vpc-service-controls/docs/overview 
[Config Connector]: https://cloud.google.com/config-connector/docs/overview
[Config Controller]: https://cloud.google.com/anthos-config-management/docs/concepts/config-controller-overview
[Anthos Service Mesh]: https://cloud.google.com/service-mesh/docs/overview