"""
Unified Local Server for NutriViet Backend WSGI & FoodOn + Kala Hybrid Engine
=============================================================================
Serves all REST APIs (`/api/v1/*`) and the Bilingual Test UI (`/foodon-test`).
"""

import os
import sys
import time
import threading
import subprocess
from socketserver import ThreadingMixIn
from wsgiref.simple_server import WSGIServer, WSGIRequestHandler, make_server

sys.path.insert(0, os.path.dirname(__file__))
import wsgi_app

HOST = os.environ.get("FOODON_UI_HOST", "0.0.0.0")
PORT = int(os.environ.get("FOODON_UI_PORT", 8050))
ADB_EXE = r"C:\platform-tools\adb.exe"


def _setup_adb_reverse_once():
    """Sets up `adb reverse tcp:8050 tcp:8050` once on startup for connected Android devices."""
    if not os.path.exists(ADB_EXE):
        return
    try:
        subprocess.run(
            [ADB_EXE, "reverse", f"tcp:{PORT}", f"tcp:{PORT}"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=6,
        )
    except Exception:
        pass


class ThreadingWSGIServer(ThreadingMixIn, WSGIServer):
    daemon_threads = True
    allow_reuse_address = True
    request_queue_size = 64


class QuietWSGIHandler(WSGIRequestHandler):
    def log_message(self, format, *args):
        pass


def app_with_root_redirect(environ, start_response):
    path = environ.get("PATH_INFO", "/")
    if path in ("/", "/index.html"):
        environ["PATH_INFO"] = "/foodon-test"
    return wsgi_app.application(environ, start_response)


def main():
    t = threading.Thread(target=_setup_adb_reverse_once, daemon=True)
    t.start()
    with make_server(
        HOST,
        PORT,
        app_with_root_redirect,
        server_class=ThreadingWSGIServer,
        handler_class=QuietWSGIHandler,
    ) as httpd:
        print(f"NutriViet Full Backend + FoodOn Hybrid Server running at: http://0.0.0.0:{PORT}/foodon-test", flush=True)
        httpd.serve_forever()


if __name__ == "__main__":
    main()
