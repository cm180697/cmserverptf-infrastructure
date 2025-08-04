# docs/architecture.py

from diagrams import Diagram, Cluster
from diagrams.aws.network import APIGateway, ELB, Route53, CloudFront
from diagrams.aws.storage import S3
from diagrams.aws.compute import Lambda, ECR, ECS
from diagrams.aws.database import Dynamodb
from diagrams.onprem.client import User

with Diagram(
    "AWS Portfolio Architecture",
    show=False,
    filename="docs/architecture",
    outformat="png",
):
    user = User("User")

    with Cluster("AWS Cloud"):
        route53 = Route53("Route 53\n(cmserverptf.click)")

        with Cluster("Frontend"):
            cloudfront = CloudFront("CloudFront CDN")
            s3_bucket = S3("S3 Bucket\n(Static Content)")

        with Cluster("Backend - Serverless Functions"):
            api_gateway = APIGateway("API Gateway")
            lambda_function = Lambda("Visitor Counter\n(Lambda)")
            dynamodb_table = Dynamodb("DynamoDB Table")

        with Cluster("Backend - Containerized Service"):
            alb = ELB("Application\nLoad Balancer")
            ecr = ECR("ECR Registry")
            ecs_service = ECS("ECS Fargate Service\n(Visitor Counter)")

    # Define the data and request flows
    user >> route53 >> cloudfront >> s3_bucket
    user >> api_gateway >> lambda_function >> dynamodb_table
    user >> alb >> ecs_service >> dynamodb_table
