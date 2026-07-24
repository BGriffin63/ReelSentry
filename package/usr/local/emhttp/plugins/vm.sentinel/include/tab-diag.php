<?php
/* VM Sentinel — Diagnostics tab (spec §13.5). SPDX-License-Identifier: MIT
   Included by VMSentinel.page; shares its scope. */
$s = json_decode(vms_run('services/diagnostics.sh', ['status']), true) ?: [];
if (!function_exists('vms_ynbadge')) {
    function vms_ynbadge($b){ return $b ? '<span class="vms-badge vms-ok">yes</span>' : '<span class="vms-badge vms-warn">no</span>'; }
}
?>
<table class="vms-tbl">
  <tr><td>Plugin version</td><td><?=h($s['plugin_version']??'?')?></td></tr>
  <tr><td>Minimum Unraid</td><td><?=h($s['min_unraid']??'7.2.0')?></td></tr>
  <tr><td>Current Unraid</td><td><?=h($s['unraid_version']??'?')?></td></tr>
  <tr><td>Hook status</td><td><?=h($s['hook_status']??'?')?></td></tr>
  <tr><td>Processor</td><td><?=h($s['processor']??'?')?></td></tr>
  <tr><td>Health service</td><td><?=h($s['healthcheck']??'?')?></td></tr>
  <tr><td>libvirt available</td><td><?=vms_ynbadge(!empty($s['libvirt_available']))?></td></tr>
  <tr><td>Secrets file permissions</td><td><?=h($s['secrets_perms']??'n/a')?></td></tr>
  <tr><td>Queue depth</td><td><?=h((string)($s['queue_depth']??0))?></td></tr>
  <tr><td>Dropped / duplicate events</td><td><?=h((string)($s['dropped_events']??0))?></td></tr>
  <tr><td>History events</td><td><?=h((string)($s['history_events']??0))?></td></tr>
</table>
<p>
  <button type="button" onclick="VMS.testNotify('all',document.getElementById('vmsDf'))">Test all notifications</button>
  <a class="button" href="/plugins/vm.sentinel/include/download-diagnostics.php">Download diagnostics (sanitized)</a>
  <span id="vmsDf" class="vms-flash"></span>
</p>
<p class="vms-help">The diagnostics bundle redacts the Discord webhook and any other secrets before download.</p>
