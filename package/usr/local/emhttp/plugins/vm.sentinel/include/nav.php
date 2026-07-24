<?php
/* VM Sentinel — shared sub-navigation (spec §13). SPDX-License-Identifier: MIT */
function vms_nav(string $active): void {
    $tabs = [
        'overview' => ['Overview', '/Settings/VMSentinel'],
        'vms'      => ['VMs', '/Settings/VMSentinelVMs'],
        'notify'   => ['Notifications', '/Settings/VMSentinelNotify'],
        'history'  => ['Event History', '/Settings/VMSentinelHistory'],
        'diag'     => ['Diagnostics', '/Settings/VMSentinelDiag'],
    ];
    echo '<div style="margin:6px 0 14px;border-bottom:1px solid rgba(128,128,128,.3);padding-bottom:8px">';
    foreach ($tabs as $k => $t) {
        $on = $k === $active;
        printf('<a href="%s" style="margin-right:14px;%s">%s</a>',
            htmlspecialchars($t[1], ENT_QUOTES), $on ? 'font-weight:700;text-decoration:underline' : '',
            htmlspecialchars($t[0], ENT_QUOTES));
    }
    echo '</div>';
}
