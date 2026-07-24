<?php
/**
 * VM Sentinel — settings POST handler (spec §13, §18).
 * SPDX-License-Identifier: MIT
 *
 * All state-changing actions funnel through here. Every request is CSRF-checked.
 * Secrets are written to the 0600 secrets file and never echoed back.
 * Responds with JSON; the WebGUI JS updates in place.
 */
require_once __DIR__.'/vms-common.php';
header('Content-Type: application/json');
vms_csrf_check();

$action = $_POST['action'] ?? '';
$reply  = ['ok' => false];

switch ($action) {

case 'save_global':
    $cfg = vms_read_config();
    // Whitelist of scalar global keys we accept from the form.
    $bools = ['monitoring_enabled','native_enabled','discord_enabled','quiet_enabled',
              'quiet_bypass_critical','debug','notify_start','notify_stop','notify_shutdown',
              'notify_crash','notify_pause','notify_resume','notify_reboot',
              'notify_health_fail','notify_health_recover'];
    foreach ($bools as $b) $cfg[$b] = isset($_POST[$b]) && $_POST[$b] === '1' ? 1 : 0;
    $ints = ['history_max_events','history_retention_days','cooldown_seconds'];
    foreach ($ints as $i) if (isset($_POST[$i]) && ctype_digit((string)$_POST[$i])) $cfg[$i] = (int)$_POST[$i];
    foreach (['quiet_start','quiet_end'] as $t)
        if (isset($_POST[$t]) && preg_match('/^\d{2}:\d{2}$/', $_POST[$t])) $cfg[$t] = $_POST[$t];
    if (isset($_POST['quiet_days']) && preg_match('/^[0-6](,[0-6])*$/', $_POST['quiet_days']))
        $cfg['quiet_days'] = $_POST['quiet_days'];
    $cfg['discord_username'] = substr(preg_replace('/[^\P{C}]+/u','', (string)($_POST['discord_username'] ?? 'VM Sentinel')), 0, 80);
    $av = trim((string)($_POST['discord_avatar'] ?? ''));
    $cfg['discord_avatar'] = preg_match('#^https://#', $av) ? $av : '';
    $cfg['discord_mention_role'] = preg_match('/^\d{1,25}$/', (string)($_POST['discord_mention_role'] ?? '')) ? $_POST['discord_mention_role'] : '';
    $cfg['discord_mention_user'] = preg_match('/^\d{1,25}$/', (string)($_POST['discord_mention_user'] ?? '')) ? $_POST['discord_mention_user'] : '';
    $reply['ok'] = vms_write_config($cfg);
    break;

case 'save_webhook':
    $url = trim((string)($_POST['discord_webhook'] ?? ''));
    if ($url === '') { // clearing
        $reply['ok'] = vms_write_secret_webhook('');
        $reply['display'] = '(not set)';
    } elseif (vms_valid_webhook($url)) {
        $reply['ok'] = vms_write_secret_webhook($url);
        $reply['display'] = vms_redact_webhook($url);
    } else {
        $reply['error'] = 'That does not look like a Discord webhook URL (must be https://discord.com/api/webhooks/...).';
    }
    break;

case 'save_vm':
    $uuid = (string)($_POST['uuid'] ?? '');
    if (!preg_match('/^[0-9a-fA-F-]{36}$/', $uuid)) { $reply['error'] = 'Invalid VM id'; break; }
    $cfg = vms_read_config();
    if (!isset($cfg['vms']) || !is_array($cfg['vms'])) $cfg['vms'] = [];
    $ov = is_array($cfg['vms'][$uuid] ?? null) ? $cfg['vms'][$uuid] : [];
    foreach (['enabled','notify_start','notify_stop','notify_shutdown','notify_crash',
              'notify_pause','notify_resume','notify_reboot','notify_health_fail',
              'notify_health_recover'] as $b)
        $ov[$b] = isset($_POST[$b]) && $_POST[$b] === '1' ? 1 : 0;
    foreach (['health_interval','health_timeout','health_fail_threshold',
              'health_recover_threshold','startup_grace','cooldown_seconds','health_port'] as $i)
        if (isset($_POST[$i]) && ctype_digit((string)$_POST[$i])) $ov[$i] = (int)$_POST[$i];
    $ht = (string)($_POST['health_type'] ?? 'none');
    $ov['health_type'] = in_array($ht, ['none','icmp','tcp','agent'], true) ? $ht : 'none';
    $tg = trim((string)($_POST['health_target'] ?? ''));
    // Validate hostname/IP with a conservative pattern before storing.
    $ov['health_target'] = preg_match('/^[A-Za-z0-9._-]{1,253}$/', $tg) ? $tg : '';
    if (isset($_POST['name'])) $ov['name'] = vms_snap_clean(substr((string)$_POST['name'],0,128));
    $cfg['vms'][$uuid] = $ov;
    $reply['ok'] = vms_write_config($cfg);
    break;

case 'forget_vm':
    $uuid = (string)($_POST['uuid'] ?? '');
    if (preg_match('/^[0-9a-fA-F-]{36}$/', $uuid)) {
        $cfg = vms_read_config();
        unset($cfg['vms'][$uuid]);
        $reply['ok'] = vms_write_config($cfg);
    }
    break;

case 'test_notify':
    $target = in_array($_POST['target'] ?? '', ['native','discord','all'], true) ? $_POST['target'] : 'all';
    $reply['ok'] = true;
    $reply['result'] = json_decode(vms_run('services/test-notify.sh', [$target]), true);
    break;

case 'suppress':
    $mins = ctype_digit((string)($_POST['minutes'] ?? '')) ? (int)$_POST['minutes'] : 0;
    $scope = ($_POST['scope'] ?? 'all') === 'all' ? 'all' : (string)$_POST['uuid'];
    if ($mins > 0 && ($scope === 'all' || preg_match('/^[0-9a-fA-F-]{36}$/', $scope))) {
        $reply['ok'] = (bool)vms_run('services/suppress.sh', [$scope, (string)$mins]);
    }
    break;

case 'clear_history':
    $reply['ok'] = (bool)vms_run('services/history-tool.sh', ['clear']);
    break;

default:
    $reply['error'] = 'Unknown action';
}

echo json_encode($reply);
