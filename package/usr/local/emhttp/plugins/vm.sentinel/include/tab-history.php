<?php
/* VM Sentinel — Event History tab (spec §13.4). SPDX-License-Identifier: MIT
   Included by VMSentinel.page; shares its scope. History is secret-free. */
$rows = [];
foreach (array_filter(explode("\n", vms_run('services/history-tool.sh', ['tail','500']))) as $line) {
    $o = json_decode($line, true); if (is_array($o)) $rows[] = $o;
}
$rows = array_reverse($rows);
if (!function_exists('vms_sev_badge')) {
    function vms_sev_badge($s){ return $s==='critical'?'vms-crit':($s==='warning'?'vms-warn':'vms-ok'); }
}
?>
<p>
  <input id="vmsFlt" type="text" placeholder="Filter (VM, event, classification…)" oninput="vmsHistFilter()" style="width:280px">
  <a href="/plugins/vm.sentinel/include/export.php?fmt=csv" class="button">Export CSV</a>
  <a href="/plugins/vm.sentinel/include/export.php?fmt=json" class="button">Export JSON</a>
  <button type="button" onclick="if(confirm('Clear all event history?'))VMS.post({action:'clear_history'}).then(()=>location.reload())">Clear history</button>
</p>
<table class="vms-tbl" id="vmsHistTbl">
  <thead><tr><th>Time</th><th>VM</th><th>Event</th><th>Classification</th><th>State</th><th>Severity</th><th>Notified</th></tr></thead>
  <tbody>
  <?php if (!$rows): ?>
    <tr><td colspan="7" class="vms-muted">No events recorded yet.</td></tr>
  <?php else: foreach ($rows as $r): ?>
    <tr>
      <td><?=h($r['timestamp']??'')?></td>
      <td><?=h($r['vm_name']??'')?></td>
      <td><?=h($r['event_type']??'')?></td>
      <td><?=h($r['classification']??'')?></td>
      <td><?=h(($r['previous_state']??'?').' → '.($r['current_state']??'?'))?></td>
      <td><span class="vms-badge <?=vms_sev_badge($r['severity']??'')?>"><?=h($r['severity']??'')?></span></td>
      <td><?=!empty($r['notify_attempted'])?'yes':'—'?></td>
    </tr>
  <?php endforeach; endif; ?>
  </tbody>
</table>
<script>
function vmsHistFilter(){var q=document.getElementById('vmsFlt').value.toLowerCase();
  document.querySelectorAll('#vmsHistTbl tbody tr').forEach(function(tr){
    tr.style.display = tr.textContent.toLowerCase().indexOf(q)>=0?'':'none';});}
</script>
