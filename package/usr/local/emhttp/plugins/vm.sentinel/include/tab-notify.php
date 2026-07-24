<?php
/* VM Sentinel — Notifications tab (spec §10,§11,§13.3,§16). SPDX-License-Identifier: MIT
   Included by VMSentinel.page; shares its scope ($cfg is already set).
   Secrets are NEVER echoed: only a redacted webhook representation is shown. */
$webhookRedacted = vms_redact_webhook(vms_read_secret_webhook());
$cc = function($k,$d=0) use ($cfg){ return (int)($cfg[$k] ?? $d) ? 'checked':''; };
?>
<form onsubmit="event.preventDefault();VMS.saveForm(this,this.querySelector('.vms-flash'));">
  <input type="hidden" name="action" value="save_global">
  <h3>Monitoring</h3>
  <label><input type="checkbox" name="monitoring_enabled" value="1" <?=$cc('monitoring_enabled')?>> Enable monitoring</label>
  <p class="vms-help">Master switch. When off, no notifications are sent regardless of per-VM settings.</p>

  <h3>Native Unraid notifications</h3>
  <label><input type="checkbox" name="native_enabled" value="1" <?=$cc('native_enabled',1)?>> Send through Unraid’s built-in notifications</label>
  <p class="vms-help">Uses whatever agents you configured under Settings → Notifications (email, agents, browser).</p>
  <button type="button" onclick="VMS.testNotify('native',document.getElementById('nflash'))">Send test notification</button>
  <span id="nflash" class="vms-flash"></span>

  <h3>Discord webhook</h3>
  <label><input type="checkbox" name="discord_enabled" value="1" <?=$cc('discord_enabled')?>> Enable Discord webhook alerts</label>
  <label>Display name override: <input type="text" name="discord_username" value="<?=h($cfg['discord_username']??'VM Sentinel')?>"></label>
  <label>Avatar URL (https): <input type="text" name="discord_avatar" value="<?=h($cfg['discord_avatar']??'')?>"></label>
  <label>Mention role ID: <input type="text" name="discord_mention_role" value="<?=h($cfg['discord_mention_role']??'')?>"></label>
  <label>Mention user ID: <input type="text" name="discord_mention_user" value="<?=h($cfg['discord_mention_user']??'')?>"></label>

  <h3>Quiet hours</h3>
  <label><input type="checkbox" name="quiet_enabled" value="1" <?=$cc('quiet_enabled')?>> Enable quiet hours</label>
  <label>Start <input type="time" name="quiet_start" value="<?=h($cfg['quiet_start']??'22:00')?>"></label>
  <label>End <input type="time" name="quiet_end" value="<?=h($cfg['quiet_end']??'07:00')?>"></label>
  <label>Days (0=Sun) <input type="text" name="quiet_days" value="<?=h($cfg['quiet_days']??'0,1,2,3,4,5,6')?>"></label>
  <label><input type="checkbox" name="quiet_bypass_critical" value="1" <?=$cc('quiet_bypass_critical',1)?>> Critical alerts still bypass quiet hours</label>

  <h3>Retention</h3>
  <label>Max events <input type="number" name="history_max_events" min="100" value="<?=h((string)($cfg['history_max_events']??5000))?>"></label>
  <label>Retention days <input type="number" name="history_retention_days" min="1" value="<?=h((string)($cfg['history_retention_days']??30))?>"></label>
  <label>Global cooldown (s) <input type="number" name="cooldown_seconds" min="0" value="<?=h((string)($cfg['cooldown_seconds']??0))?>"></label>

  <p><button type="submit">Save settings</button> <span class="vms-flash"></span></p>
</form>

<hr>
<h3>Discord webhook URL</h3>
<p class="vms-help">Stored in a private file with restricted permissions. Only a redacted form is shown.
   Treat the URL like a password.</p>
<p>Current: <code><?=h($webhookRedacted)?></code></p>
<form onsubmit="event.preventDefault();VMS.post({action:'save_webhook',discord_webhook:this.discord_webhook.value}).then(r=>{VMS.flash(document.getElementById('wflash'),r.ok,r.error||('Saved: '+(r.display||'')));if(r.ok)this.reset();});">
  <input type="password" name="discord_webhook" placeholder="https://discord.com/api/webhooks/…" style="width:420px" autocomplete="off">
  <button type="submit">Save webhook</button>
  <button type="button" onclick="VMS.testNotify('discord',document.getElementById('wflash'))">Send test</button>
  <span id="wflash" class="vms-flash"></span>
</form>
