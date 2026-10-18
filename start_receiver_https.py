"""
AirGap iOS Receiver Launcher with Cloudflare HTTPS Tunnel.
Provides an instant secure HTTPS URL for iPhone Safari camera access.
"""

import sys
import os
import re
import time
import subprocess
import threading
import http.server
import socketserver
import qrcode
from io import BytesIO

from PySide6.QtWidgets import QApplication, QMainWindow, QLabel, QVBoxLayout, QWidget, QPushButton, QHBoxLayout
from PySide6.QtGui import QPixmap, QImage, QFont
from PySide6.QtCore import Qt, QTimer

PORT = 8090
HTML_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "airgap_receiver_web.html")

class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        with open(HTML_FILE, "rb") as f:
            self.wfile.write(f.read())

def run_server():
    with socketserver.TCPServer(("127.0.0.1", PORT), Handler) as httpd:
        httpd.serve_forever()

class LauncherWindow(QMainWindow):
    def __init__(self, tunnel_url: str):
        super().__init__()
        self.tunnel_url = tunnel_url
        self.setWindowTitle("تثبيت وتشغيل مستقبل الآيفون | AirGap iOS Launcher")
        self.resize(520, 680)
        self.setStyleSheet("background-color: #0f172a; color: white;")

        central = QWidget()
        self.setCentralWidget(central)
        layout = QVBoxLayout(central)
        layout.setContentsMargins(30, 24, 30, 24)
        layout.setSpacing(16)

        # Title
        title = QLabel("🛡️ مستقبل الآيفون فائق الأمان")
        title.setFont(QFont("Segoe UI", 16, QFont.Weight.Bold))
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        title.setStyleSheet("color: #38bdf8;")
        layout.addWidget(title)

        subtitle = QLabel("امسح الرمز أدناه بكاميرا هاتف الآيفون لفتح التطبيق فوراً:")
        subtitle.setFont(QFont("Segoe UI", 12))
        subtitle.setAlignment(Qt.AlignmentFlag.AlignCenter)
        subtitle.setStyleSheet("color: #cbd5e1;")
        layout.addWidget(subtitle)

        # QR Code Display
        qr = qrcode.QRCode(box_size=8, border=2)
        qr.add_data(self.tunnel_url)
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")

        buffer = BytesIO()
        img.save(buffer, format="PNG")
        qimg = QImage.fromData(buffer.getvalue())
        pixmap = QPixmap.fromImage(qimg)

        qr_label = QLabel()
        qr_label.setPixmap(pixmap.scaled(320, 320, Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation))
        qr_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        qr_label.setStyleSheet("background: white; border-radius: 16px; padding: 12px;")
        layout.addWidget(qr_label, alignment=Qt.AlignmentFlag.AlignCenter)

        # Instructions Box
        info = QLabel(
            "📱 <b>خطوات التثبيت والاستخدام:</b><br>"
            "1. افتح كاميرا الآيفون ووجّهها نحو الرمز أعلاه.<br>"
            "2. اضغط على الرابط ليفتح التطبيق في متصفح Safari.<br>"
            "3. اضغط زر المشاركة (Share) ثم <b>'إضافة إلى الشاشة الرئيسية'</b> ليصبح تطبيقاً دائماً على هاتفك!<br>"
            "4. اسمح بإذن الكاميرا ووجّه الآيفون نحو شاشة الحاسوب الثاني لاستلام الداتابيس."
        )
        info.setFont(QFont("Segoe UI", 11))
        info.setStyleSheet("background: #1e293b; border-radius: 12px; padding: 14px; border: 1px solid #334155; line-height: 1.5;")
        info.setTextFormat(Qt.TextFormat.RichText)
        layout.addWidget(info)

        # Link button
        link_label = QLabel(f"رابط مباشر (HTTPS): <a style='color:#38bdf8;' href='{self.tunnel_url}'>{self.tunnel_url}</a>")
        link_label.setOpenExternalLinks(True)
        link_label.setFont(QFont("Segoe UI", 10))
        link_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(link_label)

def main():
    # 1. Start local HTTP server in background thread
    server_thread = threading.Thread(target=run_server, daemon=True)
    server_thread.start()

    # 2. Start Cloudflare Tunnel
    cmd = ["cloudflared", "tunnel", "--url", f"http://127.0.0.1:{PORT}"]
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

    tunnel_url = None
    start_time = time.time()
    while time.time() - start_time < 20:
        line = proc.stdout.readline()
        if not line:
            continue
        match = re.search(r"https://[a-zA-Z0-9-]+\.trycloudflare\.com", line)
        if match:
            tunnel_url = match.group(0)
            break

    if not tunnel_url:
        print("خطأ: تعذر الحصول على رابط النفق من Cloudflare.")
        sys.exit(1)

    print(f"\n[+] الرابط المباشر الآمن: {tunnel_url}\n")

    # 3. Launch UI Window
    app = QApplication(sys.argv)
    window = LauncherWindow(tunnel_url)
    window.show()

    ret = app.exec()
    proc.terminate()
    sys.exit(ret)

if __name__ == "__main__":
    main()
