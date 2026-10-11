# iOS tweak admin backend

Backend Node.js/Express + SQLite for server-side Admin/Admin Dev authentication, durable blacklist, session revocation, violation windows, audit log and a separate minimal monitoring API.

## Local setup

1. Install Node.js 20+.
2. Copy `.env.example` to `.env` and **change both example passwords immediately** before exposing the service.
3. Run `npm install` then `npm start`.
4. Health check: `GET http://127.0.0.1:8080/health`.
5. Put this service behind HTTPS (Caddy/nginx/managed hosting) before using it from the tweak. Do not expose plain HTTP credentials to the Internet.
6. Set `TIAdminAPIBaseURL` in `RootListController.txt` to your deployed HTTPS origin, for example `https://admin-api.example.com`, then rename the file to `.m` and rebuild with Theos.

## Accounts and roles

- `ADMIN_USER` / `ADMIN_PASSWORD` -> `admin`
- `DEV_ADMIN_USER` / `DEV_ADMIN_PASSWORD` -> `admin_dev`

Passwords are bcrypt-hashed. Existing users' passwords are not overwritten on every restart. Rotate passwords using an operational database migration or a dedicated password-reset workflow; do not commit `.env`.

## Main endpoints

- `POST /v1/auth/login` JSON `{ "username": "...", "password": "...", "device_id": "optional" }`
- `GET /v1/auth/me` Bearer token
- `POST /v1/auth/logout` Bearer token
- `POST /v1/monitor/checkin` Bearer token + `{ "device_id": "stable-random-id", "tweak_version": "..." }`
- `GET /v1/admin/devices` Admin Dev only
- `POST /v1/admin/blacklist` Admin Dev only + `{ "device_id": "...", "reason": "..." }`
- `DELETE /v1/admin/blacklist/:deviceId` Admin Dev only
- `POST /v1/admin/revoke-session` Admin Dev only + `{ "session_id": "..." }`
- `POST /v1/admin/violation` Admin Dev only + `{ "username": "...", "device_id": "optional" }`; first violation blocks 3 hours, second 3 days, third permanently disables the account.
- `GET /v1/admin/audit` Admin Dev only

## Security notes

- SQLite database persists under `DB_PATH`; back it up securely. Uninstalling/updating the tweak does not erase server records.
- Use HTTPS, firewall the service, rotate the example credentials, and protect backups.
- The monitoring API stores only a client-provided pseudonymous device ID, tweak version and last-seen time; it does not access iCloud or private account data.
- This starter does not implement remote tweak uninstall or app crashing. Lock/revoke access server-side instead.
- Admin Dev-only UI in the tweak is only a client-side presentation gate. Every privileged API operation is independently checked on the server.
- No app can guarantee revocation while the device is offline; sensitive operations must fail closed and check `/v1/auth/me` before use.
