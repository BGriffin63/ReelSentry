<?php
/**
 * VM Sentinel — shared WebGUI helpers (spec §13, §18).
 * SPDX-License-Identifier: MIT
 *
 * Responsibilities:
 *   - Read/write the canonical config.json AND regenerate the bash-facing
 *     config.snapshot atomically so the two never diverge (see config.sh).
 *   - Store the Discord webhook in a separate 0600 secrets.json; NEVER echo it.
 *   - CSRF validation using Unraid's token convention.
 *   - HTML/JSON-safe output and safe invocation of bash helpers (escapeshellarg).
 *
 * This file performs NO output when included.
 */

const VMS_ID          = 'vm.sentinel';
const VMS_CONFIG_DIR   = '/boot/config/plugins/vm.sentinel';
const VMS_CONFIG_FILE  = '/boot/config/plugins/vm.sentinel/config.json';
const VMS_SNAPSHOT     = '/boot/config/plugins/vm.sentinel/config.snapshot';
const VMS_SECRETS_FILE = '/boot/config/plugins/vm.sentinel/secrets.json';
const VMS_PLUGIN_ROOT  = '/usr/local/emhttp/plugins/vm.sentinel';
const VMS_RUN_DIR      = '/var/run/vm.sentinel';

/** Built-in defaults; the source of truth for a fresh install (spec §31). */
function vms_default_config(): array {
    return [
        'schema'                    => 1,
        'monitoring_enabled'        => 0,      // conservative until user sets up (spec §18.29)
        'native_enabled'            => 1,
        'discord_enabled'           => 0,
        'discord_username'          => 'VM Sentinel',
        'discord_avatar'            => '',
        'discord_mention_role'      => '',
        'discord_mention_user'      => '',
        'history_max_events'        => 5000,
        'history_retention_days'    => 30,
        'cooldown_seconds'          => 0,
        'quiet_enabled'             => 0,
        'quiet_start'               => '22:00',
        'quiet_end'                 => '07:00',
        'quiet_days'                => '0,1,2,3,4,5,6',
        'quiet_bypass_critical'     => 1,
        'quiet_allow_events'        => '',
        // global per-event defaults (per-VM can override)
        'notify_start'              => 0,
        'notify_stop'               => 1,
        'notify_shutdown'           => 1,
        'notify_crash'              => 1,
        'notify_pause'              => 0,
        'notify_resume'             => 0,
        'notify_reboot'             => 0,
        'notify_health_fail'        => 1,
        'notify_health_recover'     => 1,
        'debug'                     => 0,
        'vms'                       => new stdClass(), // uuid => per-vm overrides
    ];
}

function vms_read_config(): array {
    if (is_readable(VMS_CONFIG_FILE)) {
        $raw = file_get_contents(VMS_CONFIG_FILE);
        $cfg = json_decode($raw, true);
        if (is_array($cfg)) return array_merge((array)vms_default_config(), $cfg);
        // Corrupt: try the backup (spec §19).
        if (is_readable(VMS_CONFIG_FILE.'.bak')) {
            $cfg = json_decode((string)file_get_contents(VMS_CONFIG_FILE.'.bak'), true);
            if (is_array($cfg)) return array_merge((array)vms_default_config(), $cfg);
        }
    }
    return json_decode(json_encode(vms_default_config()), true);
}

/** Atomic write of config.json + regenerated snapshot. Returns true on success. */
function vms_write_config(array $cfg): bool {
    if (!is_dir(VMS_CONFIG_DIR)) @mkdir(VMS_CONFIG_DIR, 0755, true);
    $cfg['schema'] = 1;
    $json = json_encode($cfg, JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES);
    if ($json === false) return false;
    if (!vms_atomic_put(VMS_CONFIG_FILE, $json, 0644)) return false;
    return vms_write_snapshot($cfg);
}

/** Regenerate the flat, tab-delimited snapshot consumed by the bash services. */
function vms_write_snapshot(array $cfg): bool {
    $lines = [];
    $globalKeys = array_diff(array_keys($cfg), ['vms']);
    foreach ($globalKeys as $k) {
        $v = $cfg[$k];
        if (is_bool($v)) $v = $v ? 1 : 0;
        if (is_array($v) || is_object($v)) continue;
        $lines[] = "G\t".vms_snap_clean($k)."\t".vms_snap_clean((string)$v);
    }
    $vms = $cfg['vms'] ?? [];
    foreach ((array)$vms as $uuid => $ov) {
        $uuid = vms_snap_clean((string)$uuid);
        if (!preg_match('/^[0-9a-fA-F-]{36}$/', $uuid)) continue;
        foreach ((array)$ov as $k => $v) {
            if ($k === 'name') { $lines[] = "N\t$uuid\t".vms_snap_clean((string)$v); continue; }
            if (is_bool($v)) $v = $v ? 1 : 0;
            if (is_array($v) || is_object($v)) continue;
            $lines[] = "V\t$uuid\t".vms_snap_clean($k)."\t".vms_snap_clean((string)$v);
        }
    }
    return vms_atomic_put(VMS_SNAPSHOT, implode("\n", $lines)."\n", 0644);
}

