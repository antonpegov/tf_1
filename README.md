# AWS

## Prerequisites

### Create AWS setup file `setup-aws.sh` with following content:
<pre> #!/bin/bash

  export AWS_ACCESS_KEY_ID=[your access key]
  export AWS_SECRET_ACCESS_KEY=[your secret key]
  export AWS_DEFAULT_REGION=[your region]
</pre>

## Tools
  - Bash
  - AWS CLI
  - Terraform CLI*
  - Packer CLI*

  * - put executables to `bin` folder and add it to `PATH`

## Set AWS credentials
`. setup-aws.sh` - set AWS credentials for current session

`aws sts get-caller-identity` - check that AWS credentials set properly

## Terraform

`terraform init` - initialize terraform

`terraform plan` - show what will be created

`terraform apply` - create resources

`terraform destroy` - destroy resources
