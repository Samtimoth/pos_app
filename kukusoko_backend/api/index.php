<?php
declare(strict_types=1);

require_once __DIR__ . '/../config/database.php';

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, POST, PUT, OPTIONS');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

function respond(array $data, int $status = 200): never
{
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function body(): array
{
    return json_decode(file_get_contents('php://input') ?: '[]', true) ?: [];
}

function bearerUser(): array
{
    $headers = function_exists('getallheaders') ? getallheaders() : [];
    $header = $_SERVER['HTTP_AUTHORIZATION']
        ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION']
        ?? $headers['Authorization']
        ?? $headers['authorization']
        ?? '';
    $token = str_starts_with($header, 'Bearer ') ? substr($header, 7) : '';
    if ($token === '') respond(['success' => false, 'message' => 'Token inahitajika'], 401);
    $stmt = db()->prepare('SELECT u.* FROM auth_tokens t JOIN users u ON u.id=t.user_id WHERE t.token_hash=? AND t.expires_at>NOW() AND u.is_active=1');
    $stmt->execute([hash('sha256', $token)]);
    $user = $stmt->fetch();
    if (!$user) respond(['success' => false, 'message' => 'Token si sahihi'], 401);
    return $user;
}

function requireRole(array $user, array $roles): void
{
    if (!in_array($user['role'], $roles, true)) {
        respond(['success' => false, 'message' => 'Huna ruhusa'], 403);
    }
}

$path = trim(parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH), '/');
$segments = explode('/', $path);
$apiIndex = array_search('api', $segments, true);
$route = $apiIndex === false ? $path : implode('/', array_slice($segments, $apiIndex + 1));
$method = $_SERVER['REQUEST_METHOD'];

