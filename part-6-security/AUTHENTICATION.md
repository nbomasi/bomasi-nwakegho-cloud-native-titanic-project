# API Authentication & Authorization Guide

## Overview

The Titanic API now implements JWT (JSON Web Token) based authentication and authorization. All API endpoints (except `/health` and `/`) require authentication.

## Authentication Flow

```
1. Client → POST /auth/login (username, password)
2. Server → Returns JWT token
3. Client → Includes token in Authorization header for subsequent requests
4. Server → Validates token and processes request
```

## Endpoints

### Public Endpoints (No Authentication Required)

- `GET /` - Welcome message
- `GET /health` - Health check endpoint
- `POST /auth/login` - Login to get token
- `POST /auth/verify` - Verify token validity

### Protected Endpoints (Authentication Required)

- `GET /people` - Get all people (requires authentication)
- `GET /people/<uuid>` - Get person by ID (requires authentication)
- `POST /people` - Add new person (requires authentication)
- `PUT /people/<uuid>` - Update person (requires authentication)
- `DELETE /people/<uuid>` - Delete person (requires admin role)

### Authentication Endpoints

- `POST /auth/login` - Login and get JWT token
- `GET /auth/me` - Get current user information (requires authentication)
- `POST /auth/verify` - Verify token validity

## Usage Examples

### 1. Login and Get Token

```bash
curl -X POST https://titanic-api.iyere.site/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "user1",
    "password": "password123"
  }'
```

**Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "user1",
    "username": "user1",
    "roles": ["user"]
  },
  "expires_in": 3600
}
```

### 2. Access Protected Endpoint

```bash
curl -X GET https://titanic-api.iyere.site/people \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

### 3. Get Current User

```bash
curl -X GET https://titanic-api.iyere.site/auth/me \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Response:**
```json
{
  "user": {
    "id": "user1",
    "username": "user1",
    "roles": ["user"]
  }
}
```

### 4. Verify Token

```bash
curl -X POST https://titanic-api.iyere.site/auth/verify \
  -H "Content-Type: application/json" \
  -d '{
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }'
```

## Authentication Methods

### Method 1: Bearer Token (Recommended)

```bash
Authorization: Bearer <token>
```

### Method 2: Token Prefix

```bash
Authorization: Token <token>
```

## Roles and Permissions

### User Role (`user`)
- Can read all people (`GET /people`, `GET /people/<uuid>`)
- Can create new people (`POST /people`)
- Can update people (`PUT /people/<uuid>`)

### Admin Role (`admin`)
- All user permissions
- Can delete people (`DELETE /people/<uuid>`)

### Default Credentials

For demonstration purposes, the following credentials are available:

**Regular User:**
- Username: Any username
- Password: Any password
- Role: `user`

**Admin User:**
- Username: `admin` (or set via `ADMIN_USERNAME` env var)
- Password: `admin` (or set via `ADMIN_PASSWORD` env var)
- Role: `admin`

**Note**: In production, replace the simple authentication logic with proper user database verification.

## Error Responses

### 401 Unauthorized

**Missing Token:**
```json
{
  "error": "Authentication required",
  "message": "Missing or invalid Authorization header"
}
```

**Invalid Token:**
```json
{
  "error": "Invalid token",
  "message": "Token is expired or invalid"
}
```

### 403 Forbidden

**Insufficient Permissions:**
```json
{
  "error": "Insufficient permissions",
  "message": "Required roles: ['admin']"
}
```

## Token Details

- **Algorithm**: HS256
- **Expiration**: 1 hour (3600 seconds)
- **Payload**:
  ```json
  {
    "user_id": "user1",
    "username": "user1",
    "roles": ["user"],
    "iat": 1234567890,
    "exp": 1234571490
  }
  ```

## Security Considerations

1. **Token Storage**: Store tokens securely (e.g., httpOnly cookies, secure storage)
2. **HTTPS Only**: Always use HTTPS in production
3. **Token Expiration**: Tokens expire after 1 hour
4. **Secret Key**: JWT secret is stored in AWS Secrets Manager
5. **No Token Refresh**: Currently, users must re-login after token expiration

## Implementation Details

### Authentication Module (`src/auth.py`)

- `generate_token()` - Generate JWT token
- `verify_token()` - Verify and decode token
- `require_auth` - Decorator for authentication
- `require_role()` - Decorator for role-based authorization

### Authentication Views (`src/views/auth.py`)

- `/auth/login` - Login endpoint
- `/auth/me` - Current user endpoint
- `/auth/verify` - Token verification endpoint

### Protected Endpoints

All endpoints in `src/views/people.py` are protected with `@require_auth` decorator. The delete endpoint additionally requires admin role with `@require_role('admin')`.

## Production Recommendations

1. **User Database**: Replace simple authentication with proper user database
2. **Password Hashing**: Use bcrypt or similar for password hashing
3. **Token Refresh**: Implement refresh token mechanism
4. **Rate Limiting**: Add rate limiting to login endpoint
5. **Audit Logging**: Log authentication events
6. **Multi-Factor Authentication**: Consider adding MFA for sensitive operations

## Testing

### Test Authentication Flow

```bash
# 1. Login
TOKEN=$(curl -s -X POST https://titanic-api.iyere.site/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "testuser", "password": "testpass"}' \
  | jq -r '.token')

# 2. Access protected endpoint
curl -X GET https://titanic-api.iyere.site/people \
  -H "Authorization: Bearer $TOKEN"

# 3. Test admin endpoint (will fail without admin role)
curl -X DELETE https://titanic-api.iyere.site/people/<uuid> \
  -H "Authorization: Bearer $TOKEN"
```

## Troubleshooting

### Token Not Working

1. Check token expiration: `exp` claim in token
2. Verify Authorization header format: `Bearer <token>` or `Token <token>`
3. Check JWT_SECRET_KEY is set in environment
4. Verify token was generated for the same secret key

### 401 Unauthorized

- Ensure Authorization header is included
- Check token format (Bearer or Token prefix)
- Verify token is not expired
- Check JWT_SECRET_KEY matches between token generation and verification

### 403 Forbidden

- Verify user has required role
- Check role assignment in token payload
- Ensure `@require_role()` decorator matches user roles
