"""
PhoneMic Receiver
Listens on a TCP port for the iPhone app's audio stream and writes it into
VB-Audio Virtual Cable ("CABLE Input"), which Windows then exposes to every
other app as a normal microphone ("CABLE Output").

Wire protocol (simple, fixed):
  - Client connects, immediately sends an 8-byte header:
        uint32 little-endian sampleRate
        uint32 little-endian channelCount
  - Then a continuous stream of raw PCM16 little-endian audio samples.
"""

import socket
import struct
import sys
import threading
import time

import numpy as np
import sounddevice as sd

LISTEN_PORT = 50505
CABLE_NAME_HINT = "CABLE Input"  # VB-Audio virtual cable input device


def find_cable_device():
    devices = sd.query_devices()
    for idx, dev in enumerate(devices):
        if CABLE_NAME_HINT.lower() in dev["name"].lower() and dev["max_output_channels"] > 0:
            return idx
    return None


def recv_exact(conn, n):
    buf = b""
    while len(buf) < n:
        chunk = conn.recv(n - len(buf))
        if not chunk:
            return None
        buf += chunk
    return buf


def handle_client(conn, addr, status_cb):
    status_cb(f"Phone connected from {addr[0]}")
    header = recv_exact(conn, 8)
    if not header:
        status_cb("Connection closed before header received")
        return

    sample_rate, channels = struct.unpack("<II", header)
    channels = max(1, channels)
    status_cb(f"Stream format: {sample_rate} Hz, {channels} ch")

    device_idx = find_cable_device()
    if device_idx is None:
        status_cb("ERROR: VB-Cable ('CABLE Input') not found. Is it installed?")
        return

    frame_bytes = 2 * channels  # int16 per channel

    def callback(outdata, frames, time_info, status):
        needed = frames * frame_bytes
        data = recv_exact(conn, needed)
        if data is None:
            raise sd.CallbackStop()
        samples = np.frombuffer(data, dtype="<i2").astype(np.float32) / 32768.0
        samples = samples.reshape(-1, channels)
        outdata[:] = samples

    try:
        with sd.OutputStream(
            samplerate=sample_rate,
            channels=channels,
            dtype="float32",
            device=device_idx,
            callback=callback,
            blocksize=1024,
        ):
            status_cb("Streaming to virtual mic — select 'CABLE Output' as your mic in apps")
            while True:
                time.sleep(0.5)
    except Exception as e:
        status_cb(f"Stream ended: {e}")
    finally:
        conn.close()
        status_cb("Phone disconnected — waiting for reconnect")


def main():
    def status_cb(msg):
        print(f"[PhoneMic] {msg}", flush=True)

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("0.0.0.0", LISTEN_PORT))
    server.listen(1)

    local_ip = socket.gethostbyname(socket.gethostname())
    status_cb(f"Listening on {local_ip}:{LISTEN_PORT} — enter this IP in the iPhone app")

    while True:
        conn, addr = server.accept()
        t = threading.Thread(target=handle_client, args=(conn, addr, status_cb), daemon=True)
        t.start()
        t.join()  # one phone at a time is all we need


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
