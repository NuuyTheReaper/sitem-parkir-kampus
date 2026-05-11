# Smart Campus Parking System Backend API Documentation

Dokumentasi ini menjelaskan endpoint backend FastAPI untuk Smart Campus Parking System.

## Base URL

Lokal:

```bash
http://127.0.0.1:8000
```

Deploy VPS contoh:

```bash
http://43.133.155.101:8088
```

Gunakan variabel agar contoh curl lebih ringkas:

```bash
BASE_URL="http://43.133.155.101:8088"
```

## Autentikasi

Sebagian besar endpoint memakai JWT Bearer Token.

Format header:

```http
Authorization: Bearer <access_token>
```

Role:

| Role | Akses |
|---|---|
| `admin` | Semua endpoint admin, sebagian endpoint petugas |
| `petugas` | Endpoint petugas dan emergency gate |
| `mahasiswa` | Endpoint mahasiswa |

Catatan:

- Endpoint `/api/gate/ml/plate-detect`, `/api/gate/dual-validate`, dan `/api/gate/scan` untuk IoT saat ini tidak memakai token.
- Endpoint WebSocket juga tidak memakai token di kode saat ini.
- Token dihasilkan dari `/api/auth/login`.

## Enum

Nilai yang umum dipakai:

| Field | Nilai |
|---|---|
| `role` | `admin`, `petugas`, `mahasiswa` |
| `jenis_kendaraan` | `Motor`, `Mobil` |
| `status_validasi` | `pending`, `disetujui`, `ditolak` |
| `gate_type` / `jenis_aktivitas` | `masuk`, `keluar` |
| `status_akses` | `otomatis`, `manual_petugas` |
| `access_request.status` | `pending`, `disetujui`, `ditolak` |

## Ringkasan Endpoint

| Method | Endpoint | Auth | Keterangan |
|---|---|---|---|
| GET | `/` | Public | Health check API |
| GET | `/uploads/{path}` | Public | Akses file upload, termasuk foto STNK |
| POST | `/api/auth/login` | Public | Login dan mendapatkan JWT |
| GET | `/api/auth/me` | Bearer token | Profil user login |
| POST | `/api/auth/change-password` | Bearer token | Ubah password user login |
| GET | `/api/admin/dashboard-stats` | Admin | Statistik dashboard |
| GET | `/api/admin/activity-chart` | Admin | Grafik aktivitas 7 hari |
| POST | `/api/admin/expire-old-requests` | Admin | Menolak request pending yang kadaluarsa |
| GET | `/api/admin/mahasiswa` | Admin | List mahasiswa |
| POST | `/api/admin/mahasiswa` | Admin | Tambah mahasiswa |
| PUT | `/api/admin/mahasiswa/{user_id}` | Admin | Update mahasiswa |
| DELETE | `/api/admin/mahasiswa/{user_id}` | Admin | Hapus mahasiswa |
| GET | `/api/admin/petugas` | Admin | List petugas |
| POST | `/api/admin/petugas` | Admin | Tambah petugas |
| PUT | `/api/admin/petugas/{user_id}` | Admin | Update petugas |
| DELETE | `/api/admin/petugas/{user_id}` | Admin | Hapus petugas |
| GET | `/api/admin/prodi` | Admin | List program studi |
| POST | `/api/admin/prodi` | Admin | Tambah program studi |
| DELETE | `/api/admin/prodi/{prodi_id}` | Admin | Hapus program studi |
| GET | `/api/admin/reports` | Admin | List laporan parkir |
| GET | `/api/admin/reports/export-csv` | Admin | Export laporan parkir CSV |
| GET | `/api/admin/announcements` | Admin | List semua pengumuman |
| POST | `/api/admin/broadcast` | Admin | Buat dan broadcast pengumuman |
| PUT | `/api/admin/announcements/{ann_id}` | Admin | Update pengumuman |
| DELETE | `/api/admin/announcements/{ann_id}` | Admin | Hapus pengumuman |
| GET | `/api/petugas/vehicles/pending` | Petugas/Admin | List kendaraan pending |
| PUT | `/api/petugas/vehicles/{vehicle_id}/verify` | Petugas/Admin | Verifikasi kendaraan |
| GET | `/api/petugas/access-requests/pending` | Petugas/Admin | List request akses pending |
| PUT | `/api/petugas/access-requests/{request_id}/respond` | Petugas/Admin | Setujui/tolak request akses |
| GET | `/api/petugas/search` | Petugas/Admin | Cari user atau kendaraan |
| GET | `/api/petugas/session-stats` | Petugas/Admin | Statistik sesi petugas |
| PUT | `/api/petugas/flag-user/{user_id}` | Petugas/Admin | Tandai/hapus tanda user bermasalah |
| GET | `/api/petugas/activity-chart` | Petugas/Admin | Grafik aktivitas 7 hari |
| GET | `/api/mahasiswa/vehicles` | Mahasiswa | List kendaraan sendiri |
| POST | `/api/mahasiswa/vehicles` | Mahasiswa | Daftar kendaraan |
| POST | `/api/mahasiswa/vehicles/{vehicle_id}/upload-stnk` | Mahasiswa | Upload foto STNK |
| GET | `/api/mahasiswa/status-parkir` | Mahasiswa | Status parkir saat ini |
| POST | `/api/mahasiswa/access-request` | Mahasiswa | Request akses manual |
| GET | `/api/mahasiswa/my-requests` | Mahasiswa | Riwayat request akses |
| GET | `/api/mahasiswa/announcements` | Mahasiswa | Pengumuman aktif |
| GET | `/api/mahasiswa/riwayat-parkir` | Mahasiswa | Riwayat parkir |
| POST | `/api/gate/ml/plate-detect` | Public saat ini | Terima hasil OCR plat dari ML service |
| POST | `/api/gate/dual-validate` | Public saat ini | Validasi RFID dan plat dari IoT |
| POST | `/api/gate/scan` | Public saat ini | Legacy scan RFID dan plat dari IoT |
| POST | `/api/gate/emergency-action` | Petugas/Admin | Manual override gerbang |
| GET | `/api/gate/stats/capacity` | Public saat ini | Kapasitas parkir |
| WS | `/api/gate/monitor/live` | Public saat ini | Live monitor event gate |
| WS | `/api/gate/petugas/notifications` | Public saat ini | Notifikasi request akses baru |

