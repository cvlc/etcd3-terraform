# `etcd3-terraform`

A terraform recipe, forked from Monzo's [etcd3-terraform](https://github.com/monzo/etcd3-terraform) and updated in order to provide easy deployment of a non-Kubernetes-resident etcd cluster on AWS for Ondat.

## Stack 🎮

This will create a new VPC and a set of 3 Auto Scaling Groups each running Debian stable by default. These ASGs are distributed over 3 Availability Zones detected from the current region in use (eg. passed via `AWS_REGION` environment variable). All resources are deployed into a VPC that can either be created by setting the `vpc_id` variable to `create` or chosen by setting `vpc_id` to the ID of an existing VPC. 

This will also create a local Route 53 zone for the domain you pick and bind it to the VPC so its records can be resolved. This domain does not need to be registered. An `SRV` record suitable for etcd discovery is also created as well as a Lambda function which monitors ASG events and creates `A` records for each member of the cluster.

A Network Load Balancer will be created for clients of the etcd cluster. It wraps all of the auto-scaling group instances on port `2379` with a health check to ensure that only functional instances are presented.

### High Availability
As mentioned above, the default size of the cluster is 3 nodes - this means that only 2 node failures will trigger a catastrophic cluster failure. In order to prevent this, it's suggested to use a larger cluster in any real-world scenario - 5, 7 or 9 nodes should be sufficient depending on risk appetite.

### Elasticity
Scaling out is as easy as increasing the size of the cluster via the aforementioned variable. When scaling down/in, destroy the extreneous instances and autoscaling groups manually via `terraform destroy -target=...` after removing the member from the cluster using `etcdctl` before running another `terraform apply`. Future work could implement lifecycle hooks and autoscaling to make this more automated.

### Backups
Volume snapshots are taken automatically of each node, every day at 2am. A week of snapshots is retained for each node. In order to restore from snapshot, take down the cluster and manually replace each EBS volume. Use `terraform import` to import the new volumes into the state to reconcile from the Terraform end. 

## Security 🔒
In this distribution, we've:
- encrypted all etcd and root volumes
- encryped and authenticated all etcd traffic between peers and clients
- locked down network access to the minimum
- ensured that all AWS policies that enable writing to resources are constrained to acting on the resources created by this module
- used a modern, stable default AMI (Debian 10)

This makes for a secure base configuration. 

It is suggested that this is deployed to private subnets only within a VPC (`subnet_type` to `Private` after tagging private subnets as `Private=true`) and that the `associate_public_ips` variable is kept to false. With `vpc_id=create` this will create a new, appropriately-tagged private VPC. This is the default behaviour.

