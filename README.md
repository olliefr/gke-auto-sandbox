# Quickly provision a GKE cluster using Terraform

I use this module every time I want to quickly spin up a Google Kubernetes Engine cluster for experimentation.

## Architecture

The GKE cluster provisioned by this module

* is [VPC-native](https://cloud.google.com/kubernetes-engine/docs/concepts/alias-ips) as it uses alias IP address ranges;
* is _private_ as the nodes do not have public IP addresses;
* is _regional_ as the control nodes are allocated in multiple zones;
* is _multi-zonal_ as the nodes are allocated in multiple zones;
* has a _public endpoint_ with access limited to the _list of authorised control networks_;
* has [Dataplane V2](https://cloud.google.com/blog/products/containers-kubernetes/bringing-ebpf-and-cilium-to-google-kubernetes-engine) enabled so can enforce Network Policies;
* uses pre-emptible worker nodes to save money.

## Requirements

You must have a Google Cloud Platform project with billing enabled.

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

Now you can run `terraform init`, followed by `terraform plan`.

Enjoy! :shipit:

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
