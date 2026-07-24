<?php
/* VM Sentinel — stream a sanitized diagnostics bundle (spec §13.5, §18).
   SPDX-License-Identifier: MIT
   The bundle is produced by diagnostics.sh which redacts all secrets. */
require_once __DIR__.'/vms-common.php';
$path = trim(vms_run('services/diagnostics.sh', ['bundle']));
if ($path === '' || !is_file($path)) { http_response_code(500); exit('Could not build diagnostics bundle'); }
header('Content-Type: application/gzip');
header('Content-Disposition: attachment; filename="'.basename($path).'"');
header('Content-Length: '.filesize($path));
readfile($path);
@unlink($path);
