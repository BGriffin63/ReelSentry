# Security Policy

## Supported versions
The latest released version receives security fixes. Alpha/beta builds are
supported on a best-effort basis.

## Reporting a vulnerability
**Please do not open a public issue for security vulnerabilities.**

Use GitHub's **private vulnerability reporting** for this repository
(Security → Report a vulnerability), or contact the maintainer privately at:

- Security contact: `YOUR_SECURITY_CONTACT` (replace before release — see
  `docs/MAINTAINER-CHECKLIST.md`).

Please include:
- A description of the issue and its impact.
- Steps to reproduce or a proof of concept.
- Affected version(s) and environment.

## Our commitment
- We aim to acknowledge reports within a few days.
- We will investigate, keep you updated, and credit you (if desired) once a fix
  is released.
- Please give us reasonable time to release a fix before public disclosure.

## Scope
In scope: command injection, XSS, CSRF, path traversal, secret exposure, privilege
issues, anything that could let a VM name or hook argument execute code or break
the fail-open guarantee. See [`../docs/SECURITY.md`](../docs/SECURITY.md) for the
full threat model.
