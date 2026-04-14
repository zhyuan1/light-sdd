# Spec: auth

## Requirements

- [ ] REQ-1: Users can initiate OAuth login with Google
- [ ] REQ-2: Users can initiate OAuth login with GitHub
- [ ] REQ-3: Successful OAuth callback creates a session

## Interfaces

```typescript
POST /auth/login/:provider  -> redirects to OAuth provider
GET  /auth/callback/:provider -> handles OAuth callback, sets session
POST /auth/logout -> destroys session
GET  /auth/me -> returns current user or 401
```

## Behavior

### Happy Path

Given a user clicks "Login with Google"
When they authorize the app on Google's consent screen
Then they are redirected back with a valid session cookie

### Edge Cases

- Expired OAuth token returns 401 and prompts re-login
- User denies consent -> redirected to login page with error message

## Dependencies

- `storage` capability for token persistence

## Acceptance Criteria

- [ ] AC-1: OAuth login flow works end-to-end for Google
- [ ] AC-2: OAuth login flow works end-to-end for GitHub
- [ ] AC-3: Unauthorized access returns 401