## Akun Dummy Seed

Jika database kosong, jalankan:

```bash
docker exec -it backend-backend-1 python seed.py
```

Akun dari `seed.py`:

| Role | Username | Password |
|---|---|---|
| Admin | `admin123` | `adminpassword` |
| Petugas | `petugas123` | `petugaspassword` |
| Mahasiswa | `11223344` | `mhspassword` |
| Mahasiswa | `55667788` | `mhspassword` |

Data kendaraan dummy:

| NIM | Plat | Status |
|---|---|---|
| `11223344` | `G 1234 AB` | `disetujui` |
| `55667788` | `G 5678 CD` | `pending` |

Penting untuk test IoT: endpoint gate mencocokkan `rfid_uid` pada `users.rfid_uid`. RFID diisi manual melalui endpoint admin mahasiswa (`POST`/`PUT /api/admin/mahasiswa`).

## Public

### GET `/`

Cek API hidup.

Response:

```json
{
  "status": "success",
  "message": "Welcome to Smart Campus Parking System API"
}
```

Curl:

```bash
curl "$BASE_URL/"
```

### GET `/uploads/{path}`

Mengakses file statis upload, misalnya foto STNK.

Contoh:

```bash
curl "$BASE_URL/uploads/stnk/nama_file.jpg"
```

## Authentication

### POST `/api/auth/login`

Login dengan `nim_npp` atau `npp`. Endpoint memakai form URL encoded, bukan JSON.

Body:

| Field | Type | Required |
|---|---|---|
| `username` | string | yes |
| `password` | string | yes |

Curl:

```bash
curl -X POST "$BASE_URL/api/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=petugas123&password=petugaspassword"
```

Response:

```json
{
  "access_token": "jwt_token",
  "token_type": "bearer",
  "role": "petugas",
  "nama": "Budi Petugas",
  "nim_npp": "petugas123"
}
```

Simpan token:

```bash
TOKEN=$(curl -s -X POST "$BASE_URL/api/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=petugas123&password=petugaspassword" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
```

### GET `/api/auth/me`

Mengambil profil user dari token.

Auth: semua user login.

Curl:

```bash
curl "$BASE_URL/api/auth/me" \
  -H "Authorization: Bearer $TOKEN"
```

### POST `/api/auth/change-password`

Mengganti password user login.

Auth: semua user login.

Body:

```json
{
  "old_password": "password_lama",
  "new_password": "password_baru"
}
```

Curl:

