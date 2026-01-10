#!/usr/bin/env python3
"""
SIOP Training Hub - Simple Web Server
Serves the training modules and templates on your local network.
"""

import http.server
import socketserver
import os
import sys
import signal
import webbrowser
import gzip
import mimetypes
from pathlib import Path
from io import BytesIO

# Configuration
PORT = 3000
HOST = '0.0.0.0'  # Listen on all interfaces (accessible from network)
DIRECTORY = Path(__file__).parent

class CustomHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    """Custom request handler with better logging, compression, and caching."""
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(DIRECTORY), **kwargs)
        self._headers_sent_by_us = False
    
    def log_message(self, format, *args):
        """Custom log format with timestamp."""
        import datetime
        timestamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        print(f"[{timestamp}] {format % args}")
    
    def _should_compress(self, path):
        """Determine if a file should be compressed."""
        compressible_types = [
            'text/html', 'text/css', 'text/javascript', 'application/javascript',
            'application/json', 'text/xml', 'application/xml', 'text/plain'
        ]
        content_type, _ = mimetypes.guess_type(path)
        return content_type in compressible_types
    
    def _should_cache(self, path):
        """Determine if a file should be cached."""
        # Cache static assets, but not HTML files (so updates are visible)
        cacheable_extensions = ['.css', '.js', '.png', '.jpg', '.jpeg', '.gif', 
                               '.svg', '.woff', '.woff2', '.ttf', '.eot', '.ico']
        return any(path.lower().endswith(ext) for ext in cacheable_extensions)
    
    def _compress_content(self, content):
        """Compress content using gzip."""
        buf = BytesIO()
        with gzip.GzipFile(fileobj=buf, mode='wb', compresslevel=1) as gz:
            gz.write(content)
        return buf.getvalue()
    
    def end_headers(self):
        """Add appropriate headers based on file type."""
        if not self._headers_sent_by_us:
            path = self.path.split('?')[0]  # Remove query string
            
            # Set caching headers
            if self._should_cache(path):
                # Cache static assets for 1 hour
                self.send_header('Cache-Control', 'public, max-age=3600')
            else:
                # Cache HTML files for 60 seconds (fast page switching while allowing updates)
                self.send_header('Cache-Control', 'public, max-age=60')
            
            # Add CORS headers for local development
            self.send_header('Access-Control-Allow-Origin', '*')
        
        super().end_headers()
    
    def _send_compressed_response(self, content, content_type):
        """Send a compressed response if client supports it."""
        accept_encoding = self.headers.get('Accept-Encoding', '')
        
        if 'gzip' in accept_encoding and self._should_compress(self.path):
            compressed = self._compress_content(content)
            if len(compressed) < len(content):
                self._headers_sent_by_us = True
                self.send_response(200)
                self.send_header('Content-Type', content_type)
                self.send_header('Content-Encoding', 'gzip')
                self.send_header('Content-Length', str(len(compressed)))
                if self.protocol_version >= "HTTP/1.1":
                    self.send_header('Connection', 'keep-alive')
                self.end_headers()
                self.wfile.write(compressed)
                return True
        
        return False
    
    def do_GET(self):
        """Override GET to add compression support."""
        # Translate path and check if it exists
        path = self.translate_path(self.path)
        
        # Handle directory redirects
        if os.path.isdir(path):
            if not self.path.endswith('/'):
                self.send_response(301)
                self.send_header("Location", self.path + '/')
                self.end_headers()
                return
            # Look for index.html
            for index in "index.html", "index.htm":
                index_path = os.path.join(path, index)
                if os.path.exists(index_path):
                    path = index_path
                    break
            else:
                # Use parent's directory listing
                super().do_GET()
                return
        
        # Check if file exists
        if not os.path.isfile(path):
            self.send_error(404, "File not found")
            return
        
        try:
            # Read file content efficiently
            with open(path, 'rb') as f:
                content = f.read()
            
            # Get content type
            content_type = self.guess_type(path)
            if content_type is None:
                content_type = 'application/octet-stream'
            
            # Try to send compressed response
            if not self._send_compressed_response(content, content_type):
                # Fall back to uncompressed
                self._headers_sent_by_us = True
                self.send_response(200)
                self.send_header('Content-Type', content_type)
                self.send_header('Content-Length', str(len(content)))
                if self.protocol_version >= "HTTP/1.1":
                    self.send_header('Connection', 'keep-alive')
                self.end_headers()
                # Write content directly (faster than chunking for small files)
                self.wfile.write(content)
        except Exception as e:
            self.log_error(f"Error serving {self.path}: {e}")
            if not self.headers_sent:
                self.send_error(500, f"Internal server error: {e}")

