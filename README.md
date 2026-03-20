# URL Tracker Pro

Rút gọn URL và theo dõi analytics real-time. 

## Tech Stack

| Layer | Technology |
|-------|------------|
| Web Server / Backend | OpenResty (nginx + Lua) |
| Frontend | Astro JS + Tailwind CSS |
| Database | JSON flat-file |
| Real-time | Server-Sent Events (SSE) |
| Geo-IP | IP2Location Lite CSV |
| Public tunnel | ngrok |

## Tính Năng

- Rút gọn URL với alias tùy chỉnh
- Analytics dashboard: clicks, unique IPs, quốc gia, thiết bị, referer
- Biểu đồ clicks theo 24 giờ
- Live Feed trạng thái real-time qua SSE
- Export CSV toàn bộ dữ liệu click
- Geo-IP nhận diện quốc gia người truy cập

Deploy public: mở terminal mới → `ngrok http 8080`
