import * as path from 'path';
import * as config from '../config.json';
import cdk = require('aws-cdk-lib');
import { Construct } from 'constructs';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Asset } from 'aws-cdk-lib/aws-s3-assets';
import * as ssm from 'aws-cdk-lib/aws-ssm';

export class Weaviate extends Construct {
    public readonly vpc: ec2.IVpc;
    public readonly endpointSsmParamName: string;
    public readonly loadAmzOdrTaskSecurityGroup: ec2.ISecurityGroup;
    constructor(scope: Construct, id: string) {
        super(scope, id);

        // // uncomment to deploy a new VPC
        // this.vpc = new ec2.Vpc(this, 'VPC', {
        //     natGateways: 0,
        //     subnetConfiguration: [{
        //         name: 'Vpc',
        //         subnetType: ec2.SubnetType.PUBLIC,
        //         cidrMask: 24
        //     }],
        //     enableDnsHostnames: true,
        //     enableDnsSupport: true
        // });

        // uncomment to use the existing default VPC
        this.vpc = ec2.Vpc.fromLookup(this, 'VPC', {
            isDefault: true,
          });

        // Weaviate instance security group
        const securityGroup = new ec2.SecurityGroup(this, 'WeaviateSecurityGroup', {
            vpc: this.vpc,
            allowAllOutbound: true,
            description: 'Allow SSH (TCP port 22) in',
        });

        // Allow connections from your IP address (set in config.json)
        securityGroup.addIngressRule(
            ec2.Peer.ipv4(config.layers.vector_database.env.ssh_cidr),
            ec2.Port.tcp(8080),
            'Allow Weaviate access');

        securityGroup.addIngressRule(
            ec2.Peer.ipv4(config.layers.vector_database.env.ssh_cidr),
            ec2.Port.tcp(22),
            'Allow SSH');

        // IAM role for the instance allows SSM access
        const role = new iam.Role(this, 'Role', {
            assumedBy: new iam.ServicePrincipal('ec2.amazonaws.com'),
            managedPolicies: [
                iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonSSMManagedInstanceCore'),
            ]
        });
        
        // Ubuntu 20.04 LTS AMI
        const ami = ec2.MachineImage.fromSsmParameter('/aws/service/canonical/ubuntu/eks/20.04/1.21/stable/current/amd64/hvm/ebs-gp2/ami-id');
        
        // create the instance
        const instance = new ec2.Instance(this, 'VectorDatabase', {
            vpc: this.vpc,
            instanceType: ec2.InstanceType.of(ec2.InstanceClass.M6I, ec2.InstanceSize.XLARGE),
            machineImage: ami,
            securityGroup,
            keyName: config.layers.vector_database.env.ssh_key_name,
            role,
            instanceName: config.tags.app,
            blockDevices: [{
                deviceName: '/dev/xvda',
                volume: ec2.BlockDeviceVolume.ebs(config.layers.vector_database.env.ebs_volume_size)
            }]
        });

        // add the user data script
        const userData = new Asset(this, 'UserData', {
            path: path.join(__dirname, '../src/config.sh')
        });

        const localPath = instance.userData.addS3DownloadCommand({
            bucket: userData.bucket,
            bucketKey: userData.s3ObjectKey
        });

        instance.userData.addExecuteFileCommand({
            filePath: localPath,
            arguments: '--verbose -y'
        });
        userData.grantRead(instance.role);

        // create an elastic IP and associate it with the instance
        const eip = new ec2.CfnEIP(this, 'EIP', {
            domain: 'vpc'
        });

        // associate the EIP with the instance
        new ec2.CfnEIPAssociation(this, 'EIPAssociation', {
            allocationId: eip.attrAllocationId,
            instanceId: instance.instanceId
        });

        // SSM parameters
        const instanceIdSsmParam = new ssm.StringParameter(this, 'InstanceId', {
            parameterName: `/${config.tags.org}/${config.tags.app}/InstanceId`,
            simpleName: false,
            stringValue: instance.instanceId
        });

        const endpointValue = `http://${eip.attrPublicIp}:8080`
        const endpointSsmParam = new ssm.StringParameter(this, 'WeaviateEndpointParam', {
            parameterName: `/${config.tags.org}/${config.tags.app}/WeaviateEndpoint`,
            simpleName: false,
            stringValue: endpointValue
        });
        this.endpointSsmParamName = endpointSsmParam.parameterName
        new cdk.CfnOutput(this, 'WeaviateEndpointOutput', { value: endpointValue });
    }
}