<?php
/* VM Sentinel — VMs tab (spec §8, §13.2). SPDX-License-Identifier: MIT
   Included by VMSentinel.page; shares its scope ($cfg is already set). */
$inv_v = vms_inventory();
$all_v = $inv_v;
foreach (($cfg['vms'] ?? []) as $u => $ov) if (!isset($all_v[$u])) $all_v[$u] = ($ov['name'] ?? $u).' (unavailable)';
if (!function_exists('vms_ck')) {
    function vms_ck($cfg,$uuid,$k,$def){ return (int)($cfg['vms'][$uuid][$k] ?? $cfg[$k] ?? $def); }
    function vms_vv($cfg,$uuid,$k,$def){ return h((string)($cfg['vms'][$uuid][$k] ?? $def)); }
}
?>
<p class="vms-help">Settings are stored per VM by UUID, so they survive a rename. Deleting a VM in
Unraid does not erase its history here — use “Forget” to remove retained settings.</p>

<?php if (!$all_v): ?><p class="vms-muted">No VMs discovered yet.</p><?php endif; ?>

<?php foreach ($all_v as $uuid => $name):
    $isRetained = !isset($inv_v[$uuid]); $htype = (string)($cfg['vms'][$uuid]['health_type'] ?? 'none'); ?>
<details class="vms-vm">
  <summary><?=h($name)?> <span class="vms-uuid"><?=h($uuid)?></span></summary>
  <div class="body">
    <form onsubmit="event.preventDefault();VMS.saveForm(this,this.querySelector('.vms-flash'));">
      <input type="hidden" name="action" value="save_vm">
      <input type="hidden" name="uuid" value="<?=h($uuid)?>">
      <input type="hidden" name="name" value="<?=h(is_string($name)?$name:'')?>">
      <label><input type="checkbox" name="enabled" value="1" <?=vms_ck($cfg,$uuid,'enabled',1)?'checked':''?>> Monitor this VM</label>
      <fieldset><legend>Notify on</legend>
        <?php foreach (['notify_start'=>'Start','notify_stop'=>'Stop','notify_shutdown'=>'Shutdown',
                        'notify_crash'=>'Crash / failure','notify_pause'=>'Pause','notify_resume'=>'Resume',
                        'notify_reboot'=>'Reboot','notify_health_fail'=>'Health check fails',
                        'notify_health_recover'=>'Health check recovers'] as $k=>$lbl):
            $def = in_array($k,['notify_stop','notify_shutdown','notify_crash','notify_health_fail','notify_health_recover'])?1:0; ?>
          <label style="display:inline-block;min-width:190px"><input type="checkbox" name="<?=$k?>" value="1" <?=vms_ck($cfg,$uuid,$k,$def)?'checked':''?>> <?=$lbl?></label>
        <?php endforeach; ?>
      </fieldset>
      <fieldset><legend>Health check</legend>
        <label>Type:
          <select name="health_type">
            <?php foreach (['none'=>'Disabled','icmp'=>'Ping (ICMP)','tcp'=>'TCP port','agent'=>'QEMU guest agent'] as $k=>$lbl): ?>
              <option value="<?=$k?>" <?=$htype===$k?'selected':''?>><?=$lbl?></option>
            <?php endforeach; ?>
          </select>
        </label>
        <label>Target host/IP: <input type="text" name="health_target" value="<?=vms_vv($cfg,$uuid,'health_target','')?>" placeholder="192.168.1.50"></label>
        <label>TCP port: <input type="number" name="health_port" min="1" max="65535" value="<?=vms_vv($cfg,$uuid,'health_port','')?>"></label>
        <br>
        <label>Interval (s): <input type="number" name="health_interval" min="30" value="<?=vms_vv($cfg,$uuid,'health_interval','60')?>"></label>
        <label>Timeout (s): <input type="number" name="health_timeout" min="1" value="<?=vms_vv($cfg,$uuid,'health_timeout','5')?>"></label>
        <label>Fail threshold: <input type="number" name="health_fail_threshold" min="1" value="<?=vms_vv($cfg,$uuid,'health_fail_threshold','3')?>"></label>
        <label>Recover threshold: <input type="number" name="health_recover_threshold" min="1" value="<?=vms_vv($cfg,$uuid,'health_recover_threshold','2')?>"></label>
        <label>Startup grace (s): <input type="number" name="startup_grace" min="0" value="<?=vms_vv($cfg,$uuid,'startup_grace','120')?>"></label>
      </fieldset>
      <button type="submit">Save</button>
      <?php if ($isRetained): ?>
        <button type="button" onclick="if(confirm('Forget retained settings for this VM?'))VMS.post({action:'forget_vm',uuid:'<?=h($uuid)?>'}).then(()=>location.reload());">Forget</button>
      <?php endif; ?>
      <span class="vms-flash"></span>
    </form>
  </div>
</details>
<?php endforeach; ?>
