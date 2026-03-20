# 📖 Hướng Dẫn Cài Đặt & Deploy Ngrok — URL Tracker Pro

> Tài liệu này hướng dẫn **chi tiết từng bước** cách cài đặt môi trường trên **Windows**, chạy project, và deploy lên **ngrok** để chia sẻ qua internet.

---

## 📋 Mục Lục

1. [Tổng quan kiến trúc](#1-tổng-quan-kiến-trúc)
2. [Cài đặt môi trường Windows](#2-cài-đặt-môi-trường-windows)
   - 2.1 Cài Node.js
   - 2.2 Cài OpenResty
   - 2.3 Cài ngrok
3. [Chuẩn bị project](#3-chuẩn-bị-project)
4. [Chạy project](#4-chạy-project)
5. [Deploy lên ngrok](#5-deploy-lên-ngrok)
6. [Sử dụng hệ thống](#6-sử-dụng-hệ-thống)
7. [Dừng hệ thống](#7-dừng-hệ-thống)
8. [Xử lý lỗi thường gặp](#8-xử-lý-lỗi-thường-gặp)

---

## 1. Tổng Quan Kiến Trúc

Hệ thống chỉ cần **1 port duy nhất (8080)** → **1 tunnel ngrok duy nhất**:

```
Internet
   │
   ▼
ngrok tunnel (https://abc123.ngrok-free.app)
   │
   ▼
OpenResty (localhost:8080)
   ├── /api/*          → Lua handlers (backend logic)
   ├── /:code          → Lua redirect + tracking
   ├── /dashboard/*    → Static HTML (Astro build)
   ├── /preview/*      → Static HTML (Astro build)
   └── /               → Static HTML (Landing page)
```

**Không cần chạy Astro dev server khi deploy.** Frontend đã được build sẵn thành file HTML/CSS/JS tĩnh trong thư mục `astro-app/dist/`, OpenResty serve trực tiếp.

---

## 2. Cài Đặt Môi Trường Windows

### 2.1 Cài Node.js (Bắt buộc — chỉ cần nếu muốn rebuild frontend)

Node.js cần thiết để build lại frontend Astro nếu có chỉnh sửa source code.

```cmd
node -v
npm -v
```

Kết quả mong đợi:
```
v20.x.x
10.x.x
```

---

### 2.2 Cài OpenResty (Bắt buộc)

OpenResty là web server kiêm backend API.

#### Bước 1: Tải OpenResty for Windows

1. Truy cập: **https://openresty.org/en/download.html**
2. Kéo xuống phần **"Win32/Win64"**
3. Tải file `.zip` phiên bản mới nhất (ví dụ: `openresty-1.25.3.2-win64.zip`)

#### Bước 2: Giải nén

1. Giải nén vào thư mục dễ nhớ, ví dụ: `C:\openresty`
2. Bên trong sẽ có cấu trúc:
```
C:\openresty\
├── nginx.exe
├── conf\
├── html\
├── logs\
└── lualib\
```

#### Bước 3: Thêm vào PATH

1. Nhấn **Win + S**, tìm **"Environment Variables"**
2. Click **"Edit the system environment variables"**
3. Click **"Environment Variables..."**
4. Ở phần **"System variables"**, tìm **Path**, click **Edit**
5. Click **New**, thêm đường dẫn: `C:\openresty`
6. Nhấn **OK** 3 lần để lưu

#### Bước 4: Kiểm tra

Mở **CMD mới** (bắt buộc phải mở mới sau khi sửa PATH):

```cmd
nginx -v
```

Kết quả mong đợi:
```
nginx version: openresty/1.25.x.x
```

> **⚠️ Trên Windows, lệnh là `nginx` KHÔNG phải `openresty`.** Bản OpenResty for Windows đặt tên file là `nginx.exe`.

---

### 2.3 Cài ngrok (Bắt buộc cho deploy online)

ngrok tạo tunnel để expose localhost ra internet.

#### Bước 1: Tạo tài khoản (miễn phí)

1. Truy cập: **https://dashboard.ngrok.com/signup**
2. Đăng ký bằng Email hoặc Google/GitHub
3. Sau khi đăng nhập, vào: https://dashboard.ngrok.com/get-started/your-authtoken
4. Copy authtoken (dạng `2abc...xyz`)

#### Bước 2: Tải ngrok

1. Truy cập: **https://ngrok.com/download**
2. Tải bản **Windows (64-bit)**
3. Giải nén `ngrok.exe` vào thư mục, ví dụ: `C:\ngrok\`

#### Bước 3: Thêm vào PATH

Giống bước 2.2, thêm `C:\ngrok` vào PATH.

#### Bước 4: Cấu hình authtoken

```cmd
ngrok config add-authtoken 2abc...xyz
```

#### Bước 5: Kiểm tra

```cmd
ngrok version
```

Kết quả: `ngrok version 3.x.x`

---

## 3. Chuẩn Bị Project

### 3.1 Cấu trúc thư mục

```
URL-TRACKER\
├── nginx.conf          ← Cấu hình OpenResty
├── astro-app\          ← Frontend
│   ├── src\            ← Source code
│   ├── dist\         
│   └── package.json
├── lua\                ← Backend Lua handlers
│   ├── api\
│   │   ├── shorten.lua
│   │   ├── stats.lua
│   │   ├── stream.lua
│   │   ├── export.lua
│   │   └── links.lua
│   ├── common\
│   │   ├── storage.lua
│   │   ├── rate_limit.lua
│   │   └── geo.lua
│   └── redirect.lua
├── data\               ← Dữ liệu JSON (tự động tạo)
│   ├── links.json
│   └── clicks.json
└── logs\               ← Log files
```

### 3.3 (Tùy chọn) Tải Geo-IP Database

Nếu muốn nhận diện quốc gia của người truy cập:

1. Tải: https://download.ip2location.com/lite/IP2LOCATION-LITE-DB1.CSV.ZIP
2. Giải nén, copy file `IP2LOCATION-LITE-DB1.CSV` vào thư mục `data\`
3. Đổi tên thành `ip2location-lite.csv`

> Nếu không có file này, hệ thống vẫn chạy bình thường, chỉ là quốc gia sẽ hiện "??".

---

## 4. Chạy Project

Mở **PowerShell**, chạy theo đúng thứ tự trong **cùng 1 terminal**:

```powershell
# Bước 1: Di chuyển vào thư mục project
cd "D:\Project\URL-TRACKER"

# Bước 2: Set đường dẫn data (bắt buộc, phải cùng terminal)
$env:DATA_DIR = "D:\Project\URL-TRACKER\data"

# Bước 3: Khởi động OpenResty
nginx -p "D:\Project\URL-TRACKER\" -c nginx.conf
```

> **⚠️ Quan trọng:** `$env:DATA_DIR` chỉ tồn tại trong session PowerShell hiện tại. Nếu đóng terminal và mở lại, phải set lại biến này trước khi start nginx.

### Kiểm tra hoạt động

Mở trình duyệt, truy cập: **http://localhost:8080**

Bạn sẽ thấy trang chủ URL Tracker Pro với form rút gọn URL.

### (Tùy chọn) Rebuild Frontend

Chỉ cần làm nếu bạn chỉnh sửa source code trong `astro-app/src/`:

```powershell
cd "D:\Project\URL-TRACKER\astro-app"
npm install
npx astro build
cd ..
```

---

## 5. Deploy Lên ngrok

### Bước 1: Đảm bảo OpenResty đang chạy

Truy cập http://localhost:8080 phải hiện trang web.

### Bước 2: Mở terminal MỚI (giữ nguyên terminal nginx)

### Bước 3: Chạy ngrok

```cmd
ngrok http 8080
```

### Bước 4: Lấy URL public

```
Session Status                online
Forwarding                    https://a1b2c3d4.ngrok-free.app → http://localhost:8080
```

**URL public của bạn là:** `https://a1b2c3d4.ngrok-free.app`

### Bước 5: Chia sẻ

Gửi URL trên cho bất kỳ ai. Họ có thể truy cập trang chủ để tạo short link và xem dashboard analytics.

### ⚠️ Lưu ý ngrok Free

| Giới hạn | Chi tiết |
|----------|----------|
| **Domain ngẫu nhiên** | URL đổi mỗi lần restart ngrok |
| **Interstitial page** | Lần đầu truy cập hiện trang cảnh báo, nhấn "Visit Site" |
| **1 tunnel** | Chỉ 1 tunnel cùng lúc (đủ dùng vì chỉ cần 1 port) |
| **Session** | Có authtoken → session kéo dài ~8 giờ |

### Mẹo: Cố định domain ngrok

Với tài khoản free, có thể đăng ký 1 domain cố định:

1. Vào https://dashboard.ngrok.com/domains
2. Click **"New Domain"** → nhận domain dạng `your-name.ngrok-free.app`
3. Chạy với domain cố định:

```cmd
ngrok http 8080 --domain=your-name.ngrok-free.app
```

Lợi ích: URL không đổi khi restart, short link vẫn hoạt động.

---

## 6. Sử Dụng Hệ Thống

### 6.1 Tạo Short Link

1. Vào trang chủ (localhost:8080 hoặc URL ngrok)
2. Dán URL dài vào ô input
3. (Tùy chọn) Click **"+ Tùy chỉnh alias"** để đặt tên tùy ý
4. Click **"Rút gọn ngay →"**
5. Copy short link từ kết quả

### 6.2 Xem Analytics Dashboard

1. Sau khi tạo link, click nút **"Stats"**
2. Hoặc truy cập: `http://localhost:8080/dashboard/MÃ_CODE`
3. Dashboard hiển thị:
   - Tổng clicks, unique IPs, số quốc gia, thời gian tạo
   - Biểu đồ clicks theo 24 giờ
   - Trạng thái Live Feed (kết nối real-time)
   - Top quốc gia, thiết bị, referer

### 6.3 Preview Link

Truy cập: `http://localhost:8080/preview/MÃ_CODE`  
→ Hiện thông tin link trước khi redirect.

### 6.4 Export CSV

Trong dashboard, click **"Export CSV"** để tải file CSV chứa toàn bộ dữ liệu click.

---

## 7. Dừng Hệ Thống

### Dừng OpenResty

```powershell
cd "D:\Project\URL-TRACKER"
nginx -p "D:\Project\URL-TRACKER\" -c nginx.conf -s stop
```

> Nếu thấy lỗi `OpenEvent... failed (2)` — nginx đã tắt rồi, bỏ qua lỗi này.

### Dừng ngrok

Nhấn **Ctrl+C** trong terminal đang chạy ngrok.

---

## 🎯 Tóm Tắt Nhanh

```
┌─────────────────────────────────────────────────────────────────┐
│  1. Cài: OpenResty + ngrok                                      │
│  2. Mở PowerShell, cd vào thư mục project                       │
│  3. Set DATA_DIR: $env:DATA_DIR = "D:\Project\URL-TRACKER\data" │
│  4. Start: nginx -p "D:\Project\URL-TRACKER\" -c nginx.conf     │
│  5. Kiểm tra: http://localhost:8080                             │
│  6. Deploy: mở terminal mới → ngrok http 8080                   │
│  7. Chia sẻ: gửi URL https://xxx.ngrok-free.app                 │
│  8. Dừng: nginx ... -s stop + Ctrl+C ngrok                      │
│                                                                 │
│   $env:DATA_DIR phải set lại mỗi lần mở terminal mới            │
│   Windows dùng lệnh "nginx" KHÔNG PHẢI "openresty"              │
└─────────────────────────────────────────────────────────────────┘
```
