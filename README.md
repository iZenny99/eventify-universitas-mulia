# Eventify - Universitas Mulia

Eventify adalah sistem manajemen acara (Event Management System) terintegrasi yang dirancang khusus untuk lingkungan Universitas Mulia. Proyek ini terdiri dari dua komponen utama: Aplikasi Mobile untuk pengguna akhir (mahasiswa/peserta) dan Web Admin Dashboard untuk pengelola (administrator/panitia acara). 

Dibangun menggunakan **Flutter** untuk ekosistem multi-platform dan **Supabase** sebagai layanan *backend-as-a-service* (BaaS), Eventify menawarkan skalabilitas, kecepatan, dan pengalaman pengguna yang responsif.

---

## 🚀 Fitur Utama

### 1. Aplikasi Mobile (Peserta)
Aplikasi mobile dirancang untuk memberikan pengalaman yang mulus bagi pengguna dalam mencari dan mengikuti berbagai acara di Universitas Mulia.

*   **Autentikasi (Auth):** Sistem login dan registrasi terintegrasi.
*   **Eksplorasi Acara (Events):** Pencarian dan informasi detail mengenai acara-acara kampus (seminar, workshop, kompetisi).
*   **Pendaftaran & Manajemen Tiket:** Proses pendaftaran acara yang cepat dan terdokumentasi.
*   **Sistem Presensi (Attendance):** Presensi modern menggunakan teknologi pemindaian kode QR (*QR Code Scanner*).
*   **Sertifikat Digital (Certificates):** Distribusi e-sertifikat otomatis pasca-acara yang dapat langsung diunduh oleh peserta.
*   **Profil Pengguna (Profile):** Manajemen data diri dan riwayat acara yang diikuti.

### 2. Web Admin Dashboard (Pengelola)
Web admin (`/admin_web`) adalah pusat kendali bagi administrator dan panitia untuk mengelola seluruh ekosistem acara secara menyeluruh.

*   **Dashboard & Analitik:** Visualisasi data interaktif untuk memantau metrik acara, jumlah pendaftar, dan tingkat partisipasi secara *real-time*.
*   **Manajemen Acara (Event Management):** Pembuatan acara baru, pengeditan detail informasi, penjadwalan, dan pengelolaan kapasitas peserta.
*   **Manajemen Kategori (Category Management):** Pengaturan kategori acara untuk memudahkan klasifikasi dan pencarian bagi peserta.
*   **Manajemen Pengguna (User Management):** Pengelolaan akun pengguna, memantau pendaftar, dan manajemen akses admin.

---

## 🛠️ Teknologi yang Digunakan

*   **Frontend Mobile & Web:** [Flutter](https://flutter.dev/) (SDK ^3.9.2)
*   **Backend & Database:** [Supabase](https://supabase.com/) (Autentikasi, PostgreSQL Database, Storage)
*   **Dependensi Utama:**
    *   `supabase_flutter` - Integrasi penuh dengan layanan Supabase.
    *   `fl_chart` - Rendering grafik dan visualisasi data pada admin dashboard.
    *   `mobile_scanner` & `qr_flutter` - Modul utama untuk fitur tiket dan pemindaian presensi QR.
    *   `google_fonts` - Penyesuaian tipografi antarmuka.

---

## ⚙️ Persiapan & Instalasi (Getting Started)

Pastikan Flutter SDK dan dependensi terkait telah terpasang pada perangkat pengembangan Anda.

### Prasyarat
- Flutter SDK (Versi yang disarankan: ^3.9.2)
- Akses kredensial Supabase (Project URL & Anon Key)

### Konfigurasi Variabel Lingkungan (.env)
Salin file `.env.example` menjadi `.env`. Anda dapat melakukannya melalui terminal dengan perintah:

```bash
cp .env.example .env
```

Setelah disalin, buka file `.env` tersebut dan sesuaikan nilainya dengan kredensial dari *project* Supabase Anda.

### Untuk menjalankan ikuti langkah berikut:

**Aplikasi Mobile (Utama)**
1. Klon repositori ini ke dalam direktori lokal Anda.
2. Unduh dan pasang seluruh dependensi dengan menjalankan:
   ```bash
   flutter pub get
   ```
3. Jalankan aplikasi pada perangkat atau emulator:
   ```bash
   flutter run
   ```

**Web Admin Dashboard**
1. Pindah ke direktori web admin:
   ```bash
   cd admin_web
   ```
2. Unduh dan pasang dependensi:
   ```bash
   flutter pub get
   ```
3. Jalankan server pengembangan untuk web:
   ```bash
   flutter run -d chrome
   ```

---

## 📚 Referensi Ekstra

Bagi pengembang yang baru memulai proyek Flutter, beberapa sumber daya berikut dapat menjadi acuan:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)
- [Flutter Online Documentation](https://docs.flutter.dev/)
