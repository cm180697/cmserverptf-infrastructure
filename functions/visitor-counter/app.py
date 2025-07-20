import boto3
import os

def lambda_handler(event, context):
    """
    This function is triggered by an API Gateway request. It increments a
    counter in a DynamoDB table and returns the new count.
    """
    # --- Initialize boto3 objects inside the handler ---
    TABLE_NAME = os.environ.get("TABLE_NAME")
    PRIMARY_KEY = os.environ.get("PRIMARY_KEY")
    dynamodb = boto3.resource("dynamodb")
    table = dynamodb.Table(TABLE_NAME)

    try:
        # Use update_item to atomically increment the 'visitor_count' attribute.
        response = table.update_item(
            Key={"id": PRIMARY_KEY},
            UpdateExpression="add visitor_count :val",
            ExpressionAttributeValues={":val": 1},
            ReturnValues="UPDATED_NEW",
        )

        # Extract the new count from the response
        new_count = response["Attributes"]["visitor_count"]

        # Return a successful response with the new count
        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
            },
            "body": f'{{"count": {new_count}}}',
        }

    except Exception as e:
        # Log the error for debugging
        print(f"Error: {e}")

        # Return an error response
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
            },
            "body": '{"error": "Could not process request."}',
        }