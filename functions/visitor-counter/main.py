import json
from fastapi import FastAPI
from fastapi.responses import JSONResponse

# We can reuse the tested handler logic from our original app
from app import lambda_handler

app = FastAPI()


@app.get("/")
def read_root():
    """
    This endpoint is called by the web server.
    It invokes the original lambda_handler and returns its response.
    """
    lambda_response = lambda_handler({}, {})

    # The lambda body is a string, so we need to parse it back into a dict
    content_body = json.loads(lambda_response["body"])

    return JSONResponse(
        status_code=lambda_response["statusCode"],
        content=content_body,
        headers=lambda_response.get("headers", {}),
    )
