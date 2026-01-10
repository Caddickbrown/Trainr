# 🚀 SIOP Training Hub - Quick Start Guide

Get your training hub running on your home server in minutes!

## Prerequisites

- **Python 3.6+** installed on your system
  - Check with: `python3 --version` (Mac/Linux) or `python --version` (Windows)
  - Download from: https://www.python.org/downloads/

## Quick Start (Choose Your Platform)

### 🍎 Mac / Linux

1. **Make scripts executable:**
   ```bash
   chmod +x start.sh stop.sh server.py
   ```

2. **Start the server:**
   ```bash
   ./start.sh
   ```

3. **Access the training hub:**
   - Open your browser to: http://localhost:8080/index.html
   - Or access from other devices on your network: http://YOUR_SERVER_IP:8080/index.html

4. **Stop the server:**
   ```bash
   ./stop.sh
   ```

### 🪟 Windows

1. **Start the server:**
   ```cmd
   start.bat
   ```
   (The browser should open automatically)

2. **Access the training hub:**
   - Browser should open automatically
   - Or manually go to: http://localhost:8080/index.html
   - Or access from other devices: http://YOUR_SERVER_IP:8080/index.html

3. **Stop the server:**
   ```cmd
   stop.bat
   ```

### 🐍 Manual Start (Any Platform)

If you prefer to run it manually:

```bash
python3 server.py
```

Or with custom port:
```bash
python3 server.py --port 8081
```

Press `Ctrl+C` to stop.

## 📋 Server Details

- **Default Port:** 8080
- **Access URLs:**
  - Local: http://localhost:8080/index.html
  - Network: http://YOUR_SERVER_IP:8080/index.html
- **Logs:** Written to `server.log` (when using start scripts)

## 🔧 Customization

### Change Port

**Mac/Linux:**
```bash
python3 server.py --port 9000
```

**Windows:**
Run with a custom port:
```cmd
start.bat 9000
```

### Change Host Binding

By default, the server listens on all interfaces (`0.0.0.0`), making it accessible from your network.

To only allow local access:
```bash
python3 server.py --host 127.0.0.1
```

## 🌐 Accessing from Other Devices

1. **Find your server's IP address:**
   - Mac/Linux: `ifconfig` or `ip addr`
   - Windows: `ipconfig`
   - Look for your local network IP (usually starts with 192.168.x.x or 10.x.x.x)

2. **Access from other devices:**
   - On your phone/tablet/other computer, open: `http://YOUR_SERVER_IP:8080/index.html`
   - Make sure the device is on the same network

## 🛠️ Troubleshooting

### Port Already in Use

If you see "Port 8080 is already in use":

1. **Use a different port:**
   ```bash
   python3 server.py --port 8081
   ```

2. **Or find and stop the process using port 8080:**
   - Mac/Linux: `lsof -ti:8080 | xargs kill`
   - Windows: Find process in Task Manager or use `netstat -ano | findstr :8080`

### Server Won't Start

1. **Check Python is installed:**
   ```bash
   python3 --version
   ```

2. **Check the logs:**
   - Mac/Linux: `cat server.log`
   - Windows: Open `server.log` in a text editor

3. **Check file permissions:**
   - Mac/Linux: Make sure scripts are executable (`chmod +x start.sh stop.sh`)

### Can't Access from Network

1. **Check firewall settings:**
   - Make sure port 8080 is allowed through your firewall
   - Mac: System Preferences → Security & Privacy → Firewall
   - Windows: Windows Defender Firewall → Allow an app

2. **Verify server is listening on all interfaces:**
   - Check that server.py uses `HOST = '0.0.0.0'` (default)

3. **Check your IP address:**
   - Make sure you're using the correct local network IP

## 📝 Running as a Service (Advanced)

### Mac (LaunchAgent)

Create `~/Library/LaunchAgents/com.siop.traininghub.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.siop.traininghub</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/python3</string>
        <string>/path/to/RRPrep/server.py</string>
        <string>--no-browser</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>WorkingDirectory</key>
    <string>/path/to/RRPrep</string>
</dict>
</plist>
```

Load it:
```bash
launchctl load ~/Library/LaunchAgents/com.siop.traininghub.plist
```

### Linux (systemd)

Create `/etc/systemd/system/siop-traininghub.service`:

```ini
[Unit]
Description=SIOP Training Hub Server
After=network.target

[Service]
Type=simple
User=yourusername
WorkingDirectory=/path/to/RRPrep
ExecStart=/usr/bin/python3 /path/to/RRPrep/server.py --no-browser
Restart=always

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl enable siop-traininghub
sudo systemctl start siop-traininghub
```

## 🎯 What's Next?

1. **Start the server** using one of the methods above
2. **Open the training hub** in your browser
3. **Complete the training modules** at your own pace
4. **Use the templates** for your real work
5. **Keep the server running** - it will stay on until you stop it

## 💡 Tips

- **Bookmark the URL** for easy access
- **Use the templates** - they're designed to be printed or saved as PDF
- **Practice regularly** - the training modules are designed for repetition
- **Keep the server running** - start it once and leave it running

## 🆘 Need Help?

- Check the logs: `server.log`
- Verify Python is installed: `python3 --version`
- Check port availability: `netstat -an | grep 8080` (Mac/Linux) or `netstat -an | findstr 8080` (Windows)

---

**Happy Training! 🎓**
