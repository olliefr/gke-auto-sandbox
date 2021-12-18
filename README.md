# Quickly provision a GKE cluster using Terraform

I use this module every time I want to quickly spin up a Google Kubernetes Engine cluster for experimentation.

**TODO** Replace [preemptible VMs] with [spot VMs].

## Architecture

* The cluster is [VPC-native](https://cloud.google.com/kubernetes-engine/docs/concepts/alias-ips) as it uses alias IP address ranges;
* It is a [private cluster], that is its worker nodes do not have public IP addresses;
* It is _regional_ as the control nodes are allocated in multiple zones;
* It is _multi-zonal_ as the nodes are allocated in multiple zones;
* It has a _public endpoint_ with access limited to the _list of authorised control networks_;
* It has [Dataplane V2](https://cloud.google.com/blog/products/containers-kubernetes/bringing-ebpf-and-cilium-to-google-kubernetes-engine) enabled so it can enforce Network Policies;
* It uses [preemptible VMs] for worker nodes. This reduces the running cost substantially;
* The worker nodes' outbound Internet access is via [Cloud NAT].

[Cloud NAT]: https://cloud.google.com/nat/
[private cluster]: https://cloud.google.com/kubernetes-engine/docs/concepts/private-cluster-concept
[preemptible VMs]: https://cloud.google.com/compute/docs/instances/preemptible
[spot VMs]: https://cloud.google.com/compute/docs/instances/spot

## Requirements

* You must have been granted `Owner` role on some existing *project*;
* The project must be linked to a [Cloud Billing account].

[Cloud Billing account]: https://cloud.google.com/billing/docs/concepts#billing_account

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

Once the infrastructure is provisioned with Terraform, you can deploy Google's `microservices-demo` application.

For my custom, hardened, version of deployment manifests and supporting information, see TODO repository.
