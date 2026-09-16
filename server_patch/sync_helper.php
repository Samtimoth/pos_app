<?php
/**
 * sync_helper.php — idempotency layer for offline-sync requests.
 *
 * The Flutter app sends `client_op_id` (a UUID) with every write request.
 * When the network drops mid-request the app retries with the SAME id.
 * This helper guarantees the write is applied once: the first successful
 * response is stored in `sync_ops`; any replay returns that stored response
 * without touching the rest of the endpoint.
 *
 * Usage — add these two lines near the top of each write endpoint, right
 * after the DB connection ($conn / $pdo / $db …) exists:
 *
 *     require_once __DIR__ . '/sync_helper.php';
 *     sync_begin($conn);   // pass your mysqli or PDO handle
 *
 * Nothing else changes: the endpoint keeps echoing its JSON as before.
 * Only responses whose JSON has "success": true are remembered, so a
 * transient failure (DB down, validation error) can still be retried.
 *
 * Works with mysqli and PDO. Requires the `sync_ops` table (migration.sql).
 */

if (!function_exists('sync_begin')) {

    /** Read client_op_id from JSON body, form POST, or query string. */
    function sync_client_op_id(): ?string
    {
        static $id = false;
        if ($id !== false) return $id;
        $id = null;
        $raw = file_get_contents('php://input');
        if ($raw) {
            $j = json_decode($raw, true);
            if (is_array($j) && !empty($j['client_op_id'])) $id = (string)$j['client_op_id'];
        }
        if ($id === null && !empty($_POST['client_op_id'])) $id = (string)$_POST['client_op_id'];
        if ($id === null && !empty($_GET['client_op_id']))  $id = (string)$_GET['client_op_id'];
        if ($id !== null && !preg_match('/^[A-Za-z0-9\-_]{8,64}$/', $id)) $id = null;
        return $id;
    }

    /** Fetch a stored response, or null. */
    function sync_lookup($db, string $opId): ?string
    {
        try {
            if ($db instanceof PDO) {
                $st = $db->prepare('SELECT response_json FROM sync_ops WHERE client_op_id = ?');
                $st->execute([$opId]);
                $row = $st->fetch(PDO::FETCH_ASSOC);
                return $row ? $row['response_json'] : null;
            }
            if ($db instanceof mysqli) {
                $st = $db->prepare('SELECT response_json FROM sync_ops WHERE client_op_id = ?');
                $st->bind_param('s', $opId);
                $st->execute();
                $st->bind_result($json);
                $found = $st->fetch();
                $st->close();
                return $found ? $json : null;
            }
        } catch (Throwable $e) {
            error_log('sync_helper lookup: ' . $e->getMessage());
        }
        return null;
    }

    /** Persist a successful response. */
    function sync_store($db, string $opId, string $endpoint, string $json): void
    {
        try {
            if ($db instanceof PDO) {
                $st = $db->prepare('INSERT IGNORE INTO sync_ops (client_op_id, endpoint, response_json) VALUES (?,?,?)');
                $st->execute([$opId, $endpoint, $json]);
            } elseif ($db instanceof mysqli) {
                $st = $db->prepare('INSERT IGNORE INTO sync_ops (client_op_id, endpoint, response_json) VALUES (?,?,?)');
                $st->bind_param('sss', $opId, $endpoint, $json);
                $st->execute();
                $st->close();
            }
        } catch (Throwable $e) {
            error_log('sync_helper store: ' . $e->getMessage());
        }
    }

    /**
     * Call once at the top of a write endpoint.
     * Replays a stored response and exits if this op was already applied;
     * otherwise buffers output and stores it on shutdown when success=true.
     */
    function sync_begin($db): void
    {
        $opId = sync_client_op_id();
        if ($opId === null) return; // normal (online) request – nothing to do

        $stored = sync_lookup($db, $opId);
        if ($stored !== null) {
            if (!headers_sent()) {
                header('Content-Type: application/json');
                header('X-Sync-Replay: 1');
            }
            echo $stored;
            exit;
        }

        $endpoint = basename($_SERVER['SCRIPT_NAME'] ?? 'unknown');
        ob_start();
        register_shutdown_function(function () use ($db, $opId, $endpoint) {
            $out = ob_get_contents();
            if ($out === false) return;
            ob_end_flush();
            $j = json_decode(trim($out), true);
            if (is_array($j) && !empty($j['success'])) {
                sync_store($db, $opId, $endpoint, trim($out));
            }
        });
    }
}
