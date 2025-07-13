# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| latest  | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly:

1. **DO NOT** open a public issue
2. Email the details to: [Create a security advisory](https://github.com/timlikesai/code-sandbox-mcp/security/advisories/new)
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if available)

We will acknowledge receipt within 48 hours and provide updates on the fix.

## Security Measures

### Code Execution Security

This MCP server executes arbitrary code. Security measures include:

- **Container Isolation**: All code runs in Docker containers
- **Resource Limits**: Memory (512MB) and CPU (50%) restrictions
- **Network Isolation**: No network access (`--network none`)
- **Filesystem Protection**: Read-only root filesystem
- **No Privileges**: Runs as non-root user with all capabilities dropped
- **Timeout Protection**: 30-second execution timeout

### GitHub Actions Security

Our workflows follow security best practices:

- **Minimal Permissions**: Top-level `permissions: read` with specific grants only where needed
- **No Fork Secrets**: Using `pull_request` event, not `pull_request_target`
- **Trusted Actions**: Using well-known publishers (`actions/*`, `docker/*`) with version pinning
- **No Self-Hosted Runners**: Only GitHub-hosted runners for public repository safety

### Supply Chain Security

- **Dependency Review**: Automated PR checks for vulnerable dependencies
- **CodeQL Analysis**: Weekly security scanning
- **Bundler Audit**: Regular dependency vulnerability checks
- **Dependabot**: Automated security updates (when enabled)

## Best Practices for Users

When using this code sandbox:

1. **Never execute untrusted code** without reviewing it first
2. **Use additional sandboxing** in production environments
3. **Monitor resource usage** when running the container
4. **Keep the image updated** with the latest security patches
5. **Review MCP client permissions** before granting access

## Container Security Configuration

Recommended production deployment:

```bash
docker run --rm -i \
  --read-only \
  --tmpfs /tmp \
  --tmpfs /app/tmp \
  --memory 512m \
  --cpus 0.5 \
  --network none \
  --security-opt no-new-privileges \
  --cap-drop ALL \
  ghcr.io/timlikesai/code-sandbox-mcp:latest
```

## Security Audit

This project uses:
- RuboCop for code quality and style enforcement
- Bundler Audit for dependency vulnerabilities
- SimpleCov for test coverage (99%+)

Run security checks locally:
```bash
bundle exec bundler-audit check --update
bundle exec rake
```