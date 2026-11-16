#!/usr/bin/env python3
"""Servidor local para o build web do Nutria.

Além de servir `build/web`, envia os headers de isolamento de origem
(COOP/COEP) que habilitam SharedArrayBuffer/OPFS — deixando o SQLite
WASM do Drift mais rápido e persistente no navegador.

Uso:
  python3 tool/serve_web.py [PORTA] [--host HOST]

Por padrão escuta apenas em localhost (127.0.0.1). Use --host 0.0.0.0
apenas em redes confiáveis.
"""

import argparse
import http.server
import mimetypes
import os
import socketserver
import sys
import threading

mimetypes.add_type("application/wasm", ".wasm")
mimetypes.add_type("text/javascript", ".js")
mimetypes.add_type("application/json", ".json")
mimetypes.add_type("application/manifest+json", ".webmanifest")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Servidor web do Nutria")
    parser.add_argument("port", nargs="?", type=int, default=8080, help="Porta (padrão: 8080)")
    parser.add_argument(
        "--host", default="127.0.0.1", help="Interface (padrão: 127.0.0.1)"
    )
    return parser.parse_args()


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        # Não usa o parâmetro directory (que causa bug no Python 3.12);
        # em vez disso, fazemos a tradução de caminho manualmente.
        super().__init__(*args, **kwargs)

    def translate_path(self, path):
        # Resolve o caminho relativo ao ROOT.
        path = path.split('?', 1)[0].split('#', 1)[0]
        path = path.lstrip('/')
        if not path:
            path = 'index.html'
        full = os.path.join(ROOT, path)
        # Previne traversal de diretório.
        if not os.path.normpath(full).startswith(os.path.normpath(ROOT) + os.sep) and full != ROOT:
            return os.path.join(ROOT, 'index.html')
        return full

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "cross-origin")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def list_directory(self, path):
        # Desabilita listagem de diretórios.
        self.send_error(404, "Not found")
        return None

    def log_message(self, fmt, *args):
        pass


class ThreadingTCPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    allow_reuse_address = True
    daemon_threads = True


def main() -> None:
    args = parse_args()

    global ROOT
    ROOT = os.path.normpath(
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "web")
    )

    with ThreadingTCPServer((args.host, args.port), Handler) as httpd:
        host_display = "localhost" if args.host in ("127.0.0.1", "localhost") else args.host
        print(
            f"Nutria web em http://{host_display}:{args.port}  (raiz: {ROOT})",
            flush=True,
        )
        httpd.serve_forever()


if __name__ == "__main__":
    main()