```bash
curl -X POST "$BASE_URL/api/auth/change-password" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "old_password": "petugaspassword",
    "new_password": "passwordbaru"
  }'
```

## Admin

Semua endpoint admin membutuhkan token role `admin`.

Login admin:

```bash
ADMIN_TOKEN=$(curl -s -X POST "$BASE_URL/api/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin123&password=adminpassword" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
```

### GET `/api/admin/dashboard-stats`

Statistik dashboard admin.

Curl:

```bash
curl "$BASE_URL/api/admin/dashboard-stats" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

Response:

```json
{
  "total_mahasiswa": 2,
  "total_petugas": 1,
  "masuk_today": 1,
  "keluar_today": 0
}
```

### GET `/api/admin/activity-chart`

Grafik aktivitas parkir 7 hari terakhir.

Curl:

```bash
curl "$BASE_URL/api/admin/activity-chart" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

### POST `/api/admin/expire-old-requests`

Menolak otomatis access request `pending` yang sudah lebih dari 10 menit.

Curl:

```bash
curl -X POST "$BASE_URL/api/admin/expire-old-requests" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

### Mahasiswa CRUD

#### GET `/api/admin/mahasiswa`

List semua mahasiswa.

```bash
curl "$BASE_URL/api/admin/mahasiswa" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

#### POST `/api/admin/mahasiswa`

Membuat mahasiswa.

Body:

```json
{
  "nim_npp": "22110001",
  "nama": "Nama Mahasiswa",
  "prodi_id": 1,
  "angkatan": 2024,
  "rfid_uid": "RFID_22110001",
  "role": "mahasiswa",
  "password": "password123"
}
```

Curl:

```bash
curl -X POST "$BASE_URL/api/admin/mahasiswa" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "nim_npp": "22110001",
    "nama": "Nama Mahasiswa",
    "prodi_id": 1,
    "angkatan": 2024,
    "rfid_uid": "RFID_22110001",
    "role": "mahasiswa",
    "password": "password123"
  }'
```

#### PUT `/api/admin/mahasiswa/{user_id}`

Update mahasiswa.

Body dapat berisi sebagian field:

```json
{
  "nama": "Nama Baru",
  "angkatan": 2023,
  "rfid_uid": "RFID_22110001",
  "password": "passwordbaru"
}
```

#### DELETE `/api/admin/mahasiswa/{user_id}`

Menghapus mahasiswa.

```bash
curl -X DELETE "$BASE_URL/api/admin/mahasiswa/1" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

### Petugas CRUD

#### GET `/api/admin/petugas`

List semua petugas.

```bash
curl "$BASE_URL/api/admin/petugas" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

#### POST `/api/admin/petugas`

Membuat petugas.

Body:

```json
{
  "nim_npp": "petugas002",
  "nama": "Petugas Dua",
  "role": "petugas",
  "password": "password123"
}
```

#### PUT `/api/admin/petugas/{user_id}`

Update petugas.

Body contoh:

```json
{
  "nama": "Petugas Baru",
  "password": "passwordbaru"
}
```

#### DELETE `/api/admin/petugas/{user_id}`

Menghapus petugas.

```bash
curl -X DELETE "$BASE_URL/api/admin/petugas/2" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

### Prodi CRUD

#### GET `/api/admin/prodi`

List prodi.

```bash
curl "$BASE_URL/api/admin/prodi" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

#### POST `/api/admin/prodi`

Membuat prodi.

Body:

```json
{
  "nama": "Teknik Komputer"
}
```

#### DELETE `/api/admin/prodi/{prodi_id}`

Menghapus prodi.

```bash
curl -X DELETE "$BASE_URL/api/admin/prodi/1" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

### Reports

#### GET `/api/admin/reports`

List log parkir terbaru, maksimal 200 data.

```bash
curl "$BASE_URL/api/admin/reports" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

#### GET `/api/admin/reports/export-csv`

Download CSV log parkir, maksimal 500 data.

```bash
curl "$BASE_URL/api/admin/reports/export-csv" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -o parking_logs.csv
```

### Announcements

#### GET `/api/admin/announcements`

List semua pengumuman.

```bash
curl "$BASE_URL/api/admin/announcements" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

#### POST `/api/admin/broadcast`

Membuat pengumuman dan broadcast ke WebSocket monitor.

Body:

```json
{
  "message": "Gerbang B sedang maintenance.",
  "expires_at": "2026-05-07T23:59:59Z"
}
```

`expires_at` opsional.

#### PUT `/api/admin/announcements/{ann_id}`

Update pengumuman.

Body:

```json
{
  "message": "Pengumuman diperbarui.",
  "expires_at": null
}
```

#### DELETE `/api/admin/announcements/{ann_id}`

Menghapus pengumuman.

```bash
curl -X DELETE "$BASE_URL/api/admin/announcements/1" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

