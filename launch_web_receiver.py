"""
Quick launcher for the iPhone AirGap Web App.
Hosts the web receiver on local LAN and displays a QR code for instant opening in iPhone Safari.
"""

import http.server
import socketserver
import socket
import os
import qrcode

PORT = 8090
DIRECTORY = os.path.dirname(os.path.abspath(__file__))

def get_lan_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    except Exception:
        return "127.0.0.1"
    finally:
        s.close()

class CustomHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def do_GET(self):
        if self.path == "/" or self.path == "":
            self.path = "/airgap_receiver_web.html"
        return super().do_GET()

def main():
    ip = get_lan_ip()
    url = f"http://{ip}:{PORT}"
    
    print("=" * 60)
    print("  مستقبل الآيفون البصري المباشر (Direct Web Receiver)")
    print("=" * 60)
    print(f"\n[+] الرابط المباشر: {url}")
    print("\nامسح الرمز أدناه بكاميرا هاتف الآيفون لفتح التطبيق فوراً:\n")

    # Generate ASCII QR in terminal
    qr = qrcode.QRCode(border=1)
    qr.add_data(url)
    qr.make(fit=True)
    qr.print_ascii(invert=True)

    print("\n[نصيحة في الآيفون]: بعد فتح الرابط في متصفح سفاري، اضغط على زر المشاركة")
    print("ثم اختر 'إضافة إلى الشاشة الرئيسية' (Add to Home Screen) ليصبح تطبيقاً دائماً على هاتفك!")
    print("\nالخادم نشط الآن... اضغط Ctrl+C للإيقاف.")

    with socketserver.TCPServer(("", PORT), CustomHandler) as httpd:
        httpd.serve_forever()

if __name__ == "__main__":
    main()