/** Strip tabs/newlines so a value stays a single snapshot field. */
function vms_snap_clean(string $s): string {
    return str_replace(["\t", "\r", "\n"], [' ', ' ', ' '], $s);
}

function vms_atomic_put(string $target, string $content, int $mode): bool {
    $dir = dirname($target);
    $tmp = @tempnam($dir, '.vms');
    if ($tmp === false) return false;
    if (@file_put_contents($tmp, $content) === false) { @unlink($tmp); return false; }
    @chmod($tmp, $mode);
    if (is_file($target)) @copy($target, $target.'.bak');
    if (!@rename($tmp, $target)) { @unlink($tmp); return false; }
    return true;
}

/** Secrets: separate 0600 file. Never returned to HTML in full. */
function vms_read_secret_webhook(): string {
    if (!is_readable(VMS_SECRETS_FILE)) return '';
    $s = json_decode((string)file_get_contents(VMS_SECRETS_FILE), true);
    return is_array($s) && isset($s['discord_webhook']) ? (string)$s['discord_webhook'] : '';
}

function vms_write_secret_webhook(string $url): bool {
    $payload = json_encode(['discord_webhook' => $url], JSON_UNESCAPED_SLASHES);
    if (!is_dir(VMS_CONFIG_DIR)) @mkdir(VMS_CONFIG_DIR, 0755, true);
    $ok = vms_atomic_put(VMS_SECRETS_FILE, (string)$payload, 0600);
    @chmod(VMS_SECRETS_FILE, 0600);
    return $ok;
}

/** Redact a webhook for display: never reveal enough to reconstruct (spec §26). */
function vms_redact_webhook(string $url): string {
    if ($url === '') return '(not set)';
    if (preg_match('#^(https://[^/]+/api/webhooks/\d+)/([A-Za-z0-9_-]+)#', $url, $m)) {
        return $m[1].'/'.substr($m[2], 0, 3).'…/REDACTED';
    }
    return '(stored)';
}

/** Validate a Discord webhook URL in PHP (mirrors validate.sh). */
function vms_valid_webhook(string $u): bool {
    if ($u === '') return false;
    if (!preg_match('#^https://#', $u)) return false;
    $host = parse_url($u, PHP_URL_HOST);
    if (!in_array($host, ['discord.com','discordapp.com','ptb.discord.com','canary.discord.com'], true)) return false;
    return (bool)preg_match('#^/api/webhooks/\d+/[A-Za-z0-9_-]+$#', (string)parse_url($u, PHP_URL_PATH));
}

/** CSRF check using Unraid's token (spec §18.16). Dies on mismatch. */
function vms_csrf_check(): void {
    $token = $_POST['csrf_token'] ?? ($_GET['csrf_token'] ?? '');
    $expected = '';
    if (is_readable('/var/local/emhttp/var.ini')) {
        $var = @parse_ini_file('/var/local/emhttp/var.ini');
        $expected = $var['csrf_token'] ?? '';
    }
    if ($expected === '' || !hash_equals((string)$expected, (string)$token)) {
        http_response_code(403);
        exit('Invalid CSRF token');
    }
}

/** Safe HTML escaping helper. */
function h($s): string { return htmlspecialchars((string)$s, ENT_QUOTES, 'UTF-8'); }

/** Run a plugin bash helper safely; args are individually escaped. */
function vms_run(string $script, array $args = []): string {
    $cmd = 'bash '.escapeshellarg(VMS_PLUGIN_ROOT.'/'.$script);
    foreach ($args as $a) $cmd .= ' '.escapeshellarg((string)$a);
    return (string)shell_exec($cmd.' 2>/dev/null');
}

/** Inventory of defined VMs from the tmpfs uuidmap (uuid<TAB>name). */
function vms_inventory(): array {
    $out = [];
    $map = VMS_RUN_DIR.'/uuidmap';
    if (is_readable($map)) {
        foreach (file($map, FILE_IGNORE_NEW_LINES) as $line) {
            $p = explode("\t", $line, 2);
            if (count($p) === 2 && preg_match('/^[0-9a-fA-F-]{36}$/', $p[0])) {
                $out[$p[0]] = $p[1];
            }
        }
    }
    return $out;
}
