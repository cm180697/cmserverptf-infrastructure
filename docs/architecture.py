# docs/architecture.py

from diagrams import Diagram, Cluster
# Corrected imports for APIGateway, Route53, and CloudFront
from diagrams.aws.network import APIGateway, Route53, CloudFront
from diagrams.aws.storage import S3
from diagrams.aws.compute import Lambda
from diagrams.aws.database import Dynamodb
from diagrams.onprem.client import User

with Diagram("AWS Portfolio Architecture", show=False, filename="architecture", outformat="png"):
    user = User("User")

    with Cluster("AWS Cloud"):
        route53 = Route53("Route 53\n(cmserverptf.click)")

        with Cluster("Frontend"):
            cloudfront = CloudFront("CloudFront CDN")
            s3_bucket = S3("S3 Bucket\n(Static Content)")

        with Cluster("Backend API"):
            api_gateway = APIGateway("API Gateway")
            lambda_function = Lambda("Visitor Counter\nFunction")
            dynamodb_table = Dynamodb("DynamoDB Table")

    # Connect the components
    user >> route53
    route53 >> cloudfront >> s3_bucket
    user >> api_gateway >> lambda_function >> dynamodb_table