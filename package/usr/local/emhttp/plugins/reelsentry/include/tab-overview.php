<?php
/* ReelSentry — Overview tab (spec §13.1). SPDX-License-Identifier: MIT
   Included by ReelSentry.page; shares its scope ($cfg is already set). */
$status = json_decode(vms_run('services/diagnostics.sh', ['status']), true) ?: [];
$inv = vms_inventory();
$running = 0; $healthy = 0; $unhealthy = 0; $nohc = 0;
foreach ($inv as $uuid => $name) {
    $st = trim((string)shell_exec('virsh domstate '.escapeshellarg($uuid).' 2>/dev/null'));
    if ($st === 'running') $running++;
    $hs = trim((string)@file_get_contents(VMS_RUN_DIR.'/health/'.$uuid.'.state'));
    if ($hs === '') $nohc++;
    elseif ($hs === 'Unhealthy') $unhealthy++;
    elseif ($hs === 'Healthy' || $hs === 'Recovered') $healthy++;
    else $nohc++;
}
?>
<?php if (!(int)$cfg['monitoring_enabled']): ?>
  <blockquote class="vms-badge vms-warn" style="display:block;padding:10px 14px;">
    Monitoring is <b>off</b>. Turn it on in the <b>Notifications</b> tab after choosing what to watch.
  </blockquote>
<?php endif; ?>

<div class="vms-cards">
  <div class="vms-card"><div class="n"><?=count($inv)?></div><div class="l">VMs discovered</div></div>
  <div class="vms-card"><div class="n"><?=$running?></div><div class="l">Running</div></div>
  <div class="vms-card"><div class="n"><?=$healthy?></div><div class="l">Healthy</div></div>
  <div class="vms-card"><div class="n"><?=$unhealthy?></div><div class="l">Unhealthy</div></div>
  <div class="vms-card"><div class="n"><?=$nohc?></div><div class="l">No health check</div></div>
</div>

<table class="vms-tbl">
  <thead><tr><th>VM</th><th>Libvirt state</th><th>Health</th><th>Monitoring</th><th>UUID</th></tr></thead>
  <tbody>
  <?php if (!$inv): ?>
    <tr><td colspan="5" class="vms-muted">No VMs found. Is VM Manager enabled and the array started?</td></tr>
  <?php else: foreach ($inv as $uuid => $name):
      $st = trim((string)shell_exec('virsh domstate '.escapeshellarg($uuid).' 2>/dev/null')) ?: 'unknown';
      $hs = trim((string)@file_get_contents(VMS_RUN_DIR.'/health/'.$uuid.'.state')) ?: '—';
      $mon = ((int)$cfg['monitoring_enabled'] && (int)($cfg['vms'][$uuid]['enabled'] ?? 1)) ? 'on' : 'off';
  ?>
    <tr>
      <td><?=h($name)?></td>
      <td><?=h($st)?></td>
      <td><?=h($hs)?></td>
      <td><span class="vms-badge <?=$mon==='on'?'vms-ok':'vms-muted'?>"><?=$mon?></span></td>
      <td class="vms-uuid"><?=h(substr($uuid,0,8))?>…</td>
    </tr>
  <?php endforeach; endif; ?>
  </tbody>
</table>

<h3>Status</h3>
<table class="vms-tbl">
  <tr><td>Plugin version</td><td><?=h($status['plugin_version'] ?? 'unknown')?></td></tr>
  <tr><td>Processor</td><td><?=h($status['processor'] ?? '?')?></td></tr>
  <tr><td>Health service</td><td><?=h($status['healthcheck'] ?? '?')?></td></tr>
  <tr><td>Hook</td><td><?=h($status['hook_status'] ?? '?')?></td></tr>
  <tr><td>Queue depth</td><td><?=h((string)($status['queue_depth'] ?? 0))?></td></tr>
  <tr><td>Dropped events</td><td><?=h((string)($status['dropped_events'] ?? 0))?></td></tr>
</table>
