# aws-cdk-ec2-weaviate
CDK application to deploy a Weaviate instance on an EC2 instance.

## Table of Contents
- [aws-cdk-ec2-weaviate](#aws-cdk-ec2-weaviate)
  * [Table of Contents](#table-of-contents)
  * [Project Structure](#project-structure)
  * [Description](#description)
  * [Quickstart](#quickstart)
  * [Installation](#installation)
    + [Prerequisites](#prerequisites)
    + [Environment Variables](#environment-variables)
    + [CDK Application Configuration](#cdk-application-configuration)
    + [AWS Credentials](#aws-credentials)
    + [Weaviate Configuration](#weaviate-configuration)
      - [Run the Docker Compose File Locally](#run-the-docker-compose-file-locally)
  * [Usage](#usage)
    + [Makefile](#makefile)
    + [AWS Deployment](#aws-deployment)
    + [Weaviate](#weaviate)
      - [Create the Schema](#create-the-schema)
      - [Delete the Schema](#delete-the-schema)
  * [Troubleshooting](#troubleshooting)
  * [References & Links](#references---links)
  * [Authors](#authors)

## Project Structure
```bash
.
├── Makefile
├── README.md
├── (aws-cdk-ec2-weaviate-key-pair.pem)
├── bin
├── cdk.context.json
├── cdk.json
├── config.json
├── lib
├── package.json
├── scripts
├── src
└── tsconfig.json
```

## Description
Deploy Weaviate on an EC2 instance using AWS CDK. Configures Weaviate to use `text2vec-transformers` and `qna-transformers`. Creates an example schema with two classes, `Article` and `Author` with one cross-reference `hasArticle`.

## Quickstart
1. Configure your AWS credentials.
2. Add environment variables to `.env`.
3. Update `config.json` if desired.
4. Run `npm install` to install TypeScript dependencies.
5. Run `make deploy` to deploy the app.

## Installation
Follow the steps to configure the deployment environment.

### Prerequisites
* Nodejs >= 18.0.0
* TypeScript >= 5.1.3
* AWS CDK >= 2.84.0
* AWSCLI
* jq

### Environment Variables
Sensitive environment variables containing secrets like passwords and API keys must be exported to the environment first.

Create a `.env` file in the project root.
```bash
CDK_DEFAULT_ACCOUNT=<account_id>
CDK_DEFAULT_REGION=<region>
```

***Important:*** *Always use a `.env` file or AWS SSM Parameter Store or Secrets Manager for sensitive variables like credentials and API keys. Never hard-code them, including when developing. AWS will quarantine an account if any credentials get accidentally exposed and this will cause problems.*

***Make sure that `.env` is listed in `.gitignore`***

### CDK Application Configuration
The CDK application configuration is stored in `config.json`. This file contains values for the database layer, the data ingestion layer, and tags. You can update the tags and SSH IP to your own values before deploying.
```json
{
    "layers": {
        "vector_database": {
            "env": {
                "ssh_cidr": "0.0.0.0/0", // Update to your IP
                "ssh_key_name": "aws-cdk-ec2-weaviate-key-pair",
                "ebs_volume_size": 64
            }
        }
    },
    "tags": {
        "org": "my-organization", // Update to your organization
        "app": "aws-cdk-ec2-weaviate"
    }
}
```

***Important:*** *Make sure that `tsconfig.json` is configured with `"resolveJsonModule": true` so that `config.json` is imported correctly.*

### AWS Credentials
Valid AWS credentials must be available to AWS CLI and SAM CLI. The easiest way to do this is running `aws configure`, or by adding them to `~/.aws/credentials` and exporting the `AWS_PROFILE` variable to the environment.

For more information visit the documentation page:
[Configuration and credential file settings](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)

### Weaviate Configuration
Weaviate is configured using Docker Compose. To obtain an up-to-date Docker Compose file you can use the Configurator at https://weaviate.io/developers/weaviate/installation/docker-compose and make sure to include a persistent volume.

Once you have downloaded the Docker Compose file, you will need to update make some changes to the configuration for it to run on EC2:
1. Configure the database and module containers to restart automatically on reboot.
```docker
version: '3.4'
services:
  weaviate:
    restart: always # Always restart when the instance reboots
    ...
  t2v-transformers:
    restart: always
    ...
  qna-transformers:
    restart: always
```

2. Configure the database container to persist data to the `/data` directory where the EBS volume is mounted.
```docker
version: '3.4'
services:
  weaviate:
    ...
    volumes:
    - /opt/data/weaviate_data:/var/lib/weaviate
```

3. Disable the auto-schema feature.
```docker
version: '3.4'
services:
  weaviate:
    ...
    environment:
      ...
      AUTOSCHEMA_ENABLED: 'false'
```

#### Run the Docker Compose File Locally
Configure the mounted volume to point to a local directory.
```docker
version: '3.4'
services:
  weaviate:
    ...
    volumes:
    - weaviate_data:/var/lib/weaviate # Change to a local directory
```

Finally, run the command to start Weaviate.
```bash
docker-compose up -d
```

## Usage

### Makefile
```bash
# Deploy AWS resources
make deploy

# Destroy the application
make destroy

# Get the status of Weaviate
make weaviate.status

# Stop Weaviate
make weaviate.stop

# Start Weaviate
make weaviate.start

# Restart Weaviate
make weaviate.restart

# Get the endpoint for Weaviate
make weaviate.get.endpoint

# Create the Weaviate schema
make weaviate.schema.create

# Delete the Weaviate schema
make weaviate.schema.delete
```

### AWS Deployment
Once the AWS profile and environment variables are configured, the application can be deployed using `make`. Deployment takes about 15 minutes because of the size of the transformers modules.
```bash
# Deploy the application
make deploy
```
The deploy command will build a CloudFormation template from the CDK app, deploy it, run the Weaviate service and create the schema once they are available.

An SSH key will be created in the project's root directory. To SSH into the instance you will need to update the permissions.
```bash
chmod 400 aws-cdk-ec2-weaviate-key-pair.pem

# SSH into the instance using just the IP address
ssh -i aws-cdk-ec2-weaviate-key-pair.pem ec2-user@<instance_ip>
```

More information about how to SSH into an EC2 instance can be found in the [AWS documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AccessingInstancesLinux.html).

### Weaviate
You can define your schema any way you desire and use the Make targets to create or delete ths schema while the instance is running. The schema is stored in `schema.json`.

#### Create the Schema
```bash
make weaviate.schema.create
```

#### Delete the Schema
```bash
make weaviate.schema.delete
```

## Troubleshooting
* Check your AWS credentials in `~/.aws/credentials`
* Check that the environment variables are available to the services that need them

## References & Links
- [Weaviate Documentation](https://www.semi.technology/developers/weaviate/current/index.html)
- [Weaviate GraphQL API](https://weaviate.io/developers/weaviate/current/graphql-references/index.html)
- [Weaviate Docker Compose](https://weaviate.io/developers/weaviate/installation/docker-compose)

## Authors
**Primary Contact:** [@chrisammon3000](https://github.com/chrisammon3000)
