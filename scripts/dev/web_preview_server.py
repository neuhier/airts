#!/usr/bin/env python3
"""Serve the exported game without allowing browsers to cache old builds."""

from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import sys


class PreviewRequestHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, max-age=0")
        super().end_headers()


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", int(sys.argv[1])), PreviewRequestHandler).serve_forever()
