# Design: test-feature

## Architecture Overview

passport.js middleware sits between Express routes and session store. Each OAuth provider is a strategy plugin.

## Key Decisions

### Decision 1: Session store

- **Context**: Need persistent sessions across server restarts
- **Decision**: Use Redis-backed express-session
- **Consequences**: Adds Redis dependency, but enables horizontal scaling

## Data Model

```
User { id, email, name, provider, providerId, createdAt }
Session { sid, userId, expiresAt }
Token { userId, accessToken, refreshToken, expiresAt }
```

## Error Handling

All auth errors return standard JSON: `{ error: string, code: number }`. Never expose internal details.

## Migration

No existing auth system -- greenfield implementation.
