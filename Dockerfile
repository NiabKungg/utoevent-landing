# ── UTO Event — Landing Page ─────────────────────────────
# เว็บไซต์ static (HTML/CSS/JS, 3 ภาษา TH/EN/JP) เสิร์ฟด้วย nginx
# build: docker build -t utoevent-landing .
FROM nginx:1.27-alpine

# config: gzip, cache policy, security headers, /healthz
COPY nginx.conf /etc/nginx/conf.d/default.conf

# เนื้อหาเว็บ (ไฟล์ build system ถูกแยกออกด้วย .dockerignore)
COPY . /usr/share/nginx/html

EXPOSE 80

# ตรวจสุขภาพ container ทุก 30 วินาที (load balancer / compose ใช้ด้วย)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1/healthz >/dev/null 2>&1 || exit 1
