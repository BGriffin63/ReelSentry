<?php
/* ReelSentry — sanitized history export (spec §13.4, §18). SPDX-License-Identifier: MIT
   Output is redacted by history-tool.sh; exports never contain secrets. */
require_once __DIR__.'/vms-common.php';
$fmt = ($_GET['fmt'] ?? 'json') === 'csv' ? 'csv' : 'json';
if ($fmt === 'csv') {
    header('Content-Type: text/csv');
    header('Content-Disposition: attachment; filename="reelsentry-history.csv"');
    echo vms_run('services/history-tool.sh', ['export-csv']);
} else {
    header('Content-Type: application/json');
    header('Content-Disposition: attachment; filename="reelsentry-history.json"');
    $lines = array_filter(explode("\n", vms_run('services/history-tool.sh', ['tail','100000'])));
    $arr = [];
    foreach ($lines as $l) { $o = json_decode($l, true); if (is_array($o)) $arr[] = $o; }
    echo json_encode($arr, JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES);
}
