# GKE set-up for microservices demo

This is an example infrastructure for Google Cloud Platform's [microservices-demo]. Unofficial, obviously.

Once the infrastructure is provisioned with Terraform, a custom hardened deployment of `microservices-demo` is performed.

For the deployment manifests and supporting information, see TODO repository.

## Terraform backend

This project is a foundation for the technical demo of a secure Kubernetes deployment.
As such, its focus is not on establishing a production-grade Terraform pipeline.
So it is using the [`local`](https://www.terraform.io/docs/language/settings/backends/local.html) Terraform backend.

## Requirements

Deploying the infrastructure defined in this repository requires:

* a Google Cloud Platform project with billing enabled;

## Mandatory variables

The values set for the following variables are applied at Terraform Google provider level.

* `project` is the project ID.
* `region`
* `zone`

## Recommended variables

The value set for the following variable is applied at the GKE cluster resource level.

* `authorized_networks` is the list of authorized control networks for the GKE cluster. Default is `[]`, which means no access. Each network is represented by an object.

Example of an object:

```hcl
{
	cidr_block:   "127.0.0.1/32"
	display_name: "This would obviously not work"
}
```

To find your external IP use `dig -4 TXT +short o-o.myaddr.l.google.com @ns1.google.com`

The value set fo the following variable is applied at the GKE cluster node pool level.

* `preemptible` is for provisioning preemptible VM instances for GKE nodes. Default is `true`.

## Architecture

A GKE cluster and supporting infrastructure is provisioned, subject to the following.

The GKE cluster:

* is [VPC-native](https://cloud.google.com/kubernetes-engine/docs/concepts/alias-ips) as it uses alias IP address ranges;
* is _private_ as the nodes do not have public IP addresses;
* is _regional_ as the control nodes are allocated in multiple zones;
* is _multi-zonal_ as the nodes are allocated in multiple zones;
* has _public endpoint_ with a _list of authorised control networks_;
* has [Dataplane V2](https://cloud.google.com/blog/products/containers-kubernetes/bringing-ebpf-and-cilium-to-google-kubernetes-engine) enabled so can enforce Network Policies.

**!!** The worker nodes are pre-emptible by default to save money.

## Cloud Router and Cloud NAT Gateway

The nature of the microservices demo that is going to be deployed into this cluster requires it pulling a Docker image from Docker Hub. 

Unlike Google Container Registry, the Docker Hub is not part of the Google network. Therefore, to pull an image, the node must have outbound access to the internet. This is achieved with [Cloud NAT](https://cloud.google.com/nat/docs/overview).

Thus, the resources representing the Cloud Router and the Cloud NAT Gateway are only necessary for as long as the deployment is using container registries other than Google's one.
