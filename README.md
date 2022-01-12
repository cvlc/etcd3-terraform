# `etcd3-terraform`

A terraform recipe, forked from Monzo's [etcd3-terraform](https://github.com/monzo/etcd3-terraform) and updated in order to provide easy deployment of a non-Kubernetes-resident etcd cluster on AWS for Ondat.

## Stack 🎮

This will create a new VPC and a set of 3 Auto Scaling Groups each running Debian stable by default. These ASGs are distributed over 3 Availability Zones detected from the current region in use (eg. passed via `AWS_REGION` environment variable). All resources are deployed into a VPC that can either be created by setting the `vpc_id` variable to `create` or chosen by setting `vpc_id` to the ID of an existing VPC. 

This will also create a local Route 53 zone for the domain you pick and bind it to the VPC so its records can be resolved. This domain does not need to be registered. An `SRV` record suitable for etcd discovery is also created as well as a Lambda function which monitors ASG events and creates `A` records for each member of the cluster.

An Application Load Balancer will be created for clients of the etcd cluster. It fronts all 9 ASGs on port `2379`.

## How to use 🕹

The file `variables.tf` declares the Terraform variables required to run this stack. Almost everything has a default - the region will be detected from the `AWS_REGION` environment variable and it will span across the maximum available zones within your preferred region. You will be asked to provide an SSH public key to launch the stack. Variables can all be overridden in a `terraform.tfvars` file or by passing runtime parameters.
