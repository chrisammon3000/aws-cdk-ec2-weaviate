# aws-cdk-ec2-weaviate
CDK application to deploy a Weaviate instance on an EC2 instance.

## Table of Contents
- [aws-cdk-ec2-weaviate](#aws-cdk-ec2-weaviate)
  - [Table of Contents](#table-of-contents)
  - [Project Structure](#project-structure)
  - [Description](#description)
  - [Quickstart](#quickstart)
  - [Installation](#installation)
    - [Prerequisites](#prerequisites)
    - [Environment Variables](#environment-variables)
    - [CDK Application Configuration](#cdk-application-configuration)
    - [AWS Credentials](#aws-credentials)
  - [Usage](#usage)
    - [Makefile Usage](#makefile-usage)
    - [Docker](#docker)
    - [AWS Deployment](#aws-deployment)
    - [CDK Commands](#cdk-commands)
  - [Troubleshooting](#troubleshooting)
  - [References \& Links](#references--links)
  - [Authors](#authors)

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
Deploy Weaviate on an Ubuntu EC2 instance using AWS CDK. Configures Weaviate to use `text2vec-transformers` and `sentence-transformers-multi-qa-MiniLM-L6-cos-v1` for text2vec. Uses a basic example with two classes, `Article` and `Author` with one cross-reference `hasArticle`.

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
                "ssh_key_name": "aws-cdk-ec2-weaviate-key-pair"
            }
        }
    },
    "tags": {
        "org": "my-organization", // Update to your organization
        "app": "aws-cdk-ec2-weaviate"
    }
}
```

***Important:*** *Make sure that `tsconfig.json` is configured with `"resolveJsonModule": true`.*

### AWS Credentials
Valid AWS credentials must be available to AWS CLI and SAM CLI. The easiest way to do this is running `aws configure`, or by adding them to `~/.aws/credentials` and exporting the `AWS_PROFILE` variable to the environment.

For more information visit the documentation page:
[Configuration and credential file settings](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)

### Weaviate Configuration
Weaviate is configured using EC2 user data in `src/config.sh`. There are 3 main steps:
1. Download the Docker Compose file from [Weaviate](https://weaviate.io/developers/weaviate/installation/docker-compose).
2. Update the Docker Compose file to configure Weaviate to persist data and automatically restart on reboot.
3. Run the Docker Compose file.

All of these steps are handled by the user data script, but keep in mind that if any changes are made the script may need to be updated.

#### Download the Docker Compose File
Run the command to download a Docker Compose file for Weaviate. To configure Docker Compose via the download URL visit https://weaviate.io/developers/weaviate/installation/docker-compose and use the Configurator.
```bash
curl -o docker-compose.yaml "https://configuration.weaviate.io/v2/docker-compose/docker-compose.yml?generative_cohere=false&generative_openai=false&generative_palm=false&gpu_support=false&media_type=text&modules=modules&ner_module=false&qna_module=false&ref2vec_centroid=false&runtime=docker-compose&spellcheck_module=false&sum_module=false&text_module=text2vec-transformers&transformers_model=sentence-transformers-multi-qa-MiniLM-L6-cos-v1&weaviate_version=v1.19.8"
```

#### Update the Docker Compose File
Next, run the command to configure Weaviate to persist data and automatically restart on reboot.
```bash
awk '
  /^  weaviate:$/ {
    print
    print "    restart: always"
    print "    volumes:"
    print "      - /data/weaviate:/var/lib/weaviate"
    while(getline && $0 !~ /^  /);
    if ($0 ~ /^  /) {
      print
    }
    next
  }
  /^  t2v-transformers:$/ {
    print
    print "    restart: always"
    while(getline && $0 !~ /^  /);
    if ($0 ~ /^  /) {
      print
    }
    next
  }
  /CLUSTER_HOSTNAME: '\''node1'\''/ {
    print
    print "      AUTOSCHEMA_ENABLED: '\''false'\''"
    next
  }
  /restart: on-failure:0/ {
    next
  }
  1' docker-compose.yaml > docker-compose-temp.yaml && mv docker-compose-temp.yaml docker-compose.yaml
```

#### Run the Docker Compose File
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
Once an AWS profile is configured and environment variables are available, the application can be deployed using `make`.
```bash
make deploy
```

An SSH key will be created in the project's root directory. To SSH into the instance you will need to update the permissions.
```bash
chmod 400 aws-cdk-ec2-weaviate-key-pair.pem
```

More information about how to SSH into an EC2 instance can be found in the [AWS documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AccessingInstancesLinux.html).

### Weaviate
You can define your schema any way you desire and use the Make targets to create or delete ths schema. The schema is stored in `schema.json`.

#### Create the Schema
```bash
make weaviate.schema.create
```

#### Delete the Schema
```bash
make weaviate.schema.delete
```

### CDK Commands

* `npm run build`   compile typescript to js
* `npm run watch`   watch for changes and compile
* `npm run test`    perform the jest unit tests
* `cdk deploy`      deploy this stack to your default AWS account/region
* `cdk diff`        compare deployed stack with current state
* `cdk synth`       emits the synthesized CloudFormation template

## Troubleshooting
* Check your AWS credentials in `~/.aws/credentials`
* Check that the environment variables are available to the services that need them

## References & Links
- [Weaviate Documentation](https://www.semi.technology/developers/weaviate/current/index.html)
- [Weaviate GraphQL API](https://weaviate.io/developers/weaviate/current/graphql-references/index.html)
- [Weaviate Docker Compose](https://weaviate.io/developers/weaviate/installation/docker-compose)

## Authors
**Primary Contact:** [@chrisammon3000](https://github.com/chrisammon3000)
