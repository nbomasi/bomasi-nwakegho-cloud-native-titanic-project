"""
Authentication views module
"""
import os
import logging
from flask import request, json, Response, Blueprint

from ..auth import generate_token, require_auth

logger = logging.getLogger(__name__)

auth_api = Blueprint("auth", __name__)


@auth_api.route("auth/login", methods=["POST"])
def login() -> Response:
    """
    Login endpoint to generate JWT token

    Request body:
        {
            "username": "string",
            "password": "string"
        }

    Returns:
        JWT token and user information
    """
    try:
        request_data = request.get_json()
        if not request_data:
            return custom_response({"error": "Invalid request", "message": "Request body is required"}, 400)

        username = request_data.get("username")
        password = request_data.get("password")

        if not username or not password:
            return custom_response({"error": "Invalid credentials", "message": "Username and password are required"}, 400)

        # Simple authentication (in production, verify against database)
        # For demo purposes, accept any username/password
        # In production, verify credentials against user database
        user_id = username
        roles = ["user"]

        # Check for admin user (example)
        admin_username = os.getenv("ADMIN_USERNAME", "admin")
        admin_password = os.getenv("ADMIN_PASSWORD", "admin")
        if username == admin_username and password == admin_password:
            roles = ["user", "admin"]

        token = generate_token(user_id=user_id, username=username, roles=roles)

        return custom_response(
            {
                "token": token,
                "user": {
                    "id": user_id,
                    "username": username,
                    "roles": roles,
                },
                "expires_in": 3600,
            },
            200,
        )
    except ValueError as e:
        logger.error(f"Login failed - JWT not available: {e}")
        return custom_response({"error": "Authentication unavailable", "message": "JWT authentication is not configured. Please install PyJWT and set JWT_SECRET_KEY."}, 503)
    except Exception as e:
        logger.error(f"Login failed: {e}")
        return custom_response({"error": "Login failed", "message": str(e)}, 500)


@auth_api.route("auth/me", methods=["GET"])
@require_auth
def get_current_user() -> Response:
    """
    Get current authenticated user information

    Requires:
        Authorization header with Bearer token

    Returns:
        Current user information
    """
    user = request.current_user
    return custom_response(
        {
            "user": {
                "id": user.get("user_id"),
                "username": user.get("username"),
                "roles": user.get("roles", []),
            }
        },
        200,
    )


@auth_api.route("auth/verify", methods=["POST"])
def verify_token_endpoint() -> Response:
    """
    Verify if a token is valid

    Request body:
        {
            "token": "string"
        }

    Returns:
        Token validity status
    """
    try:
        request_data = request.get_json()
        if not request_data:
            return custom_response({"error": "Invalid request", "message": "Request body is required"}, 400)

        token = request_data.get("token")
        if not token:
            return custom_response({"error": "Invalid request", "message": "Token is required"}, 400)

        from ..auth import verify_token

        payload = verify_token(token)
        if payload:
            return custom_response({"valid": True, "user": payload}, 200)
        else:
            return custom_response({"valid": False, "message": "Token is invalid or expired"}, 401)
    except Exception as e:
        logger.error(f"Token verification failed: {e}")
        return custom_response({"error": "Verification failed", "message": str(e)}, 500)


def custom_response(response_body: dict, status_code: int) -> Response:
    """
    Wrapper function creating a response with common parameters

    Parameters:
        response_body: the response body
        status_code: the status code of the response

    Returns:
        The Response object that Flask can return
    """
    return Response(
        mimetype="application/json",
        response=json.dumps(response_body),
        status=status_code,
    )
