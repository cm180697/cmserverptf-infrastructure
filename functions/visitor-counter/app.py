import boto3
import os
import json


def lambda_handler(event, context):
    """
    This function is triggered by an API Gateway request. It increments a
    counter in a DynamoDB table and returns the new count.
    """
    TABLE_NAME = os.environ.get("TABLE_NAME")
    PRIMARY_KEY = os.environ.get("PRIMARY_KEY")
    dynamodb = boto3.resource("dynamodb")
    table = dynamodb.Table(TABLE_NAME)

    try:
        response = table.update_item(
            Key={"id": PRIMARY_KEY},
            UpdateExpression="add visitor_count :val",
            ExpressionAttributeValues={":val": 1},
            ReturnValues="UPDATED_NEW",
        )

        new_count = response["Attributes"]["visitor_count"]
        body = json.dumps({"count": int(new_count)})

        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
            },
            "body": body,
        }

    except Exception as e:
        print(f"Error: {e}")
        error_body = json.dumps({"error": "Could not process request."})

        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
            },
            "body": error_body,
        }