try {
    if ($route === 'health' && $method === 'GET') {
        db()->query('SELECT 1');
        respond(['success' => true, 'message' => 'KukuSoko API iko tayari']);
    }

    if ($route === 'login' && $method === 'POST') {
        $input = body();
        $stmt = db()->prepare('SELECT * FROM users WHERE phone=? AND is_active=1 LIMIT 1');
        $stmt->execute([$input['phone'] ?? '']);
        $user = $stmt->fetch();
        if (!$user || !password_verify((string)($input['password'] ?? ''), $user['password_hash'])) {
            respond(['success' => false, 'message' => 'Namba au password si sahihi'], 422);
        }
        $token = bin2hex(random_bytes(32));
        db()->prepare('INSERT INTO auth_tokens(user_id,token_hash,expires_at) VALUES(?,?,DATE_ADD(NOW(),INTERVAL 30 DAY))')
            ->execute([$user['id'], hash('sha256', $token)]);
        unset($user['password_hash']);
        respond(['success' => true, 'token' => $token, 'user' => $user]);
    }

    if ($route === 'register' && $method === 'POST') {
        $input = body();
        $name = trim((string)($input['name'] ?? ''));
        $phone = preg_replace('/\s+/', '', trim((string)($input['phone'] ?? '')));
        $password = (string)($input['password'] ?? '');
        $location = trim((string)($input['location'] ?? ''));
        if (mb_strlen($name) < 2) respond(['success' => false, 'message' => 'Weka jina kamili'], 422);
        if (!preg_match('/^(?:\+?255|0)\d{9}$/', $phone)) respond(['success' => false, 'message' => 'Weka namba sahihi ya simu'], 422);
        if (strlen($password) < 6) respond(['success' => false, 'message' => 'Password iwe na herufi au namba 6 kwenda juu'], 422);
        $check = db()->prepare('SELECT id FROM users WHERE phone=? LIMIT 1');
        $check->execute([$phone]);
        if ($check->fetch()) respond(['success' => false, 'message' => 'Namba hii tayari imesajiliwa'], 409);
        $stmt = db()->prepare("INSERT INTO users(role,name,phone,password_hash,location,is_verified,is_active) VALUES('customer',?,?,?,?,0,1)");
        $stmt->execute([$name, $phone, password_hash($password, PASSWORD_DEFAULT), $location]);
        $userId = (int)db()->lastInsertId();
        $token = bin2hex(random_bytes(32));
        db()->prepare('INSERT INTO auth_tokens(user_id,token_hash,expires_at) VALUES(?,?,DATE_ADD(NOW(),INTERVAL 30 DAY))')
            ->execute([$userId, hash('sha256', $token)]);
        respond(['success' => true, 'token' => $token, 'user' => ['id' => $userId, 'name' => $name, 'phone' => $phone, 'role' => 'customer', 'location' => $location]], 201);
    }

    if ($route === 'products' && $method === 'GET') {
        $category = trim((string)($_GET['category'] ?? ''));
        if ($category !== '' && $category !== 'wote') {
            $stmt = db()->prepare("SELECT p.id,p.category,p.name,p.description,p.customer_price,p.available_stock,p.location,p.image_url,p.weight,p.age,p.vaccination FROM products p WHERE p.status='approved' AND p.available_stock>0 AND p.category=? ORDER BY p.created_at DESC");
            $stmt->execute([$category]);
            $rows = $stmt->fetchAll();
        } else {
            $rows = db()->query("SELECT p.id,p.category,p.name,p.description,p.customer_price,p.available_stock,p.location,p.image_url,p.weight,p.age,p.vaccination FROM products p WHERE p.status='approved' AND p.available_stock>0 ORDER BY p.created_at DESC")->fetchAll();
        }
        respond(['success' => true, 'data' => $rows]);
    }

    if ($route === 'ads' && $method === 'GET') {
        $rows = db()->query("SELECT id,advertiser_name,title,subtitle,image_url,button_text,target_category FROM advertisements WHERE is_active=1 AND starts_at<=NOW() AND ends_at>=NOW() ORDER BY created_at DESC")->fetchAll();
        respond(['success' => true, 'data' => $rows]);
    }

    if ($route === 'me' && $method === 'GET') {
        $user = bearerUser();
        unset($user['password_hash']);
        respond(['success' => true, 'user' => $user]);
    }

    if (preg_match('#^orders/(\d+)$#', $route, $matches) && $method === 'GET') {
        $user = bearerUser();
        $orderId = (int)$matches[1];
        if ($user['role'] === 'customer') {
            $stmt = db()->prepare('SELECT * FROM orders WHERE id=? AND customer_id=?');
            $stmt->execute([$orderId, $user['id']]);
        } elseif ($user['role'] === 'admin') {
            $stmt = db()->prepare('SELECT * FROM orders WHERE id=?');
            $stmt->execute([$orderId]);
        } else {
            $stmt = db()->prepare('SELECT o.* FROM orders o WHERE o.id=? AND EXISTS (SELECT 1 FROM order_assignments a WHERE a.order_id=o.id AND a.broker_id=?)');
            $stmt->execute([$orderId, $user['id']]);
        }
        $order = $stmt->fetch();
        if (!$order) respond(['success' => false, 'message' => 'Oda haijapatikana'], 404);
        $items = db()->prepare('SELECT oi.id,oi.product_id,oi.quantity,oi.unit_price,p.name,p.category,p.image_url FROM order_items oi JOIN products p ON p.id=oi.product_id WHERE oi.order_id=? ORDER BY oi.id');
        $items->execute([$orderId]);
        respond(['success' => true, 'data' => ['order' => $order, 'items' => $items->fetchAll()]]);
    }

    if ($route === 'orders' && $method === 'GET') {
        $user = bearerUser();
        if ($user['role'] === 'customer') {
            $stmt = db()->prepare('SELECT * FROM orders WHERE customer_id=? ORDER BY created_at DESC');
            $stmt->execute([$user['id']]);
        } elseif ($user['role'] === 'admin') {
            $stmt = db()->query('SELECT o.*,u.name customer_name,u.phone customer_phone FROM orders o JOIN users u ON u.id=o.customer_id ORDER BY o.created_at DESC');
        } else {
            $stmt = db()->prepare('SELECT o.*,a.id assignment_id,a.status assignment_status,a.quantity assigned_quantity,a.deadline,p.name product_name FROM order_assignments a JOIN orders o ON o.id=a.order_id JOIN products p ON p.id=a.product_id WHERE a.broker_id=? ORDER BY a.created_at DESC');
            $stmt->execute([$user['id']]);
        }
        respond(['success' => true, 'data' => $stmt->fetchAll()]);
    }

    if ($route === 'broker/products' && $method === 'GET') {
        $user = bearerUser(); requireRole($user, ['broker']);
        $stmt = db()->prepare('SELECT * FROM products WHERE broker_id=? ORDER BY created_at DESC');
        $stmt->execute([$user['id']]);
        respond(['success' => true, 'data' => $stmt->fetchAll()]);
    }

    if ($route === 'broker/products' && $method === 'POST') {
        $user = bearerUser(); requireRole($user, ['broker']);
        $i = body();
        $stmt = db()->prepare("INSERT INTO products(broker_id,category,name,description,supplier_price,customer_price,total_stock,available_stock,location,weight,age,vaccination,image_url,status) VALUES(?,?,?,?,?,?, ?,?,?,?,?,?,?, 'pending')");
        $stmt->execute([$user['id'],$i['category'] ?? 'vingine',$i['name'],$i['description'] ?? '',$i['supplier_price'],0,$i['stock'],$i['stock'],$i['location'],$i['weight'] ?? null,$i['age'] ?? null,$i['vaccination'] ?? null,$i['image_url'] ?? null]);
        respond(['success' => true, 'message' => 'Listing imetumwa kwa Admin', 'id' => db()->lastInsertId()], 201);
    }

    if ($route === 'orders' && $method === 'POST') {
        $user = bearerUser(); requireRole($user, ['customer']);
        $i = body(); $items = $i['items'] ?? [];
        if (!$items) respond(['success'=>false,'message'=>'Kikapu hakina bidhaa'],422);
        $pdo = db(); $pdo->beginTransaction();
        $total = 0;
        foreach ($items as $item) {
            $s=$pdo->prepare("SELECT id,customer_price,available_stock FROM products WHERE id=? AND status='approved' FOR UPDATE");
            $s->execute([$item['product_id']]); $p=$s->fetch();
            if (!$p || $p['available_stock'] < $item['quantity']) throw new RuntimeException('Stock haitoshi');
            $total += $p['customer_price'] * $item['quantity'];
        }
        $number='KS-'.date('Ymd').'-'.random_int(1000,9999);
        $pdo->prepare("INSERT INTO orders(order_number,customer_id,status,total_amount,delivery_fee,delivery_address,payment_method,payment_status) VALUES(?,?,'pending',?,0,?,?,'pending')")
            ->execute([$number,$user['id'],$total,$i['delivery_address'] ?? '',$i['payment_method'] ?? 'cash']);
        $orderId=(int)$pdo->lastInsertId();
        foreach ($items as $item) {
            $s=$pdo->prepare('SELECT customer_price FROM products WHERE id=?'); $s->execute([$item['product_id']]); $price=$s->fetchColumn();
            $pdo->prepare('INSERT INTO order_items(order_id,product_id,quantity,unit_price) VALUES(?,?,?,?)')->execute([$orderId,$item['product_id'],$item['quantity'],$price]);
        }
        $pdo->commit();
        respond(['success'=>true,'message'=>'Oda imeenda kwa Admin','order_number'=>$number],201);
    }

    if ($route === 'admin/approve-product' && $method === 'PUT') {
        $user=bearerUser(); requireRole($user,['admin']); $i=body();
        db()->prepare("UPDATE products SET customer_price=?,status='approved',approved_by=?,approved_at=NOW() WHERE id=?")
            ->execute([$i['customer_price'],$user['id'],$i['product_id']]);
        respond(['success'=>true,'message'=>'Bidhaa imeidhinishwa']);
    }

    if ($route === 'admin/assign-order' && $method === 'POST') {
        $user=bearerUser(); requireRole($user,['admin']); $i=body(); $pdo=db(); $pdo->beginTransaction();
        $pdo->prepare("INSERT INTO order_assignments(order_id,broker_id,product_id,quantity,status,deadline) VALUES(?,?,?,?, 'pending',?)")
            ->execute([$i['order_id'],$i['broker_id'],$i['product_id'],$i['quantity'],$i['deadline']]);
        $pdo->prepare("UPDATE orders SET status='assigned',updated_at=NOW() WHERE id=?")->execute([$i['order_id']]);
        $pdo->commit(); respond(['success'=>true,'message'=>'Oda imetumwa kwa Broker']);
    }

    if ($route === 'broker/respond-assignment' && $method === 'PUT') {
        $user=bearerUser(); requireRole($user,['broker']); $i=body();
        $status=($i['accept'] ?? false) ? 'accepted' : 'rejected';
        $pdo=db(); $pdo->beginTransaction();
        $stmt=$pdo->prepare("SELECT a.*,p.available_stock FROM order_assignments a JOIN products p ON p.id=a.product_id WHERE a.id=? AND a.broker_id=? AND a.status='pending' FOR UPDATE");
        $stmt->execute([$i['assignment_id'],$user['id']]); $a=$stmt->fetch();
        if (!$a) throw new RuntimeException('Ombi halijapatikana au limejibiwa');
        $pdo->prepare('UPDATE order_assignments SET status=?,responded_at=NOW() WHERE id=?')->execute([$status,$a['id']]);
        if ($status === 'accepted') {
            $pending=$pdo->prepare("SELECT COUNT(*) FROM order_assignments WHERE order_id=? AND status='pending'");
            $pending->execute([$a['order_id']]);
            $nextOrderStatus=(int)$pending->fetchColumn()===0 ? 'accepted' : 'assigned';
            $pdo->prepare('UPDATE orders SET status=? WHERE id=?')->execute([$nextOrderStatus,$a['order_id']]);
        } else {
            $pdo->prepare("UPDATE orders SET status='confirmed' WHERE id=?")->execute([$a['order_id']]);
        }
        $pdo->commit(); respond(['success'=>true,'message'=>$status === 'accepted' ? 'Oda imekubaliwa' : 'Oda imekataliwa']);
    }

    if ($route === 'admin/dashboard' && $method === 'GET') {
        $user=bearerUser(); requireRole($user,['admin']);
        $data=[
            'sales_today'=>(float)db()->query("SELECT COALESCE(SUM(total_amount+delivery_fee),0) FROM orders WHERE DATE(created_at)=CURDATE() AND status NOT IN ('cancelled','refunded')")->fetchColumn(),
            'new_orders'=>(int)db()->query("SELECT COUNT(*) FROM orders WHERE status='pending'")->fetchColumn(),
            'pending_listings'=>(int)db()->query("SELECT COUNT(*) FROM products WHERE status='pending'")->fetchColumn(),
            'active_brokers'=>(int)db()->query("SELECT COUNT(*) FROM users WHERE role='broker' AND is_active=1")->fetchColumn(),
        ];
        respond(['success'=>true,'data'=>$data]);
    }

    if ($route === 'messages' && $method === 'GET') {
        $user=bearerUser();
        if ($user['role'] === 'admin') {
            $otherId=(int)($_GET['with_user_id'] ?? 0);
            if ($otherId < 1) respond(['success'=>false,'message'=>'Chagua mtumiaji wa kuwasiliana naye'],422);
        } else {
            $adminStmt=db()->query("SELECT id FROM users WHERE role='admin' AND is_active=1 ORDER BY id LIMIT 1");
            $otherId=(int)$adminStmt->fetchColumn();
            if ($otherId < 1) respond(['success'=>false,'message'=>'Admin hajapatikana kwa sasa'],503);
        }
        $otherStmt=db()->prepare('SELECT id,name,role FROM users WHERE id=? AND is_active=1');
        $otherStmt->execute([$otherId]); $other=$otherStmt->fetch();
        if(!$other) respond(['success'=>false,'message'=>'Mtumiaji hajapatikana'],404);
        db()->prepare('UPDATE messages SET read_at=NOW() WHERE sender_id=? AND receiver_id=? AND read_at IS NULL')
            ->execute([$otherId,$user['id']]);
        $stmt=db()->prepare('SELECT m.id,m.sender_id,m.receiver_id,m.order_id,m.message,m.read_at,m.created_at,s.name sender_name FROM messages m JOIN users s ON s.id=m.sender_id WHERE (m.sender_id=? AND m.receiver_id=?) OR (m.sender_id=? AND m.receiver_id=?) ORDER BY m.id ASC LIMIT 300');
        $stmt->execute([$user['id'],$otherId,$otherId,$user['id']]);
        $rows=$stmt->fetchAll();
        foreach($rows as &$row) $row['is_mine']=(int)$row['sender_id']===(int)$user['id'];
        respond(['success'=>true,'data'=>$rows,'other_user'=>$other]);
    }

    if ($route === 'messages' && $method === 'POST') {
        $user=bearerUser(); $i=body();
        $message=trim((string)($i['message'] ?? ''));
        if($message==='') respond(['success'=>false,'message'=>'Andika ujumbe kwanza'],422);
        if(mb_strlen($message)>2000) respond(['success'=>false,'message'=>'Ujumbe ni mrefu sana'],422);
        $receiver=(int)($i['receiver_id'] ?? 0);
        if($user['role']!=='admin') {
            if($receiver<1) $receiver=(int)db()->query("SELECT id FROM users WHERE role='admin' AND is_active=1 ORDER BY id LIMIT 1")->fetchColumn();
            $s=db()->prepare('SELECT role FROM users WHERE id=? AND is_active=1'); $s->execute([$receiver]);
            if($s->fetchColumn()!=='admin') respond(['success'=>false,'message'=>'Mawasiliano lazima yapitie kwa Admin'],403);
        } else {
            $s=db()->prepare("SELECT role FROM users WHERE id=? AND is_active=1 AND role IN ('customer','broker')"); $s->execute([$receiver]);
            if(!$s->fetchColumn()) respond(['success'=>false,'message'=>'Mpokeaji hajapatikana'],404);
        }
        db()->prepare('INSERT INTO messages(sender_id,receiver_id,order_id,message) VALUES(?,?,?,?)')->execute([$user['id'],$receiver,$i['order_id'] ?? null,$message]);
        respond(['success'=>true,'message'=>'Ujumbe umetumwa'],201);
    }

    respond(['success' => false, 'message' => 'Endpoint haijapatikana'], 404);
} catch (Throwable $e) {
    if (db()->inTransaction()) db()->rollBack();
    respond(['success' => false, 'message' => $e->getMessage()], 500);
}
