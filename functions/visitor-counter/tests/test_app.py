import os
import sys

# We need to add the parent directory to the path to find the app module.
# This allows us to import the 'app' module from the parent directory.
# We construct the path and insert it at the beginning of the system path.
parent_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, parent_dir)

import boto3
import pytest
from moto import mock_aws

from app import lambda_handler


@pytest.fixture
def aws_credentials():
    """Mocked AWS Credentials for moto."""
    os.environ["AWS_ACCESS_KEY_ID"] = "testing"
    os.environ["AWS_SECRET_ACCESS_KEY"] = "testing"
    os.environ["AWS_SECURITY_TOKEN"] = "testing"
    os.environ["AWS_SESSION_TOKEN"] = "testing"
    os.environ["AWS_DEFAULT_REGION"] = "us-east-2"


@pytest.fixture
def dynamodb_table(aws_credentials):
    """Create a mock DynamoDB table."""
    with mock_aws():
        client = boto3.client("dynamodb", region_name="us-east-2")
        table_name = "test-visitor-table"
        client.create_table(
            TableName=table_name,
            KeySchema=[{"AttributeName": "id", "KeyType": "HASH"}],
            AttributeDefinitions=[{"AttributeName": "id", "AttributeType": "S"}],
            ProvisionedThroughput={"ReadCapacityUnits": 1, "WriteCapacityUnits": 1},
        )
        yield table_name


def test_lambda_handler_increments_count(dynamodb_table):
    """
    Test that the lambda_handler successfully increments the visitor count.
    """
    # Set environment variables for the handler
    os.environ["TABLE_NAME"] = dynamodb_table
    os.environ["PRIMARY_KEY"] = "visitor_count"

    # Call the lambda handler
    response = lambda_handler(event={}, context={})

    # Check the response
    assert response["statusCode"] == 200
    assert response["headers"]["Content-Type"] == "application/json"
    assert '"count": 1' in response["body"]

    # Call it again to ensure it increments
    response_2 = lambda_handler(event={}, context={})
    assert response_2["statusCode"] == 200
    assert '"count": 2' in response_2["body"]
