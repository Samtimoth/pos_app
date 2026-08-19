# KukuPaja backend (XAMPP)

1. Copy folder `kukupaja_backend` kwenda `C:\xampp\htdocs\kukupaja_backend`.
2. Washa Apache na MySQL kupitia XAMPP Control Panel.
3. Fungua phpMyAdmin, kisha import `database/kukupaja.sql`.
4. Test: `http://localhost/kukupaja_backend/api/health`.
5. Admin panel: `http://localhost/kukupaja_backend/admin/`.
6. Android emulator hutumia `http://10.0.2.2/kukupaja_backend/api`.
7. Simu halisi itumie IPv4 ya PC, mfano `http://192.168.1.10/kukupaja_backend/api`.

Demo accounts (password `password`):

- Admin: `255700000001`
- Broker: `255700000002`
- Customer: `255700000003`

Production notes: tumia HTTPS, token rotation, validation ya picha, rate limiting,
payment webhooks na usiache MySQL root bila password.
