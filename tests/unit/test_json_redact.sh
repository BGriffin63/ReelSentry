#!/usr/bin/env bash
# Unit: JSON escaping + secret redaction (spec §18, §26, §27).
. "$(dirname "$0")/../lib/testlib.sh"
vms_load common json redact

assert_eq "escape quote"   "$(json_escape_string 'a"b')"       '"a\"b"'
assert_eq "escape backslash" "$(json_escape_string 'a\b')"     '"a\\b"'
assert_eq "escape newline" "$(json_escape_string $'a\nb')"     '"a\nb"'
assert_eq "escape tab"     "$(json_escape_string $'a\tb')"     '"a\tb"'
assert_eq "escape slash"   "$(json_escape_string 'a/b')"       '"a\/b"'
assert_contains "escape closes script" "$(json_escape_string '</script>')" '<\/script>'

# Control char -> \u00XX
esc=$(json_escape_string $'\x01')
assert_contains "control char unicode" "$esc" 'u0001'

assert_eq "json bool 1"  "$(json_bool 1)" "true"
assert_eq "json bool no" "$(json_bool no)" "false"
assert_eq "json num ok"  "$(json_num 42)" "42"
assert_eq "json num junk" "$(json_num 'DROP TABLE')" "0"

# Redaction never leaks the token
full="https://discord.com/api/webhooks/123456789/SuperSecretTokenABCDEF"
r=$(redact_discord_webhook "$full")
assert_not_contains "redact no secret" "$r" "SuperSecretToken"
assert_contains "redact keeps id" "$r" "123456789"
assert_contains "redact marker" "$r" "REDACTED"

# Stream redaction on log-like text
log="posting to $full with token=abcdef123456 Authorization: Bearer zzz"
rs=$(printf '%s' "$log" | redact_stream)
assert_not_contains "stream no webhook token" "$rs" "SuperSecretTokenABCDEF"
assert_not_contains "stream no bearer" "$rs" "zzz"
assert_not_contains "stream no token kv" "$rs" "abcdef123456"

vms_test_summary
