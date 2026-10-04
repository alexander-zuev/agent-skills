# Security

Read for authentication, authorization, public inputs, uploads, or secret handling.

## Identity and access

- Store sessions in KV or a database with a 7–30 day TTL. Rotate sessions on privilege escalation.
- Use Durable Objects or Redis for rate limits. Defaults are 10 requests/minute for authentication and 100 for APIs.
- Return 429 with `Retry-After` when limited.
- Authenticate at the entrypoint. Enforce authorization against the resource owner in the application operation.
- Never trust client-supplied owner IDs. Compare resource ownership with the authenticated identity.

## Inputs and files

Parse untrusted API inputs through the declared schema. Use the typescript-standards skill for schema conventions.
Use parameterized SQL and allowlisted paths. Reject path traversal.
Check file MIME type and size on the server. Scan file content and use presigned URLs for large files.

## Secrets

Keep unencrypted secrets out of Git, logs, errors, and frontend code.
Use gitignored local secret files or the project's encrypted dotenvx workflow.
Use platform secret storage in production. Rotate secrets and grant least privilege.
Generate API keys with cryptographic entropy. Hash keys used for authentication.
Avoid sequential public identifiers.

## Browser boundaries

Use explicit allowed CORS origins. Do not allow every origin in production.
Use SameSite cookies and the project's CSRF protection for state changes.
Preserve global TanStack Start CSRF middleware; do not recreate it per server function.
Never render untrusted HTML without sanitization. Set CSP restrictions on script sources.
Use HTTPS and log security events without secrets.

## Dependencies

Run `pnpm audit` regularly and review updates monthly.
Pin deployed dependency versions through the repository's catalog and lockfile policy.
Follow AGENTS.md for dependency commands, release-age policy, and approval rules.