### Authentication
The etcd nodes authenticate with each other via individual TLS certificates and keys. Clients authenticate using a single certificate. Role Based Access Control [is possible with further configuration via etcd itself](https://etcd.io/docs/v3.5/op-guide/authentication/rbac/).

### Certificates
A CA and several certificates for peers, servers and clients are generated by Terraform and stored in the state file. It is therefore suggested that the state file is stored securely (and ideally remotely, eg. in an encrypted S3 bucket with limited access). Certificates are valid for 5 years (for the CA) and 1 year (for others). At the moment, the renewal process requires replacing the nodes one-at-a-time after the certificates have been destroyed and re-created in terraform - this should be done carefully using `terraform destroy -target=...` and `terraform apply -target=...` for each of the resources in series, spacing out the node replacements to ensure that quorum is not broken. Replacing the CA certificate will require manually copying the new certificates to each instance and restarting the `etcd-member` systemd job to ensure that the cluster remains in-sync through the terraform node replacement process.

The client certificate must be used to authenticate with the server when communicating with etcd from allowed clients (within the cidr range in `client_cidrs`). The certificate and key will be generated by Terraform and placed in the current working directory, named client.pem and client.key respectively. 

## How to configure and deploy 🕹

The file `variables.tf` declares the Terraform variables required to run this stack. Almost everything has a default - the region will be detected from the `AWS_REGION` environment variable and it will span across the maximum available zones within your preferred region. You will be asked to provide an SSH public key to launch the stack. Variables can all be overridden in a `terraform.tfvars` file or by passing runtime parameters.


### Example (minimal for development env, creates a VPC and all resources in a private subnet)
```
module "etcd3-terraform" {
  source = "github.com/cvlc/etcd3-terraform"
  key_pair_public_key = "ssh-rsa..."
  ssh_cidrs = ["10.2.3.4/32"] # ssh jumpbox
  dns = { "domain_name": "mycompany.local" }
  
  ssd_size = 32
  instance_type = "t3.medium"
}

```

### Example (existing vpc running kops for stage env)
This example uses the tag "kubernetes.io/role/internal-elb: 1" to identify the private subnets to deploy to.

```
module "etcd3-terraform" {
  source = "github.com/cvlc/etcd3-terraform"
  key_pair_public_key = "ssh-rsa..."
  ssh_cidrs = ["10.2.3.4/32"] # ssh jumpbox
  dns = { "domain_name": "mycompany.local" }
  
  ssd_size = 512
  cluster_size = 5
  instance_type = "c5a.large"
  
  role = "etcds"
  environment = "stage"

  vpc_id = "vpc-abcdef1234"
  subnet_tag_key = "kubernetes.io/role/internal-elb"
  subnet_tag_value = "1"
}
```

### Example (new vpc, 'airgapped' environment)

Though 'airgapped' in terms of inbound/outbound internet access, this will still rely on access to the AWS metadata service from the instance in order to attach the volumes. 

```
module "etcd3-terraform" {
  source = "github.com/cvlc/etcd3-terraform"
  key_pair_public_key = "ssh-rsa..."
  ssh_cidrs = ["10.2.3.4/32"] # ssh jumpbox
  dns = { "domain_name": "mycompany.local" }

  client_cirs = ["10.3.0.0/16"] # k8s cluster
  
  ssd_size = 1024
  cluster_size = 9
  instance_type = c5a.4xlarge

  role = "etcd0"
  environment = "performance"
  
  allow_download_from_cidrs = ["10.2.3.5/32"] # HTTP server for files
  create_s3_bucket = "false"
  etcd3_bootstrap_binary_url = "http://10.2.3.5/etcd3_bootstrap"
  etcd_url = "http://10.2.3.5/etcd-v3.5.1.tgz"
}
```

Note that if you are creating a VPC with `vpc_id=create` you may need to initialize it first, before the rest of this module. To do so, simply:
```
terraform apply -target=module.vpc
terraform apply
```

### Maintenance
etcd is configured with a 100GB data disk per node on Amazon EBS SSDs by default (configurable via `ssd_size` variable), a `revision` auto compaction mode and a retention of `20000`. An automatic cronjob runs on each node to ensure defragmentation happens at least once every month, this briefly blocks reads/writes on a single node at a time from 3:05am on a different day of the month for each node. It's configured with a backend space quota of `8589934592` bytes. 

For further details of what these values and settings mean, refer to [etcd's official documentation](https://etcd.io/docs/v3.5/op-guide/maintenance/).

## How to run etcdctl 🔧
We presume that whatever system you choose to run these commands on can connect to the NLB (ie. if you're using a private subnet, your client machine is within the VPC or connected via a VPN).

First, install the CA certificate to your client machine. On Ubuntu/Debian, this can be done by copying `ca.pem` to `/usr/local/share/ca-certificates/my-etcd-ca.crt` and running `update-ca-certificates`.  

You're now ready to test etcdctl functionality - replace `$insert_nlb_address` with the URL of the NLB. 

```
$ ETCDCTL_API=3 ETCDCTL_CERT=client.pem ETCDCTL_KEY=client.key ETCDCTL_ENDPOINTS="https://$insert_nlb_address:2379" etcdctl member list
25f97d08c726ed1, started, peer-2, https://peer-2.etcd.eu-west-2.i.development.mycompany.local:2380, https://peer-2.ondat.eu-west-2.i.development.mycompany.local:2379, false
326a6d27c048c8ea, started, peer-1, https://peer-1.etcd.eu-west-2.i.development.mycompany.local:2380, https://peer-1.ondat.eu-west-2.i.development.mycompany.local:2379, false
38308ae09ffc8b32, started, peer-0, https://peer-0.etcd.eu-west-2.i.development.mycompany.local:2380, https://peer-0.ondat.eu-west-2.i.development.mycompany.local:2379, false
```
## How to (synthetically) [benchmark](https://etcd.io/docs/v3.5/op-guide/performance/) etcd in your environment 📊

### Prep
Be sure that you have `go` installed and `$GOPATH` correctly set with `$GOPATH/bin` in your `$PATH` in addition to being able to run `etcdctl` successfully as above.
```
$ go get go.etcd.io/etcd/v3/tools/benchmark
```

Note that performance will vary significantly depending on the client machine you run the benchmarks from - running them over the internet, even through a VPN, does not provide equitable performance to running directly from inside your VPC. For the first benchmark, we will demonstrate this before we continue using a VPC-resident instance only to run the rest.

### Benchmark the write rate to leader (high-spec workstation, 100mbps connected over internet) 📉
```
$ benchmark --endpoints="https://$insert_nlb_address:2379" --cert client.pem --key client.key --target-leader --conns=1 --clients=1 put --key-size=8 --sequential-keys --total=10000 --val-size=256
Summary:
  Total:	383.4450 secs.
  Slowest:	0.2093 secs.
  Fastest:	0.0283 secs.
  Average:	0.0383 secs.
  Stddev:	0.0057 secs.
  Requests/sec:	26.0794

Response time histogram:
  0.0283 [1]	|
  0.0464 [9199]	|∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎
  0.0645 [764]	|∎∎∎
  0.0826 [31]	|
  0.1007 [4]	|
  0.1188 [0]	|
  0.1369 [0]	|
  0.1550 [0]	|
  0.1731 [0]	|
  0.1912 [0]	|
  0.2093 [1]	|

Latency distribution:
  10% in 0.0335 secs.
  25% in 0.0350 secs.
  50% in 0.0364 secs.
  75% in 0.0405 secs.
  90% in 0.0450 secs.
  95% in 0.0495 secs.
  99% in 0.0585 secs.
  99.9% in 0.0754 secs.
```

### Benchmark the write rate to leader (VPC-resident c4.large instance) 📈
```
$ benchmark --endpoints="https://$insert_nlb_address:2379" --cert client.pem --key client.key --target-leader --conns=1 --clients=1 put --key-size=8 --sequential-keys --total=10000 --val-size=256
Summary:
  Total:	19.0950 secs.
  Slowest:	0.0606 secs.
  Fastest:	0.0014 secs.
  Average:	0.0019 secs.
  Stddev:	0.0011 secs.
  Requests/sec:	523.6961

Response time histogram:
  0.0014 [1]	|
  0.0073 [9972]	|∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎
  0.0133 [17]	|
  0.0192 [4]	|
  0.0251 [0]	|
  0.0310 [2]	|
  0.0369 [2]	|
  0.0428 [0]	|
  0.0487 [0]	|
  0.0547 [0]	|
  0.0606 [2]	|

Latency distribution:
  10% in 0.0016 secs.
  25% in 0.0017 secs.
  50% in 0.0018 secs.
  75% in 0.0019 secs.
  90% in 0.0022 secs.
  95% in 0.0025 secs.
  99% in 0.0044 secs.
  99.9% in 0.0139 secs.
```

```
$ benchmark --endpoints="https://$insert_nlb_address:2379" --cert client.pem --key client.key --target-leader --conns=100 --clients=1000 put --key-size=8 --sequential-keys --total=100000 --val-size=256
Summary:
  Total:	17.8645 secs.
  Slowest:	1.1992 secs.
  Fastest:	0.0338 secs.
  Average:	0.1782 secs.
  Stddev:	0.0785 secs.
  Requests/sec:	5597.7090

Response time histogram:
  0.0338 [1]	|
  0.1503 [37453]	|∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎
  0.2668 [54595]	|∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎
  0.3834 [6561]	|∎∎∎∎
  0.4999 [627]	|
  0.6165 [268]	|
  0.7330 [187]	|
  0.8495 [108]	|
  0.9661 [76]	|
  1.0826 [89]	|
  1.1992 [35]	|

Latency distribution:
  10% in 0.1061 secs.
  25% in 0.1313 secs.
  50% in 0.1678 secs.
  75% in 0.2060 secs.
  90% in 0.2528 secs.
  95% in 0.2935 secs.
  99% in 0.4293 secs.
  99.9% in 0.9885 secs.
```

### Benchmark writes to all members 📈
```
$ benchmark --endpoints="https://$insert_nlb_address:2379" --cert client.pem --key client.key --conns=100 --clients=1000 put --key-size=8 --sequential-keys --total=100000 --val-size=256
Summary:
  Total:	7.0381 secs.
  Slowest:	0.3753 secs.
  Fastest:	0.0111 secs.
  Average:	0.0694 secs.
  Stddev:	0.0241 secs.
  Requests/sec:	14208.3928

Response time histogram:
  0.0111 [1]	|
  0.0475 [12583]	|∎∎∎∎∎∎∎
  0.0840 [68178]	|∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎
  0.1204 [15990]	|∎∎∎∎∎∎∎∎∎
  0.1568 [2456]	|∎
  0.1932 [562]	|
  0.2297 [135]	|
  0.2661 [25]	|
  0.3025 [0]	|
  0.3389 [0]	|
  0.3753 [70]	|

Latency distribution:
  10% in 0.0459 secs.
  25% in 0.0540 secs.
  50% in 0.0654 secs.
  75% in 0.0793 secs.
  90% in 0.0963 secs.
  95% in 0.1092 secs.
  99% in 0.1524 secs.
  99.9% in 0.2080 secs.
```

### Benchmark single connection reads 📈
```
$ benchmark --endpoints="https://$insert_nlb_address:2379" --cert client.pem --key client.key --conns=1 --clients=1 range YOUR_KEY --consistency=l --total=10000
Summary:
  Total:	27.1453 secs.
  Slowest:	0.3582 secs.
  Fastest:	0.0023 secs.
  Average:	0.0027 secs.
  Stddev:	0.0039 secs.
  Requests/sec:	368.3883

Response time histogram:
  0.0023 [1]	|
  0.0379 [9992]	|∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎
  0.0735 [5]	|
  0.1091 [1]	|
  0.1446 [0]	|
  0.1802 [0]	|
  0.2158 [0]	|
  0.2514 [0]	|
  0.2870 [0]	|
  0.3226 [0]	|
  0.3582 [1]	|

Latency distribution:
  10% in 0.0024 secs.
  25% in 0.0025 secs.
  50% in 0.0026 secs.
  75% in 0.0027 secs.
  90% in 0.0028 secs.
  95% in 0.0028 secs.
  99% in 0.0032 secs.
  99.9% in 0.0359 secs.
```

```
$ benchmark --endpoints="https://$insert_nlb_address:2379" --cert client.pem --key client.key --conns=1 --clients=1 range YOUR_KEY --consistency=s --total=10000
Summary:
  Total:	10.9325 secs.
  Slowest:	0.0685 secs.
  Fastest:	0.0009 secs.
  Average:	0.0011 secs.
  Stddev:	0.0008 secs.
  Requests/sec:	914.7062

Response time histogram:
  0.0009 [1]	|
  0.0077 [9989]	|∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎
  0.0144 [5]	|
  0.0212 [3]	|
  0.0279 [1]	|
  0.0347 [0]	|
  0.0414 [0]	|
  0.0482 [0]	|
  0.0550 [0]	|
  0.0617 [0]	|
  0.0685 [1]	|

Latency distribution:
  10% in 0.0010 secs.
  25% in 0.0010 secs.
  50% in 0.0010 secs.
  75% in 0.0012 secs.
  90% in 0.0012 secs.
  95% in 0.0013 secs.
  99% in 0.0014 secs.
  99.9% in 0.0077 secs.
```

### Benchmark many concurrent reads 📈
```
$ benchmark --endpoints="https://$insert_nlb_address:2379" --cert client.pem --key client.key --conns=100 --clients=1000 range YOUR_KEY --consistency=l --total=100000
Summary:
  Total:	6.2002 secs.
  Slowest:	0.6050 secs.
  Fastest:	0.0030 secs.
  Average:	0.0570 secs.
  Stddev:	0.0428 secs.
  Requests/sec:	16128.4008

Response time histogram:
  0.0030 [1]	|
  0.0632 [72786]	|∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎
  0.1234 [20556]	|∎∎∎∎∎∎∎∎∎∎∎
  0.1836 [4931]	|∎∎
  0.2438 [1145]	|
  0.3040 [193]	|
  0.3642 [293]	|
  0.4244 [29]	|
  0.4846 [6]	|
  0.5448 [0]	|
  0.6050 [60]	|

Latency distribution:
  10% in 0.0239 secs.
  25% in 0.0316 secs.
  50% in 0.0438 secs.
  75% in 0.0664 secs.
  90% in 0.1096 secs.
  95% in 0.1336 secs.
  99% in 0.2207 secs.
  99.9% in 0.3603 secs.
```

```
$ benchmark --endpoints="https://$insert_nlb_address:2379" --cert client.pem --key client.key --conns=100 --clients=1000 range YOUR_KEY --consistency=s --total=100000
Summary:
  Total:	5.0824 secs.
  Slowest:	0.6650 secs.
  Fastest:	0.0018 secs.
  Average:	0.0452 secs.
  Stddev:	0.0321 secs.
  Requests/sec:	19675.9040

Response time histogram:
  0.0018 [1]	|
  0.0681 [85681]	|∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎
  0.1344 [12171]	|∎∎∎∎∎
  0.2008 [1710]	|
  0.2671 [271]	|
  0.3334 [79]	|
  0.3997 [23]	|
  0.4660 [33]	|
  0.5324 [21]	|
  0.5987 [1]	|
  0.6650 [9]	|

Latency distribution:
  10% in 0.0190 secs.
  25% in 0.0262 secs.
  50% in 0.0371 secs.
  75% in 0.0537 secs.
  90% in 0.0795 secs.
  95% in 0.1006 secs.
  99% in 0.1665 secs.
  99.9% in 0.2903 secs.
```

## Appendix
### Requirements

No requirements.

### Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | 2.2.0 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 3.71.0 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.1.0 |
| <a name="provider_template"></a> [template](#provider\_template) | 2.2.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 3.1.0 |

### Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | 3.11.2 |

### Resources

| Name | Type |
|------|------|
| [aws_autoscaling_group.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_cloudwatch_event_rule.autoscaling](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_rule.ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.lambda-cloudwatch-dns-service-autoscaling](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_event_target.lambda-cloudwatch-dns-service-ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_dlm_lifecycle_policy.automatic_snapshots](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dlm_lifecycle_policy) | resource |
| [aws_ebs_volume.ssd](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_volume) | resource |
| [aws_iam_instance_profile.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.dlm_lifecycle_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.lambda-cloudwatch-dns-service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.dlm_lifecycle](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.lambda-cloudwatch-dns-service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.lambda-cloudwatch-dns-service-logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.lambda-cloudwatch-dns-service-xray](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_key_pair.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/key_pair) | resource |
| [aws_lambda_function.cloudwatch-dns-service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.cloudwatch-dns-service-autoscaling](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_permission.cloudwatch-dns-service-ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_launch_configuration.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_configuration) | resource |
| [aws_lb.nlb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_route53_record.defaultclient](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.defaultssl](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.nlb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.peers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_zone.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |
| [aws_s3_bucket.files](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_object.etcd3-bootstrap-linux-amd64](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_object) | resource |
| [aws_s3_bucket_public_access_block.example](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_security_group.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [local_file.ca-cert](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.client-cert](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.client-key](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [tls_cert_request.client](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/cert_request) | resource |
| [tls_cert_request.peer](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/cert_request) | resource |
| [tls_cert_request.server](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/cert_request) | resource |
| [tls_locally_signed_cert.client](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/locally_signed_cert) | resource |
| [tls_locally_signed_cert.peer](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/locally_signed_cert) | resource |
| [tls_locally_signed_cert.server](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/locally_signed_cert) | resource |
| [tls_private_key.ca](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_private_key.client](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_private_key.peer](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_private_key.server](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_self_signed_cert.ca](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/self_signed_cert) | resource |
| [archive_file.lambda-dns-service](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_subnet.target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [aws_subnets.target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpc.target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |
| [template_file.cloud-init](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |
| [template_file.etcd_bootstrap_unit](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |
| [template_file.etcd_member_unit](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allow_download_from_cidrs"></a> [allow\_download\_from\_cidrs](#input\_allow\_download\_from\_cidrs) | CIDRs from which to allow downloading etcd and etcd-bootstrap binaries via TLS (443 outbound). By default, this is totally open as S3 and GitHub IP addresses are unpredictable. | `list` | <pre>[<br>  "0.0.0.0/0"<br>]</pre> | no |
| <a name="input_ami"></a> [ami](#input\_ami) | AMI to launch with - suggest Debian | `string` | `"ami-050949f5d3aede071"` | no |
| <a name="input_associate_public_ips"></a> [associate\_public\_ips](#input\_associate\_public\_ips) | Whether to associate public IPs with etcd instances (suggest false for security) | `string` | `"false"` | no |
| <a name="input_client_cidrs"></a> [client\_cidrs](#input\_client\_cidrs) | CIDRs to allow client access to etcd | `list` | <pre>[<br>  "10.0.0.0/8"<br>]</pre> | no |
| <a name="input_cluster_size"></a> [cluster\_size](#input\_cluster\_size) | Number of etcd nodes to launch | `number` | `3` | no |
| <a name="input_create_s3_bucket"></a> [create\_s3\_bucket](#input\_create\_s3\_bucket) | Whether to create the S3 bucket used by default for instances to obtain the etcd3-bootstrap binary through cloud-init | `string` | `"true"` | no |
| <a name="input_dns"></a> [dns](#input\_dns) | Domain to install etcd | `map(string)` | <pre>{<br>  "domain_name": "mycompany.local"<br>}</pre> | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Target environment, used to apply tags | `string` | `"development"` | no |
| <a name="input_etcd3_bootstrap_binary_url"></a> [etcd3\_bootstrap\_binary\_url](#input\_etcd3\_bootstrap\_binary\_url) | Custom URL from which to download the etcd3-bootstrap binary | `any` | `null` | no |
| <a name="input_etcd_url"></a> [etcd\_url](#input\_etcd\_url) | Custom URL from which to download the etcd tgz | `any` | `null` | no |
| <a name="input_etcd_version"></a> [etcd\_version](#input\_etcd\_version) | etcd version to install | `string` | `"3.5.1"` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | AWS instance type, at least c5a.large is recommended. etcd suggest m4.large. | `string` | `"c5a.large"` | no |
| <a name="input_key_pair_public_key"></a> [key\_pair\_public\_key](#input\_key\_pair\_public\_key) | Public key for SSH access | `any` | n/a | yes |
| <a name="input_nlb_internal"></a> [nlb\_internal](#input\_nlb\_internal) | 'true' to expose the NLB internally only, 'false' to expose it to the internet | `bool` | `true` | no |
| <a name="input_private_subnet_tags"></a> [private\_subnet\_tags](#input\_private\_subnet\_tags) | Additional tags to apply to private subnets | `map` | `{}` | no |
| <a name="input_public_subnet_tags"></a> [public\_subnet\_tags](#input\_public\_subnet\_tags) | Additional tags to apply to public subnets | `map` | `{}` | no |
| <a name="input_restore_snapshot_ids"></a> [restore\_snapshot\_ids](#input\_restore\_snapshot\_ids) | Map of of the snapshots to use to restore etcd data storage - eg. {0: "snap-abcdef", 1: "snap-fedcba", 2: "snap-012345"} | `map(string)` | `{}` | no |
| <a name="input_role"></a> [role](#input\_role) | Role name used for internal logic | `string` | `"etcd"` | no |
| <a name="input_ssd_size"></a> [ssd\_size](#input\_ssd\_size) | Size (in GB) of the SSD to be used for etcd data storage | `string` | `"100"` | no |
| <a name="input_ssh_cidrs"></a> [ssh\_cidrs](#input\_ssh\_cidrs) | CIDRs to allow SSH access to the nodes from (by default, none) | `list` | `[]` | no |
| <a name="input_subnet_tag_key"></a> [subnet\_tag\_key](#input\_subnet\_tag\_key) | The value of the key in the tag on the subnet to deploy to. By default, we use 'Private' as key to label a private subnet | `string` | `"Private"` | no |
| <a name="input_subnet_tag_value"></a> [subnet\_tag\_value](#input\_subnet\_tag\_value) | The value to search for in the subnet tag from subnet\_tag\_key. By default, this is 'true' with a key of 'Private' | `string` | `"true"` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | The VPC ID to use or 'create' to create a new VPC | `string` | `"create"` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_ca_cert"></a> [ca\_cert](#output\_ca\_cert) | CA certificate to add to client trust stores (also see ./ca.pem) |
| <a name="output_client_cert"></a> [client\_cert](#output\_client\_cert) | Client certificate to use to authenticate with etcd (also see ./client.pem) |
| <a name="output_client_key"></a> [client\_key](#output\_client\_key) | Client private key to use to authenticate with etcd (also see ./client.key) |
| <a name="output_lb_address"></a> [lb\_address](#output\_lb\_address) | Load balancer address for use by clients |
| <a name="output_subnet_ids"></a> [subnet\_ids](#output\_subnet\_ids) | Subnet IDs |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | VPC ID |