## Petugas

Endpoint petugas dapat diakses role `petugas` dan `admin`.

Login petugas:

```bash
PETUGAS_TOKEN=$(curl -s -X POST "$BASE_URL/api/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=petugas123&password=petugaspassword" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
```

### GET `/api/petugas/vehicles/pending`

List kendaraan yang menunggu validasi STNK.

```bash
curl "$BASE_URL/api/petugas/vehicles/pending" \
  -H "Authorization: Bearer $PETUGAS_TOKEN"
```

### PUT `/api/petugas/vehicles/{vehicle_id}/verify`

Validasi kendaraan.

Query parameter:

| Field | Nilai |
|---|---|
| `status` | `disetujui` atau `ditolak` |

Curl:

```bash
curl -X PUT "$BASE_URL/api/petugas/vehicles/1/verify?status=disetujui" \
  -H "Authorization: Bearer $PETUGAS_TOKEN"
```

### GET `/api/petugas/access-requests/pending`

List permintaan akses manual yang masih pending.

```bash
curl "$BASE_URL/api/petugas/access-requests/pending" \
  -H "Authorization: Bearer $PETUGAS_TOKEN"
```

### PUT `/api/petugas/access-requests/{request_id}/respond`

Menjawab permintaan akses manual.

Query parameter:

| Field | Nilai |
|---|---|
| `action` | `disetujui` atau `ditolak` |
| `catatan` | string opsional |

Curl:

```bash
curl -X PUT "$BASE_URL/api/petugas/access-requests/1/respond?action=disetujui&catatan=Diizinkan" \
  -H "Authorization: Bearer $PETUGAS_TOKEN"
```

Jika disetujui, backend membuat `ParkingLog` dengan `status_akses` bernilai `manual_petugas`.

### GET `/api/petugas/search`

Cari user berdasarkan NIM/NPP, nama, atau plat kendaraan.

Query parameter:

| Field | Type |
|---|---|
| `query` | string |

Curl:

```bash
curl "$BASE_URL/api/petugas/search?query=G%201234%20AB" \
  -H "Authorization: Bearer $PETUGAS_TOKEN"
```

### GET `/api/petugas/session-stats`

Statistik sesi petugas hari ini.

```bash
curl "$BASE_URL/api/petugas/session-stats" \
  -H "Authorization: Bearer $PETUGAS_TOKEN"
```

### PUT `/api/petugas/flag-user/{user_id}`

Memberi atau menghapus flag pada user.

Query parameter:

| Field | Nilai |
|---|---|
| `is_flagged` | `true` atau `false` |
| `reason` | string opsional |

Curl:

```bash
curl -X PUT "$BASE_URL/api/petugas/flag-user/1?is_flagged=true&reason=Parkir%20sembarangan" \
  -H "Authorization: Bearer $PETUGAS_TOKEN"
```

### GET `/api/petugas/activity-chart`

Grafik aktivitas parkir 7 hari terakhir.

```bash
curl "$BASE_URL/api/petugas/activity-chart" \
  -H "Authorization: Bearer $PETUGAS_TOKEN"
```

## Mahasiswa

Semua endpoint mahasiswa membutuhkan token role `mahasiswa`.

Login mahasiswa:

```bash
MHS_TOKEN=$(curl -s -X POST "$BASE_URL/api/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=11223344&password=mhspassword" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
```

### GET `/api/mahasiswa/vehicles`

List kendaraan milik mahasiswa login.

```bash
curl "$BASE_URL/api/mahasiswa/vehicles" \
  -H "Authorization: Bearer $MHS_TOKEN"
```

### POST `/api/mahasiswa/vehicles`

Mendaftarkan kendaraan baru. Status awal selalu `pending`.

Body:

```json
{
  "jenis_kendaraan": "Motor",
  "plat_nomor": "G 8888 ZZ",
  "merek": "Honda Beat",
  "foto_stnk": null
}
```

Curl:

```bash
curl -X POST "$BASE_URL/api/mahasiswa/vehicles" \
  -H "Authorization: Bearer $MHS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "jenis_kendaraan": "Motor",
    "plat_nomor": "G 8888 ZZ",
    "merek": "Honda Beat",
    "foto_stnk": null
  }'
```

