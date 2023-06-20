import * as config from '../config.json';
import * as cdk from 'aws-cdk-lib';
import { Weaviate } from './vector-database';

export class WeaviateStack extends cdk.Stack {
  constructor(scope: cdk.App, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const weaviate = new Weaviate(this, 'Weaviate');

  }
}