class Server:
    def __init__(self, port=PORT, host=HOST):
        self.port = port
        self.host = host
        self.httpd = None
        self.running = False
        
    def start(self, open_browser=True):
        """Start the web server."""
        try:
            # Change to the script directory
            os.chdir(DIRECTORY)
            
            # Create server with address reuse to avoid TIME_WAIT issues
            # Use a custom server class to set socket options
            class ReusableTCPServer(socketserver.TCPServer):
                allow_reuse_address = True
                def server_bind(self):
                    """Override to set socket options for better port reuse."""
                    import socket
                    self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                    # Try to set SO_REUSEPORT if available (Linux 3.9+)
                    try:
                        self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
                    except (AttributeError, OSError):
                        pass  # SO_REUSEPORT not available on this system
                    super().server_bind()
            
            self.httpd = ReusableTCPServer((self.host, self.port), CustomHTTPRequestHandler)
            self.running = True
            
            # Get local IP addresses
            import socket
            local_ip = self._get_local_ip()
            
            print("\n" + "="*60)
            print("🚀 SIOP Training Hub Server Starting...")
            print("="*60)
            print(f"📁 Serving directory: {DIRECTORY}")
            print(f"🌐 Server running at:")
            print(f"   Local:   http://localhost:{self.port}")
            print(f"   Local:   http://127.0.0.1:{self.port}")
            if local_ip:
                print(f"   Network: http://{local_ip}:{self.port}")
            print("="*60)
            print(f"📋 Access the training hub at: http://localhost:{self.port}/index.html")
            print(f"📋 Access templates at: http://localhost:{self.port}/Templates/index.html")
            print("="*60)
            print("\n💡 Press Ctrl+C to stop the server\n")
            
            # Open browser if requested
            if open_browser:
                try:
                    webbrowser.open(f'http://localhost:{self.port}/index.html')
                except:
                    pass
            
            # Handle graceful shutdown
            signal.signal(signal.SIGINT, self._signal_handler)
            signal.signal(signal.SIGTERM, self._signal_handler)
            
            # Start serving
            self.httpd.serve_forever()
            
        except OSError as e:
            if e.errno == 48:  # Address already in use
                print(f"\n❌ Error: Port {self.port} is already in use!")
                print(f"   Try a different port or stop the process using port {self.port}")
                print(f"   To use a different port: python server.py --port 8081\n")
            else:
                print(f"\n❌ Error starting server: {e}\n")
            sys.exit(1)
        except KeyboardInterrupt:
            self.stop()
        except Exception as e:
            print(f"\n❌ Unexpected error: {e}\n")
            sys.exit(1)
    
    def stop(self):
        """Stop the web server gracefully."""
        if self.httpd and self.running:
            print("\n\n🛑 Shutting down server...", flush=True)
            self.running = False
            try:
                # shutdown() works from signal handlers in Python 3
                self.httpd.shutdown()
                # Close the socket explicitly to release the port immediately
                if hasattr(self.httpd, 'socket') and self.httpd.socket:
                    try:
                        self.httpd.socket.close()
                    except:
                        pass
                self.httpd.server_close()
                print("✅ Server stopped successfully.\n", flush=True)
            except Exception as e:
                print(f"⚠️  Error during shutdown: {e}\n", flush=True)
    
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals."""
        self.stop()
        sys.exit(0)
    
    def _get_local_ip(self):
        """Get the local IP address."""
        try:
            import socket
            # Connect to a remote address to determine local IP
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
            s.close()
            return ip
        except:
            return None

def main():
    """Main entry point."""
    import argparse
    
    parser = argparse.ArgumentParser(description='SIOP Training Hub Web Server')
    parser.add_argument('--port', '-p', type=int, default=PORT,
                       help=f'Port to run server on (default: {PORT})')
    parser.add_argument('--host', type=str, default=HOST,
                       help=f'Host to bind to (default: {HOST})')
    parser.add_argument('--no-browser', action='store_true',
                       help='Do not open browser automatically')
    
    args = parser.parse_args()
    
    # Check if directory exists
    if not DIRECTORY.exists():
        print(f"❌ Error: Directory {DIRECTORY} does not exist!")
        sys.exit(1)
    
    # Start server
    server = Server(port=args.port, host=args.host)
    server.start(open_browser=not args.no_browser)

if __name__ == '__main__':
    main()