### POST `/api/mahasiswa/vehicles/{vehicle_id}/upload-stnk`

Upload foto STNK.

Auth: mahasiswa pemilik kendaraan.

Format: `multipart/form-data`

Field:

| Field | Type |
|---|---|
| `file` | image/jpeg, image/png, image/webp |

Curl:

```bash
curl -X POST "$BASE_URL/api/mahasiswa/vehicles/1/upload-stnk" \
  -H "Authorization: Bearer $MHS_TOKEN" \
  -F "file=@/path/to/stnk.jpg"
```

Response:

```json
{
  "status": "success",
  "message": "Foto STNK berhasil diupload",
  "path": "/uploads/stnk/stnk_1_xxxxxxxx.jpg"
}
```

### GET `/api/mahasiswa/status-parkir`

Status parkir mahasiswa berdasarkan log terakhir.

```bash
curl "$BASE_URL/api/mahasiswa/status-parkir" \
  -H "Authorization: Bearer $MHS_TOKEN"
```

### POST `/api/mahasiswa/access-request`

Membuat permintaan akses manual ke petugas.

Query parameter:

| Field | Nilai |
|---|---|
| `action` | `masuk` atau `keluar` |

Curl:

```bash
curl -X POST "$BASE_URL/api/mahasiswa/access-request?action=masuk" \
  -H "Authorization: Bearer $MHS_TOKEN"
```

Syarat:

- Mahasiswa harus punya minimal satu kendaraan `disetujui`.
- Tidak boleh ada request lain yang masih `pending`.

### GET `/api/mahasiswa/my-requests`

List 10 request akses terakhir milik mahasiswa login.

```bash
curl "$BASE_URL/api/mahasiswa/my-requests" \
  -H "Authorization: Bearer $MHS_TOKEN"
```

### GET `/api/mahasiswa/announcements`

List pengumuman aktif.

```bash
curl "$BASE_URL/api/mahasiswa/announcements" \
  -H "Authorization: Bearer $MHS_TOKEN"
```

### GET `/api/mahasiswa/riwayat-parkir`

Riwayat parkir mahasiswa login, maksimal 30 data.

```bash
curl "$BASE_URL/api/mahasiswa/riwayat-parkir" \
  -H "Authorization: Bearer $MHS_TOKEN"
```

## IoT Gate

Endpoint IoT saat ini tidak memakai token. Untuk produksi, tambahkan API key/signature di sisi device.

### POST `/api/gate/ml/plate-detect`

Endpoint untuk ML service mengirim hasil OCR plat nomor dari kamera gate. Data disimpan sementara per `gate_id`.

Body:

```json
{
  "gate_id": "GATE_MASUK_1",
  "detected_plate": "G 1234 AB",
  "confidence": 0.94,
  "image_path": "/uploads/ml/gate_masuk_1.jpg",
  "timestamp": "2026-05-07T10:30:00Z"
}
```

Field:

| Field | Type | Required | Keterangan |
|---|---|---|---|
| `gate_id` | string | yes | ID gerbang fisik, contoh `GATE_MASUK_1` |
| `detected_plate` | string | yes | Plat nomor hasil OCR |
| `confidence` | number | yes | Confidence ML, rentang `0.0` sampai `1.0` |
| `image_path` | string/null | no | Path gambar bukti deteksi |
| `timestamp` | datetime/null | no | Waktu deteksi. Jika kosong, backend memakai waktu saat request diterima |

Curl:

```bash
curl -X POST "$BASE_URL/api/gate/ml/plate-detect" \
  -H "Content-Type: application/json" \
  -d '{
    "gate_id": "GATE_MASUK_1",
    "detected_plate": "G 1234 AB",
    "confidence": 0.94,
    "image_path": "/uploads/ml/gate_masuk_1.jpg"
  }'
```

Response:

```json
{
  "status": "received",
  "message": "Plate 'G 1234 AB' stored for gate GATE_MASUK_1",
  "gate_id": "GATE_MASUK_1"
}
```

### POST `/api/gate/dual-validate`

Endpoint utama untuk alat IoT/gateway controller. Device mengirim UID RFID dan hasil deteksi plat, lalu backend memvalidasi keduanya.

Auth: tidak memakai token di kode saat ini.

Body:

