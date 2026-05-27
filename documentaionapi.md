# Dokumentasi API Motoguard Realtime Database

Dokumen ini berisi cara akses Firebase Realtime Database project `ta-motoguard` memakai `curl`.

Base URL:

```text
https://ta-motoguard-default-rtdb.asia-southeast1.firebasedatabase.app
```

Credential service account:

```text
ta-motoguard-firebase-adminsdk-fbsvc-ee9a9af2ee.json
```

Catatan keamanan:

- Jangan commit service account JSON.
- Jangan simpan token `ya29...` asli di file dokumentasi.
- OAuth access token berlaku sekitar 1 jam.
- Parameter `auth=<API_KEY>` tidak bisa dipakai untuk RTDB protected. Gunakan header `Authorization: Bearer <OAUTH_ACCESS_TOKEN>`.

## Ambil Token

Ambil OAuth token untuk Realtime Database:

```bash
TOKEN_SCOPES='https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/firebase.database' \
PRINT_TOKEN=true \
bash scripts/test_firebase_service_account.sh ta-motoguard-firebase-adminsdk-fbsvc-ee9a9af2ee.json
```

Copy nilai setelah:

```text
Access token: ya29...
```

Set variable supaya command lebih pendek:

```bash
TOKEN='PASTE_TOKEN_YA29_DI_SINI'
BASE_URL='https://ta-motoguard-default-rtdb.asia-southeast1.firebasedatabase.app'
```

## Struktur Database

Hasil test root:

```bash
curl -sS \
  "$BASE_URL/.json?shallow=true&print=pretty" \
  -H "Authorization: Bearer $TOKEN"
```

Response saat dites:

```json
{
  "codex_test": true,
  "users": true
}
```

Keterangan:

| Node | Fungsi |
| --- | --- |
| `/users` | Data asli pengguna dan motor Motoguard |
| `/codex_test` | Node test lama, bukan data aplikasi utama |

## Users

Ambil daftar user ID:

```bash
curl -sS \
  "$BASE_URL/users.json?shallow=true&print=pretty" \
  -H "Authorization: Bearer $TOKEN"
```

Response saat dites:

```json
{
  "kGglk6iNsBXflhInNkaMH3s50kD3": true,
  "mVhA7UnQ3IRV92Ug6gc2ZkmtzV43": true
}
```

Struktur setiap user:

```text
/users/{uid}/contacts
/users/{uid}/device
/users/{uid}/profile
```

Contoh cek struktur satu user:

```bash
UID='kGglk6iNsBXflhInNkaMH3s50kD3'

curl -sS \
  "$BASE_URL/users/$UID.json?shallow=true&print=pretty" \
  -H "Authorization: Bearer $TOKEN"
```

Response:

```json
{
  "contacts": true,
  "device": true,
  "profile": true
}
```

## Device

Path:

```text
/users/{uid}/device
```

Ambil status device:

```bash
UID='kGglk6iNsBXflhInNkaMH3s50kD3'

curl -sS \
  "$BASE_URL/users/$UID/device.json?print=pretty" \
  -H "Authorization: Bearer $TOKEN"
```

Contoh response:

```json
{
  "engine_cut": false,
  "is_locked": false,
  "timestamp": 1778595725462
}
```

Field yang ditemukan saat test:

| Field | Tipe | Keterangan |
| --- | --- | --- |
| `engine_cut` | boolean | Status pemutus mesin |
| `is_locked` | boolean | Status kunci motor |
| `is_alarm_active` | boolean | Status alarm, ditemukan pada salah satu user |
| `timestamp` | number | Timestamp update terakhir |

Update sebagian status device dengan `PATCH`:

```bash
UID='kGglk6iNsBXflhInNkaMH3s50kD3'

curl -sS -X PATCH \
  "$BASE_URL/users/$UID/device.json" \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"is_locked":true,"timestamp":1778599999999}'
```

Penting: command di atas mengubah data asli device user. Gunakan hanya kalau memang ingin mengubah status.

## Profile

Path:

```text
/users/{uid}/profile
```

Ambil profile:

```bash
UID='kGglk6iNsBXflhInNkaMH3s50kD3'

curl -sS \
  "$BASE_URL/users/$UID/profile.json?print=pretty" \
  -H "Authorization: Bearer $TOKEN"
```

Contoh response, data pribadi disamarkan:

```json
{
  "createdAt": 1778594210137,
  "emergencyPhone": "+62xxxxxxxxxx",
  "motorType": "Vario",
  "name": "Nama User",
  "plateNumber": "B1234XXX"
}
```

Field yang ditemukan saat test:

| Field | Tipe | Keterangan |
| --- | --- | --- |
| `createdAt` | number | Timestamp pembuatan profile |
| `emergencyPhone` | string | Nomor darurat |
| `motorType` | string | Tipe motor |
| `name` | string | Nama pengguna |
| `plateNumber` | string | Plat nomor |
| `photoUrl` | string | URL foto, ditemukan pada salah satu user |

## Contacts

Path:

```text
/users/{uid}/contacts
```

Ambil daftar contact ID:

```bash
UID='kGglk6iNsBXflhInNkaMH3s50kD3'

curl -sS \
  "$BASE_URL/users/$UID/contacts.json?shallow=true&print=pretty" \
  -H "Authorization: Bearer $TOKEN"
```

Contoh response:

```json
{
  "1778594211616": true
}
```

