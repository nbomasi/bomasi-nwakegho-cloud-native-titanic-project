"""
Authentication and authorization module
"""
import os
import logging
from datetime import datetime, timedelta
from functools import wraps
from typing import Optional, Dict, Any

import jwt
from flask import request, jsonify, Response

logger = logging.getLogger(__name__)


def get_jwt_secret() -> Optional[str]:
    """
    Get JWT secret key from environment variables

    Returns:
        JWT secret key, or None if not set

    Note: Returns None instead of raising to allow graceful degradation
    """
    secret = os.getenv("JWT_SECRET_KEY")
    if not secret:
        logger.warning("JWT_SECRET_KEY environment variable is not set. Authentication will be disabled.")
        return None
    return secret


def generate_token(user_id: str, username: str, roles: list = None, expires_in: int = 3600) -> str:
    """
    Generate a JWT token for a user

    Parameters:
        user_id: Unique user identifier
        username: Username
        roles: List of user roles (default: ['user'])
        expires_in: Token expiration time in seconds (default: 1 hour)

    Returns:
        Encoded JWT token

    Raises:
        ValueError: If JWT_SECRET_KEY is not set
    """
    secret = get_jwt_secret()
    if not secret:
        raise ValueError("JWT_SECRET_KEY environment variable is not set. Cannot generate token.")

    if roles is None:
        roles = ["user"]

    payload = {
        "user_id": user_id,
        "username": username,
        "roles": roles,
        "iat": datetime.utcnow(),
        "exp": datetime.utcnow() + timedelta(seconds=expires_in),
    }

    try:
        token = jwt.encode(payload, secret, algorithm="HS256")
        return token
    except Exception as e:
        logger.error(f"Failed to generate token: {e}")
        raise


def verify_token(token: str) -> Optional[Dict[str, Any]]:
    """
    Verify and decode a JWT token

    Parameters:
        token: JWT token string

    Returns:
        Decoded token payload if valid, None otherwise
    """
    secret = get_jwt_secret()
    if not secret:
        logger.warning("JWT_SECRET_KEY not set. Cannot verify token.")
        return None

    try:
        payload = jwt.decode(token, secret, algorithms=["HS256"])
        return payload
    except jwt.ExpiredSignatureError:
        logger.warning("Token has expired")
        return None
    except jwt.InvalidTokenError as e:
        logger.warning(f"Invalid token: {e}")
        return None
    except Exception as e:
        logger.error(f"Token verification failed: {e}")
        return None


def get_token_from_request() -> Optional[str]:
    """
    Extract JWT token from request headers

    Supports:
    - Authorization header: "Bearer <token>"
    - Authorization header: "Token <token>"

    Returns:
        Token string if found, None otherwise
    """
    auth_header = request.headers.get("Authorization")
    if not auth_header:
        return None

    parts = auth_header.split()
    if len(parts) != 2:
        return None

    scheme, token = parts
    if scheme.lower() not in ("bearer", "token"):
        return None

    return token


def require_auth(f):
    """
    Decorator to require authentication for an endpoint

    Usage:
        @app.route('/protected')
        @require_auth
        def protected_endpoint():
            user = request.current_user
            return jsonify({'message': f'Hello {user["username"]}'})
    """

    @wraps(f)
    def decorated_function(*args, **kwargs):
        token = get_token_from_request()
        if not token:
            return jsonify({"error": "Authentication required", "message": "Missing or invalid Authorization header"}), 401

        payload = verify_token(token)
        if not payload:
            return jsonify({"error": "Invalid token", "message": "Token is expired or invalid"}), 401

        request.current_user = payload
        return f(*args, **kwargs)

    return decorated_function


def require_role(*allowed_roles):
    """
    Decorator to require specific role(s) for an endpoint

    Usage:
        @app.route('/admin')
        @require_auth
        @require_role('admin')
        def admin_endpoint():
            return jsonify({'message': 'Admin access granted'})
    """

    def decorator(f):
        @wraps(f)
        @require_auth
        def decorated_function(*args, **kwargs):
            user_roles = request.current_user.get("roles", [])
            if not any(role in user_roles for role in allowed_roles):
                return jsonify({"error": "Insufficient permissions", "message": f"Required roles: {allowed_roles}"}), 403
            return f(*args, **kwargs)

        return decorated_function

    return decorator