```json
{
  "rfid_uid": "RFID_BUDI_123",
  "detected_plate": "G 1234 AB",
  "ml_confidence": 0.94,
  "gate_type": "masuk",
  "gate_id": "GATE_MASUK_1"
}
```

Field:

| Field | Type | Required | Keterangan |
|---|---|---|---|
| `rfid_uid` | string | yes | UID RFID yang dibaca alat |
| `detected_plate` | string | yes | Plat nomor hasil kamera/ML |
| `ml_confidence` | number | no | Confidence ML. Default `1.0`, minimal valid saat ini `0.70` |
| `gate_type` | string | yes | `masuk` atau `keluar` |
| `gate_id` | string | no | ID gerbang fisik. Default `GATE_DEFAULT` |

Curl masuk:

```bash
curl -X POST "$BASE_URL/api/gate/dual-validate" \
  -H "Content-Type: application/json" \
  -d '{
    "rfid_uid": "RFID_BUDI_123",
    "detected_plate": "G 1234 AB",
    "ml_confidence": 0.94,
    "gate_type": "masuk",
    "gate_id": "GATE_MASUK_1"
  }'
```

Curl keluar:

```bash
curl -X POST "$BASE_URL/api/gate/dual-validate" \
  -H "Content-Type: application/json" \
  -d '{
    "rfid_uid": "RFID_BUDI_123",
    "detected_plate": "G 1234 AB",
    "ml_confidence": 0.94,
    "gate_type": "keluar",
    "gate_id": "GATE_KELUAR_1"
  }'
```

Response sukses:

```json
{
  "action": "open_gate",
  "message": "Akses masuk diizinkan",
  "student_name": "Budi Santoso",
  "plate_number": "G 1234 AB",
  "validation_detail": "Plat nomor cocok — validasi ganda berhasil"
}
```

Response RFID tidak ditemukan:

```json
{
  "action": "keep_closed",
  "message": "RFID tidak terdaftar",
  "student_name": null,
  "plate_number": null,
  "validation_detail": "UID kartu tidak ditemukan di database"
}
```

Response plat tidak cocok:

```json
{
  "action": "keep_closed",
  "message": "Plat nomor tidak cocok dengan data terdaftar",
  "student_name": "Budi Santoso",
  "plate_number": "G 9999 XX",
  "validation_detail": "Plat tidak cocok: DB='G1234AB' vs ML='G9999XX'"
}
```

Alur validasi:

1. Backend mencari `rfid_uid` pada `users.rfid_uid`.
2. Backend mengambil kendaraan user yang `status_validasi = disetujui`.
3. Backend menormalisasi plat DB dan plat ML, misalnya `G 1234 AB` menjadi `G1234AB`.
4. Backend menolak request jika confidence ML kurang dari `0.70`.
5. Backend menolak duplikasi `masuk` sebelum ada log `keluar`, dan duplikasi `keluar` sebelum ada log `masuk`.
6. Jika valid, backend membuat `ParkingLog` dengan `status_akses = otomatis`.
7. Backend broadcast event ke WebSocket `/api/gate/monitor/live`.

### POST `/api/gate/scan`

Endpoint legacy untuk simulator IoT lama. Gunakan `/api/gate/dual-validate` untuk flow baru RFID + ML confidence.

Auth: tidak memakai token di kode saat ini.

Body:

```json
{
  "rfid_uid": "RFID_BUDI_123",
  "plat_nomor_ml": "G 1234 AB",
  "gate_type": "masuk"
}
```

Field:

| Field | Type | Required | Keterangan |
|---|---|---|---|
| `rfid_uid` | string | yes | UID RFID yang dibaca alat |
| `plat_nomor_ml` | string | yes | Plat nomor hasil scan kamera/ML |
| `gate_type` | string | yes | `masuk` atau `keluar` |

Curl:

```bash
curl -X POST "$BASE_URL/api/gate/scan" \
  -H "Content-Type: application/json" \
  -d '{
    "rfid_uid": "RFID_BUDI_123",
    "plat_nomor_ml": "G 1234 AB",
    "gate_type": "masuk"
  }'
```

Response sukses:

```json
{
  "action": "open_gate",
  "message": "Access granted"
}
```

Response RFID tidak ditemukan:

```json
{
  "action": "keep_closed",
  "message": "RFID not found"
}
```

Response plat tidak cocok atau kendaraan belum disetujui:

```json
{
  "action": "keep_closed",
  "message": "Vehicle not approved or mismatch"
}
```

Alur validasi legacy:

