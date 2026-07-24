#!/usr/bin/env bash
# Unit: input validation (spec §18, §27).
. "$(dirname "$0")/../lib/testlib.sh"
vms_load common validate

assert_true  "valid uuid"       "valid_uuid 12345678-1234-1234-1234-123456789abc"
assert_true  "valid uuid upper" "valid_uuid ABCDEF00-1234-1234-1234-123456789ABC"
assert_false "bad uuid short"   "valid_uuid 1234"
assert_false "bad uuid chars"   "valid_uuid 12345678-1234-1234-1234-zzzzzzzzzzzz"

assert_true  "port 1"      "valid_port 1"
assert_true  "port 65535"  "valid_port 65535"
assert_false "port 0"      "valid_port 0"
assert_false "port 70000"  "valid_port 70000"
assert_false "port word"   "valid_port abc"

assert_true  "ipv4 ok"     "valid_ipv4 192.168.1.50"
assert_false "ipv4 256"    "valid_ipv4 999.1.1.1"
assert_true  "host ok"     "valid_hostname home-assistant.local"
assert_true  "host ip"     "valid_hostname 10.0.0.1"
assert_false "host space"  "valid_hostname 'bad host'"
assert_false "host semicolon" "valid_hostname 'evil;rm'"
assert_false "host backtick" 'valid_hostname "a\`b"'

assert_true  "webhook ok" "valid_discord_webhook https://discord.com/api/webhooks/123/AbC-d_e"
assert_true  "webhook ptb" "valid_discord_webhook https://ptb.discord.com/api/webhooks/1/x"
assert_false "webhook http" "valid_discord_webhook http://discord.com/api/webhooks/1/x"
assert_false "webhook host" "valid_discord_webhook https://evil.com/api/webhooks/1/x"
assert_false "webhook path" "valid_discord_webhook https://discord.com/not/a/webhook"
assert_false "webhook inject" 'valid_discord_webhook "https://discord.com/api/webhooks/1/x;rm -rf /"'
assert_false "webhook subst" 'valid_discord_webhook "https://discord.com/api/webhooks/1/\$(id)"'

assert_true  "path comp ok"    "valid_path_component config.json"
assert_false "path traversal"  "valid_path_component ../etc"
assert_false "path slash"      "valid_path_component a/b"

# sanitize_vm_name strips control chars and bounds length
name=$(sanitize_vm_name $'Game\nPC\t<x>')
assert_not_contains "sanitize removes newline" "$name" $'\n'
assert_not_contains "sanitize removes tab" "$name" $'\t'
long=$(printf 'A%.0s' {1..500}); s=$(sanitize_vm_name "$long")
assert_true "sanitize bounds length" "[ ${#s} -le 128 ]"

vms_test_summary
