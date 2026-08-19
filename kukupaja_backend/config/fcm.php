<?php
declare(strict_types=1);

/**
 * Firebase Cloud Messaging (HTTP v1) push helper — pure PHP, no libraries.
 *
 * Setup: download a service-account JSON from the Firebase console
 *   (Project settings -> Service accounts -> Generate new private key)
 * and save it next to this file as `fcm-service-account.json`.
 *
 * If that file is absent every function below no-ops quietly, so the API
 * keeps working even before push is configured.
 */

function fcm_service_account(): ?array
{
    $path = __DIR__ . '/fcm-service-account.json';
    if (!is_file($path)) {
        return null;
    }
    $json = json_decode((string)file_get_contents($path), true);
    return (is_array($json) && isset($json['client_email'], $json['private_key'], $json['project_id']))
        ? $json
        : null;
}

function fcm_b64url(string $data): string
{
    return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
}

/** Mints (and briefly caches) an OAuth2 access token for the FCM scope. */
function fcm_access_token(array $sa): ?string
{
    $cacheFile = sys_get_temp_dir() . '/kukupaja_fcm_token.json';
    if (is_file($cacheFile)) {
        $c = json_decode((string)file_get_contents($cacheFile), true);
        if (is_array($c) && (int)($c['exp'] ?? 0) > time() + 60) {
            return (string)$c['token'];
        }
    }

    $now = time();
    $header = ['alg' => 'RS256', 'typ' => 'JWT'];
    $claims = [
        'iss'   => $sa['client_email'],
        'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
        'aud'   => 'https://oauth2.googleapis.com/token',
        'iat'   => $now,
        'exp'   => $now + 3600,
    ];
    $signingInput = fcm_b64url((string)json_encode($header)) . '.' . fcm_b64url((string)json_encode($claims));
    $signature = '';
    if (!openssl_sign($signingInput, $signature, $sa['private_key'], 'sha256')) {
        return null;
    }
    $jwt = $signingInput . '.' . fcm_b64url($signature);

    $ch = curl_init('https://oauth2.googleapis.com/token');
    curl_setopt_array($ch, [
        CURLOPT_POST           => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT        => 10,
        CURLOPT_POSTFIELDS     => http_build_query([
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion'  => $jwt,
        ]),
    ]);
    $resp = curl_exec($ch);
    curl_close($ch);
    $data = json_decode((string)$resp, true);
    $token = $data['access_token'] ?? null;
    if ($token) {
        @file_put_contents($cacheFile, (string)json_encode(['token' => $token, 'exp' => $now + 3500]));
        return (string)$token;
    }
    return null;
}

/**
 * Sends a notification to a list of device tokens. Dead tokens are pruned
 * from kukupaja_device_tokens when the caller passes a PDO.
 */
function fcm_send_to_tokens(array $tokens, string $title, string $body, array $data = [], ?PDO $pdo = null): void
{
    $tokens = array_values(array_unique(array_filter(array_map('strval', $tokens))));
    if (!$tokens) {
        return;
    }
    $sa = fcm_service_account();
    if (!$sa) {
        return;
    }
    $access = fcm_access_token($sa);
    if (!$access) {
        return;
    }
    $projectId = $sa['project_id'];
    $url = "https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send";
    $stringData = array_map('strval', $data);

    foreach ($tokens as $token) {
        $payload = [
            'message' => [
                'token'        => $token,
                'notification' => ['title' => $title, 'body' => $body],
                'data'         => $stringData,
                'android'      => [
                    'priority'     => 'high',
                    'notification' => ['channel_id' => 'orders_channel', 'sound' => 'default'],
                ],
            ],
        ];
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_POST           => true,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => 10,
            CURLOPT_HTTPHEADER     => [
                'Authorization: Bearer ' . $access,
                'Content-Type: application/json',
            ],
            CURLOPT_POSTFIELDS     => (string)json_encode($payload),
        ]);
        $resp = curl_exec($ch);
        $code = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        // A 404/UNREGISTERED means the token is dead — drop it so we stop trying.
        if ($pdo && ($code === 404 || ($code === 400 && str_contains((string)$resp, 'UNREGISTERED')))) {
            try {
                $pdo->prepare('DELETE FROM kukupaja_device_tokens WHERE token=?')->execute([$token]);
            } catch (Throwable $e) { /* ignore */ }
        }
    }
}