1. Backend mencari `rfid_uid` pada `users.rfid_uid`.
2. Backend mengambil user pemilik RFID.
3. Backend mengecek apakah user punya kendaraan dengan `plat_nomor` yang sama dan `status_validasi = disetujui`.
4. Jika valid, backend membuat `ParkingLog` dengan `status_akses = otomatis`.
5. Backend broadcast event ke WebSocket `/api/gate/monitor/live`.

### GET `/api/gate/stats/capacity`

Menghitung kapasitas parkir sederhana.

Rumus:

```text
parked = total log masuk - total log keluar
available = total_capacity - parked
```

Curl:

```bash
curl "$BASE_URL/api/gate/stats/capacity"
```

Response:

```json
{
  "total": 100,
  "parked": 1,
  "available": 99
}
```

### POST `/api/gate/emergency-action`

Manual override buka gerbang oleh petugas.

Auth: role `petugas` atau `admin`.

Query parameter:

| Field | Nilai |
|---|---|
| `gate` | `masuk` atau `keluar` |
| `reason` | alasan emergency |

Curl:

```bash
curl -X POST "$BASE_URL/api/gate/emergency-action?gate=masuk&reason=Darurat" \
  -H "Authorization: Bearer $PETUGAS_TOKEN"
```

Response:

```json
{
  "status": "success",
  "message": "Gate masuk dibuka manual"
}
```

Catatan: kode saat ini membuat `ParkingLog` emergency dengan `vehicle_id = 1`, jadi pastikan data kendaraan ID 1 ada agar tidak bermasalah pada database dengan foreign key ketat.

## WebSocket

Gunakan `ws://` untuk HTTP dan `wss://` untuk HTTPS.

### WS `/api/gate/monitor/live`

Channel live monitor petugas. Backend mengirim event dari scan IoT, emergency action, dan broadcast announcement.

URL contoh:

```text
ws://43.133.155.101:8088/api/gate/monitor/live
```

Ping:

```text
client -> ping
server -> pong
```

Event contoh sukses scan:

```json
{
  "type": "success",
  "message": "Akses masuk diizinkan otomatis.",
  "user": "Budi Santoso",
  "plate": "G 1234 AB",
  "time": "2026-05-06T14:20:00+00:00"
}
```

Event contoh error scan:

```json
{
  "type": "error",
  "message": "Unregistered RFID card scanned.",
  "rfid": "RFID_TIDAK_ADA",
  "plate": "G 1234 AB"
}
```

### WS `/api/gate/petugas/notifications`

Channel notifikasi request akses manual dari mahasiswa ke petugas.

URL contoh:

```text
ws://43.133.155.101:8088/api/gate/petugas/notifications
```

Event contoh:

```json
{
  "type": "new_access_request",
  "user_nama": "Budi Santoso",
  "user_nim": "11223344",
  "vehicle_plat": "G 1234 AB",
  "vehicle_jenis": "Motor",
  "jenis_aktivitas": "masuk",
  "request_id": 1
}
```

## Collection Curl Test Hit IoT Vehicles

Set base URL:

```bash
BASE_URL="http://43.133.155.101:8088"
```

Seed database jika kosong:

```bash
docker exec -it backend-backend-1 python seed.py
```

Ambil token petugas:

```bash
PETUGAS_TOKEN=$(curl -s -X POST "$BASE_URL/api/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=petugas123&password=petugaspassword" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
```

Pastikan RFID dummy sudah ada di data mahasiswa lewat seed atau input manual admin sebelum menjalankan test gate.

Test 1 - ML service kirim hasil OCR plat:

```bash
curl -X POST "$BASE_URL/api/gate/ml/plate-detect" \
  -H "Content-Type: application/json" \
  -d '{
    "gate_id": "GATE_MASUK_1",
    "detected_plate": "G 1234 AB",
    "confidence": 0.94,
    "image_path": "/uploads/ml/test-gate-masuk-1.jpg"
  }'
```

Test 2 - IoT vehicle validasi masuk:

```bash
curl -X POST "$BASE_URL/api/gate/dual-validate" \
  -H "Content-Type: application/json" \
  -d '{
    "rfid_uid": "RFID_BUDI_123",
    "detected_plate": "G 1234 AB",
    "ml_confidence": 0.94,
    "gate_type": "masuk",
    "gate_id": "GATE_MASUK_1"
  }'
```

Expected sukses:

```json
{
  "action": "open_gate",
  "message": "Akses masuk diizinkan",
  "student_name": "Budi Santoso",
  "plate_number": "G 1234 AB"
}
```

