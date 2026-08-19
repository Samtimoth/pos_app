<?php
declare(strict_types=1);

// One-time SQL importer. Protected by a secret token, self-deletes on success.
// Usage: /kukusokoni_app/_import_once.php?token=SECRET123

$expectedToken = 'kuku2026import';

if (($_GET['token'] ?? '') !== $expectedToken) {
    http_response_code(403);
    echo "Forbidden";
    exit;
}

require __DIR__ . '/config/database.php';

header('Content-Type: text/plain');

$files = [
    __DIR__ . '/database/kukusoko.sql',
    __DIR__ . '/database/migration_admin_workflows.sql',
    __DIR__ . '/database/migration_ads_categories.sql',
];

$pdo = db();
$errors = [];

foreach ($files as $file) {
    if (!file_exists($file)) {
        echo "SKIP (not found): $file\n";
        continue;
    }
    echo "=== Importing: " . basename($file) . " ===\n";
    $sql = file_get_contents($file);

    // Strip -- comments, split on statement-terminating semicolons.
    $sql = preg_replace('/^--.*$/m', '', $sql);
    $statements = array_filter(array_map('trim', explode(";\n", $sql)));
    // Handle statements not followed by a newline after the final semicolon too.
    $lastChunk = array_pop($statements);
    if ($lastChunk !== null) {
        foreach (array_filter(array_map('trim', explode(';', $lastChunk))) as $s) {
            $statements[] = $s;
        }
    }

    foreach ($statements as $stmt) {
        $stmt = trim($stmt);
        if ($stmt === '') {
            continue;
        }
        try {
            $pdo->exec($stmt);
            echo "OK: " . substr(str_replace("\n", ' ', $stmt), 0, 80) . "...\n";
        } catch (PDOException $e) {
            $msg = "ERROR on statement: " . substr(str_replace("\n", ' ', $stmt), 0, 120) . "\n  -> " . $e->getMessage() . "\n";
            echo $msg;
            $errors[] = $msg;
        }
    }
}

echo "\n=== DONE ===\n";
if ($errors) {
    echo count($errors) . " error(s) occurred (see above). File NOT deleted so you can retry after fixing.\n";
} else {
    echo "All statements executed successfully.\n";
    @unlink(__FILE__);
    echo "This importer script has deleted itself.\n";
}
