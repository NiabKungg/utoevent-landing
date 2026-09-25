# UTO Event — Landing Page (Docker)

**Rei Kamiki 1st Fan Meeting in Bangkok · 10–11 ตุลาคม 2026**

- 🌐 เว็บ live (GitHub Pages): <https://niabkungg.github.io/utoevent-landing/>
- เว็บไซต์ static ล้วน (HTML/CSS/JS) — ไม่มี build step, รองรับ 3 ภาษา TH/EN/JP
- ปุ่มซื้อบัตรทุกจุดเชื่อมไปหน้าบัตรจริงบน [Ticketmelon](https://www.ticketmelon.com/th/uto/kamiki)

---

## โครงสร้างไฟล์

```
├── index.html           หน้าเว็บทั้งหมด (โครงสร้าง + สี + คำแปล 3 ภาษาในไฟล์เดียว)
├── assets/              รูปภาพ webp/png (hero, โลโก้)
├── nginx.conf           config ของ nginx ใน container — gzip, cache policy, security headers, /healthz
├── Dockerfile           image มาตรฐาน (nginx:1.27-alpine, มี HEALTHCHECK ในตัว)
├── docker-compose.yml   รันคำสั่งเดียว + healthcheck + restart อัตโนมัติ
└── .dockerignore        แยกไฟล์ build system ออกจาก image
```

## ความต้องการ

- Docker Engine 24+ และ Docker Compose v2 (ตรวจด้วย `docker compose version`)
- พอร์ตว่าง 1 พอร์ต (ค่าเริ่มต้นใช้ **8080** — เปลี่ยนได้)

---

## รันในเครื่อง (Local)

### วิธีที่ 1 — Docker Compose (แนะนำ)

```bash
docker compose up -d --build
```

เปิดเบราว์เซอร์ไปที่ **http://localhost:8080**

```bash
docker compose logs -f     # ดู log แบบเรียลไทม์
docker compose down        # หยุดและลบ container
```

### วิธีที่ 2 — docker build / run ตรง ๆ

```bash
docker build -t utoevent-landing .
docker run -d --name utoevent-landing -p 8080:80 --restart unless-stopped utoevent-landing
```

- เปลี่ยนพอร์ต: เปลี่ยนเลขหน้าของ `-p` เช่น `-p 3000:80`
- หยุด/ลบ: `docker rm -f utoevent-landing`

### ตรวจว่ารันสำเร็จ

```bash
curl -f http://localhost:8080/healthz       # ต้องตอบกลับ "ok"
docker ps --filter name=utoevent-landing    # STATUS ต้องขึ้น (healthy)
```

---

## Deploy บน VPS (Ubuntu 22.04 / 24.04)

### 1) ติดตั้ง Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER    # ออกจาก session แล้ว login ใหม่ เพื่อใช้ docker ไม่ต้อง sudo
```

### 2) นำโค้ดขึ้นเครื่อง

```bash
git clone https://github.com/NiabKungg/utoevent-landing.git
cd utoevent-landing
```

### 3) รัน container

```bash
docker compose up -d --build
```

### 4) เปิด firewall

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

ทดสอบ: `curl http://IP_ของ_VPS:8080/healthz` ต้องได้ `ok`

### 5) ต่อโดเมน + SSL

ชี้ DNS โดเมน (เช่น `utoevent.com` หรือ `www.utoevent.com`) มาที่ IP ของ VPS แล้วตั้ง reverse proxy:

**ตัวอย่าง nginx reverse proxy บนเครื่อง host** (ไฟล์ใน `/etc/nginx/sites-available/utoevent`):

```nginx
server {
    listen 80;
    server_name utoevent.com;
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

ติดตั้งใบรับรอง SSL ฟรี:

```bash
sudo ln -s /etc/nginx/sites-available/utoevent /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d utoevent.com    # ต่ออายุเองอัตโนมัติ
```

> ทางเลือกที่ง่ายกว่า: ใช้ **Caddy** (`utoevent.com { reverse_proxy 127.0.0.1:8080 }`) หรือเปิด Cloudflare proxy แล้วใช้ SSL ฝั่ง Cloudflare

### 6) อัปเดตเวอร์ชันใหม่เมื่อแก้โค้ด

```bash
cd utoevent-landing
git pull
docker compose up -d --build
```

downtime ประมาณ 1–2 วินาทีตอนสลับ container

---

## Deploy ขึ้น Cloud (ทางเลือก)

### Google Cloud Run (auto-scale เหมาะกับช่วงเปิดขายบัตร)

```bash
gcloud builds submit --tag asia-southeast1-docker.pkg.dev/PROJECT_ID/uto/landing:latest
gcloud run deploy utoevent-landing \
  --image asia-southeast1-docker.pkg.dev/PROJECT_ID/uto/landing:latest \
  --region asia-southeast1 --allow-unauthenticated
```

### ผลัก image ไป GitHub Container Registry (GHCR)

```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u NiabKungg --password-stdin
docker tag utoevent-landing ghcr.io/niabkungg/utoevent-landing:latest
docker push ghcr.io/niabkungg/utoevent-landing:latest
```

---

## GitHub Pages (ช่องทางที่ใช้ live อยู่ตอนนี้)

repo นี้เปิด GitHub Pages ไว้แล้ว — **push ไป branch `main` แล้วเว็บอัปเดตเองใน ~1 นาที** ที่
<https://niabkungg.github.io/utoevent-landing/>

ช่องทางนี้ไม่ต้องใช้ Docker (Pages serve ไฟล์ static โดยตรง) — Docker มีไว้สำหรับ deploy บน server ของเราเอง/รัน local

---

## เรื่องแคชที่ควรรู้

| ไฟล์ | นโยบายแคช |
|---|---|
| `index.html` | ไม่แคช — ผู้ใช้ได้เนื้อหาใหม่ทันทีที่ deploy |
| `assets/*` (รูป) | แคช 7 วัน |

> ⚠️ ถ้าเปลี่ยนรูปโดยใช้**ชื่อไฟล์เดิม** ผู้ใช้ที่เคยเข้าแล้วอาจเห็นรูปเก่าค้างจนครบ 7 วัน → วิธีที่ถูกต้องคือ**เปลี่ยนชื่อไฟล์** (เช่น `kamiki-rei-hero-v2.webp`) แล้วแก้ path ใน `index.html` ด้วย

---

## Troubleshooting

| อาการ | สาเหตุ/วิธีแก้ |
|---|---|
| `bind: address already in use` | พอร์ตชน — เปลี่ยนเลขหน้าใน `ports` เช่น `"3000:80"` |
| แก้ไฟล์แล้วหน้าเว็บไม่เปลี่ยน | ต้อง `docker compose up -d --build` (ไฟล์ถูก COPY ตอน build ไม่ใช่ mount) |
| container สถานะ `unhealthy` | `docker logs utoevent-landing` ดู error / ทดสอบ `curl http://127.0.0.1:8080/healthz` |
| ผู้ใช้เห็นรูปเก่าหลังอัปเดต | แคช 7 วันของ assets — เปลี่ยนชื่อไฟล์รูป + แก้ path ใน `index.html` |
| จอมือถือ/ภาษาอื่นแสดงผิด | เปิด DevTools → hard refresh (Ctrl+Shift+R) เพื่อเคลียร์ cache ฝั่งเบราว์เซอร์ |

---

**ขนาด image:** ~74 MB (nginx:1.27-alpine + เนื้อหาเว็บ)

**เวอร์ชัน:** v1.0 · 26 กันยายน 2026