Test 3 - IoT vehicle validasi keluar:

```bash
curl -X POST "$BASE_URL/api/gate/dual-validate" \
  -H "Content-Type: application/json" \
  -d '{
    "rfid_uid": "RFID_BUDI_123",
    "detected_plate": "G 1234 AB",
    "ml_confidence": 0.94,
    "gate_type": "keluar",
    "gate_id": "GATE_KELUAR_1"
  }'
```

Test 4 - Plat tidak cocok:

```bash
curl -X POST "$BASE_URL/api/gate/dual-validate" \
  -H "Content-Type: application/json" \
  -d '{
    "rfid_uid": "RFID_BUDI_123",
    "detected_plate": "G 9999 XX",
    "ml_confidence": 0.94,
    "gate_type": "masuk",
    "gate_id": "GATE_MASUK_1"
  }'
```

Expected ditolak:

```json
{
  "action": "keep_closed",
  "message": "Plat nomor tidak cocok dengan data terdaftar"
}
```

Test 5 - RFID tidak dikenal:

```bash
curl -X POST "$BASE_URL/api/gate/dual-validate" \
  -H "Content-Type: application/json" \
  -d '{
    "rfid_uid": "RFID_TIDAK_ADA",
    "detected_plate": "G 1234 AB",
    "ml_confidence": 0.94,
    "gate_type": "masuk",
    "gate_id": "GATE_MASUK_1"
  }'
```

Expected ditolak:

```json
{
  "action": "keep_closed",
  "message": "RFID tidak terdaftar"
}
```

Test 6 - Confidence ML terlalu rendah:

```bash
curl -X POST "$BASE_URL/api/gate/dual-validate" \
  -H "Content-Type: application/json" \
  -d '{
    "rfid_uid": "RFID_BUDI_123",
    "detected_plate": "G 1234 AB",
    "ml_confidence": 0.45,
    "gate_type": "masuk",
    "gate_id": "GATE_MASUK_1"
  }'
```

Expected ditolak:

```json
{
  "action": "keep_closed",
  "message": "Confidence ML terlalu rendah: 45%"
}
```

Test 7 - Legacy scan masuk:

```bash
curl -X POST "$BASE_URL/api/gate/scan" \
  -H "Content-Type: application/json" \
  -d '{
    "rfid_uid": "RFID_BUDI_123",
    "plat_nomor_ml": "G 1234 AB",
    "gate_type": "masuk"
  }'
```

Test 8 - Legacy scan keluar:

```bash
curl -X POST "$BASE_URL/api/gate/scan" \
  -H "Content-Type: application/json" \
  -d '{
    "rfid_uid": "RFID_BUDI_123",
    "plat_nomor_ml": "G 1234 AB",
    "gate_type": "keluar"
  }'
```

Catatan duplikasi: `/api/gate/dual-validate` menolak `masuk` dua kali berturut-turut sebelum ada `keluar`. Jika test masuk mengembalikan pesan `Mahasiswa sudah tercatat di dalam area parkir`, jalankan curl `keluar` dulu lalu ulangi test `masuk`.

Cek kapasitas:

```bash
curl "$BASE_URL/api/gate/stats/capacity"
```

One-liner cepat dari IoT/gateway device:

```bash
curl -s -X POST "$BASE_URL/api/gate/dual-validate" -H "Content-Type: application/json" -d '{"rfid_uid":"RFID_BUDI_123","detected_plate":"G 1234 AB","ml_confidence":0.94,"gate_type":"masuk","gate_id":"GATE_MASUK_1"}'
```

## Status Code Umum

| Status | Arti |
|---|---|
| `200` | Berhasil |
| `400` | Request tidak valid, data duplikat, atau aksi tidak sesuai |
| `401` | Token tidak ada atau tidak valid |
| `403` | Role tidak punya akses |
| `404` | Data tidak ditemukan |
| `422` | Body/query tidak sesuai schema |

## Catatan Produksi

- Ganti `SECRET_KEY` dengan string random panjang.
- Jangan expose MySQL ke publik.
- Endpoint IoT `/api/gate/scan` sebaiknya ditambah API key atau signature sebelum dipakai di produksi.
- Jika memakai domain, letakkan backend di belakang Nginx dan HTTPS.
- Untuk WebSocket di belakang Nginx, pastikan header `Upgrade` dan `Connection` dikonfigurasi.
