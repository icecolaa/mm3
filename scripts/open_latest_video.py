#!/usr/bin/env python3
"""Watch ComfyUI output; open each newly finished video with the system default player."""

import argparse
import os
import socket
import sys
import time
from datetime import datetime

DEFAULT_DIR = r"D:\LocalAI\ComfyUI_windows_portable\ComfyUI\output"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_LOG = os.path.join(SCRIPT_DIR, "logs", "open-latest-video.log")
VIDEO_EXTS = (".mp4", ".webm", ".mov", ".mkv")
CONTROL_PORT = 47831
MAX_LOG_BYTES = 2 * 1024 * 1024


def log(msg):
    line = "[{}] {}".format(datetime.now().strftime("%Y-%m-%d %H:%M:%S"), msg)
    if sys.stdout is not None:
        try:
            print(line, flush=True)
        except Exception:
            pass
    try:
        os.makedirs(os.path.dirname(DEFAULT_LOG), exist_ok=True)
        if os.path.exists(DEFAULT_LOG) and os.path.getsize(DEFAULT_LOG) > MAX_LOG_BYTES:
            os.replace(DEFAULT_LOG, DEFAULT_LOG + ".1")
        with open(DEFAULT_LOG, "a", encoding="utf-8") as fh:
            fh.write(line + "\n")
    except OSError:
        pass


def human_size(n):
    return "{:.1f} MB".format(n / 1048576.0)


def scan_videos(root):
    found = {}
    for dirpath, _dirnames, filenames in os.walk(root):
        for name in filenames:
            if not name.lower().endswith(VIDEO_EXTS):
                continue
            path = os.path.join(dirpath, name)
            try:
                st = os.stat(path)
            except OSError:
                continue
            found[path] = (st.st_size, st.st_mtime)
    return found


def open_video(path, dry_run):
    if dry_run:
        log("DRY-RUN would open " + path)
        return True
    for attempt in range(3):
        try:
            os.startfile(path)
            log("opened with default player: " + path)
            return True
        except OSError as exc:
            if attempt == 2:
                log("open failed: {} ({})".format(path, exc))
                return False
            time.sleep(1.0)


def acquire_control():
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    if hasattr(socket, "SO_EXCLUSIVEADDRUSE"):
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_EXCLUSIVEADDRUSE, 1)
    try:
        sock.bind(("127.0.0.1", CONTROL_PORT))
    except OSError:
        sock.close()
        return None
    sock.listen(1)
    sock.setblocking(False)
    return sock


def request_stop():
    try:
        with socket.create_connection(("127.0.0.1", CONTROL_PORT), timeout=2) as sock:
            sock.sendall(b"stop")
        print("stop signal sent")
        return 0
    except OSError:
        print("no watcher is running")
        return 1


def stop_requested(control):
    try:
        conn, _addr = control.accept()
    except OSError:
        return False
    with conn:
        data = conn.recv(32)
    return data.strip().lower() == b"stop"


def watch(args):
    root = os.path.abspath(args.dir)
    if not os.path.isdir(root):
        log("watch dir not found: " + root)
        return 2
    control = acquire_control()
    if control is None:
        log("another watcher is already running (control port {} in use)".format(CONTROL_PORT))
        return 0

    handled = set(scan_videos(root))
    pending = {}
    log("watching {} (every {}s, settle {}s); {} existing video(s) ignored".format(
        root, args.interval, args.settle, len(handled)))
    try:
        while True:
            if stop_requested(control):
                log("stop requested, exiting")
                break
            time.sleep(args.interval)
            now = time.time()
            current = scan_videos(root)
            settled = []
            for path, (size, mtime) in current.items():
                if path in handled:
                    continue
                prev = pending.get(path)
                if prev is None or prev[0] != size:
                    pending[path] = (size, now, mtime)
                    continue
                if now - prev[1] >= args.settle:
                    settled.append((mtime, size, path))
                    del pending[path]
            for path in list(pending):
                if path not in current:
                    del pending[path]
            if not settled:
                continue
            settled.sort()
            for _mtime, size, path in settled:
                handled.add(path)
                log("new video: {} ({})".format(path, human_size(size)))
            if args.all:
                for _mtime, _size, path in settled:
                    open_video(path, args.dry_run)
            else:
                open_video(settled[-1][2], args.dry_run)
                if len(settled) > 1:
                    log("{} new files appeared together, opened the newest only".format(len(settled)))
    except KeyboardInterrupt:
        log("interrupted, exiting")
    finally:
        control.close()
    return 0


def main():
    ap = argparse.ArgumentParser(description="Open newly generated ComfyUI videos with the default player.")
    ap.add_argument("--dir", default=DEFAULT_DIR, help="folder to watch (recursive)")
    ap.add_argument("--interval", type=float, default=2.0, help="scan interval in seconds")
    ap.add_argument("--settle", type=float, default=3.0, help="seconds the size must stay unchanged")
    ap.add_argument("--all", action="store_true", help="open every new video, not just the newest")
    ap.add_argument("--dry-run", action="store_true", help="log detections without opening")
    ap.add_argument("--stop", action="store_true", help="stop a running watcher and exit")
    args = ap.parse_args()

    if args.stop:
        return request_stop()
    return watch(args)


if __name__ == "__main__":
    sys.exit(main())