Ambil detail satu contact:

```bash
UID='kGglk6iNsBXflhInNkaMH3s50kD3'
CONTACT_ID='1778594211616'

curl -sS \
  "$BASE_URL/users/$UID/contacts/$CONTACT_ID.json?print=pretty" \
  -H "Authorization: Bearer $TOKEN"
```

Struktur contact:

```json
{
  "name": "Kontak Darurat",
  "phone": "+62xxxxxxxxxx"
}
```

## Query Parameter

Ambil satu user pertama berdasarkan key:

```bash
curl -sS \
  "$BASE_URL/users.json?orderBy=%22%24key%22&limitToFirst=1&print=pretty" \
  -H "Authorization: Bearer $TOKEN"
```

Ambil data berdasarkan key tertentu:

```bash
UID='kGglk6iNsBXflhInNkaMH3s50kD3'

curl -sS \
  "$BASE_URL/users.json?orderBy=%22%24key%22&equalTo=%22$UID%22&print=pretty" \
  -H "Authorization: Bearer $TOKEN"
```

Catatan encoding:

- `"` ditulis sebagai `%22`
- `$key` ditulis sebagai `%24key`
- Bungkus URL dengan quotes supaya `&` tidak diproses shell.

## CRUD Test Aman

Bagian ini memakai node sementara:

```text
/api_docs_test
```

Node ini sudah dites dan dihapus kembali.

### PUT

Membuat atau mengganti data di path tertentu:

```bash
curl -sS -X PUT \
  "$BASE_URL/api_docs_test/test-001.json" \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"message":"documentation put test","status":"ok","source":"curl-docs"}'
```

Hasil test:

```text
HTTP_STATUS=200
```

### GET

Membaca data:

```bash
curl -sS \
  "$BASE_URL/api_docs_test/test-001.json?print=pretty" \
  -H "Authorization: Bearer $TOKEN"
```

Response saat test:

```json
{
  "message": "documentation put test",
  "source": "curl-docs",
  "status": "ok"
}
```

### PATCH

Update sebagian field:

```bash
curl -sS -X PATCH \
  "$BASE_URL/api_docs_test/test-001.json" \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"status":"updated","patched":true}'
```

Hasil test:

```text
HTTP_STATUS=200
```

### POST

Membuat child dengan auto ID:

```bash
curl -sS -X POST \
  "$BASE_URL/api_docs_test.json" \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"message":"documentation post test","status":"created","source":"curl-docs"}'
```

Response saat test:

```json
{
  "name": "-OsqxVl3FrVgiuYUgWJp"
}
```

### DELETE

Menghapus node:

```bash
curl -sS -X DELETE \
  "$BASE_URL/api_docs_test.json" \
  -H "Authorization: Bearer $TOKEN"
```

Hasil test:

```text
HTTP_STATUS=200
```

Verifikasi setelah delete:

```bash
curl -sS \
  "$BASE_URL/api_docs_test.json?print=pretty" \
  -H "Authorization: Bearer $TOKEN"
```

Response:

```json
null
```

## Helper Script

Test langsung tanpa copy token:

```bash
bash scripts/test_rtdb_service_account.sh \
  ta-motoguard-firebase-adminsdk-fbsvc-ee9a9af2ee.json \
  https://ta-motoguard-default-rtdb.asia-southeast1.firebasedatabase.app \
  users \
  GET
```

Cetak command curl siap paste:

```bash
bash scripts/print_rtdb_curl.sh \
  ta-motoguard-firebase-adminsdk-fbsvc-ee9a9af2ee.json \
  https://ta-motoguard-default-rtdb.asia-southeast1.firebasedatabase.app \
  users \
  GET
```

Cetak command POST siap paste:

```bash
bash scripts/print_rtdb_curl.sh \
  ta-motoguard-firebase-adminsdk-fbsvc-ee9a9af2ee.json \
  https://ta-motoguard-default-rtdb.asia-southeast1.firebasedatabase.app \
  api_docs_test \
  POST \
  '{"message":"hello","status":"ok"}'
```

## Ringkasan Test

Tanggal test: 2026-05-18, timezone Asia/Jakarta.

| Test | Path | Method | Status |
| --- | --- | --- | --- |
| Root node | `/.json` | GET | 200 |
| List users | `/users.json` | GET | 200 |
| User root | `/users/{uid}.json` | GET | 200 |
| Device | `/users/{uid}/device.json` | GET | 200 |
| Profile | `/users/{uid}/profile.json` | GET | 200 |
| Contacts | `/users/{uid}/contacts.json` | GET | 200 |
| PUT test | `/api_docs_test/test-001.json` | PUT | 200 |
| PATCH test | `/api_docs_test/test-001.json` | PATCH | 200 |
| POST test | `/api_docs_test.json` | POST | 200 |
| DELETE cleanup | `/api_docs_test.json` | DELETE | 200 |
| Verify cleanup | `/api_docs_test.json` | GET | 200, `null` |

## Error Umum

`Permission denied`

: Request tidak memakai auth yang valid.

`Unauthorized request`

: Header salah, token expired, atau token dipasang dobel seperti `Authorization: Bearer Authorization: Bearer ...`.

`API key not valid`

: Web API key salah atau bukan API key project tersebut. API key juga tidak bisa langsung dipakai di `auth=` untuk akses RTDB protected.

`null`

: Path tidak ada atau sudah dihapus.
