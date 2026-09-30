<?php
// Lightweight reachability probe used by the app's ConnectivityService.
// Any HTTP response counts as "online"; keep this file dependency-free.
header('Content-Type: application/json');
header('Cache-Control: no-store');
echo json_encode(['success' => true, 'time' => date('c')]);
