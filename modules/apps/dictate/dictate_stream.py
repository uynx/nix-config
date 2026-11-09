import array, io, math, os, queue, signal, subprocess, sys, threading, time, wave
from collections import deque

RATE = 16000
FRAME = 640
URL = "http://127.0.0.1:8765/v1/audio/transcriptions"
PIDFILE = "/tmp/whisper-dictate.pid"
DEBUG = "/tmp/dictate-debug"


class Segmenter:
    def __init__(self, level=60, ratio=3, pause=0.6, lead=0.2, minimum=0.15, longest=15.0):
        self.level, self.ratio, self.floor = level, ratio, level / ratio
        self.pause, self.lead, self.minimum, self.longest = (round(s * 50) for s in (pause, lead, minimum, longest))
        self.tail = b""
        self.recent = deque(maxlen=self.lead)
        self.frames, self.voiced, self.quiet = [], 0, 0

    def feed(self, data):
        data = self.tail + data
        cut = len(data) - len(data) % FRAME
        self.tail = data[cut:]
        phrases = (self._frame(data[i:i + FRAME]) for i in range(0, cut, FRAME))
        return [p for p in phrases if p]

    def flush(self):
        return self._finish() if self.frames else None

    def _frame(self, frame):
        samples = array.array("h", frame)
        rms = math.sqrt(sum(s * s for s in samples) / len(samples))
        # The floor drops to any quieter frame at once and creeps up slowly, so speech cannot drag it up.
        self.floor = min(rms, self.floor * 1.002 + 0.01)
        loud = rms >= max(self.level, self.ratio * self.floor)
        if not self.frames:
            if loud:
                self.frames, self.voiced, self.quiet = [*self.recent, frame], 1, 0
                self.recent.clear()
            else:
                self.recent.append(frame)
            return None
        self.frames.append(frame)
        self.voiced, self.quiet = (self.voiced + 1, 0) if loud else (self.voiced, self.quiet + 1)
        if self.quiet >= self.pause or len(self.frames) >= self.longest:
            return self._finish()
        return None

    def _finish(self):
        frames = self.frames[:len(self.frames) - max(0, self.quiet - self.lead)]
        voiced = self.voiced
        self.frames, self.voiced, self.quiet = [], 0, 0
        return b"".join(frames) if voiced >= self.minimum else None


def join_phrases(count, text):
    text = text.strip()
    return " " + text if text and count else text


def wav_bytes(pcm):
    wav = io.BytesIO()
    with wave.open(wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm)
    return wav.getvalue()


def transcribe(pcm):
    done = subprocess.run(
        ["curl", "-sf", "--retry", "5", "--retry-connrefused", "--retry-delay", "1", "--max-time", "30",
         "-F", "file=@-;filename=a.wav", "-F", "response_format=text", URL],
        input=wav_bytes(pcm), capture_output=True)
    return done.stdout.decode().replace("\n", " ") if done.returncode == 0 else None


def type_text(text):
    # Not wtype: it gives the Nth new character evdev code N, so letters land on Tab or Backspace.
    socket = os.environ.get("YDOTOOL_SOCKET", "/run/ydotoold/socket")
    subprocess.run(["ydotool", "type", "--key-delay", "6", "--key-hold", "6", "--", text],
                   env={**os.environ, "YDOTOOL_SOCKET": socket}, stderr=subprocess.DEVNULL)


def notify(message):
    subprocess.run(["notify-send", "Dictation", message, "-i", "dictate-mic"], stderr=subprocess.DEVNULL)


def typist(phrases, said):
    failed = False
    while (pcm := phrases.get()) is not None:
        text = transcribe(pcm)
        if text is None and not failed:
            failed = True
            notify("The phonon service is not answering")
        piece = join_phrases(len(said), text or "")
        if piece:
            type_text(piece)
            said.append(piece.strip())


def main():
    nodes = subprocess.run(["pw-cli", "ls", "Node"], capture_output=True, text=True).stdout
    mic = ["--target", "effect_output.j314-mic"] if 'node.name = "effect_output.j314-mic"' in nodes else []
    rec = subprocess.Popen(["pw-record", *mic, f"--rate={RATE}", "--channels=1", "--format=s16", "-"],
                           stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, bufsize=0)
    with open(PIDFILE, "w") as f:
        f.write(str(os.getpid()))
    for sig in (signal.SIGTERM, signal.SIGINT):
        signal.signal(sig, lambda *_: rec.terminate())
    header = rec.stdout.read(24)
    if len(header) == 24:
        rec.stdout.read(max(0, int.from_bytes(header[4:8], "little") - 24))
    notify("Listening. Press Super+D again to stop.")
    phrases, said = queue.Queue(), []
    thread = threading.Thread(target=typist, args=(phrases, said))
    thread.start()
    seg = Segmenter()
    raw = bytearray() if os.path.isdir(DEBUG) else None
    while chunk := os.read(rec.stdout.fileno(), 3200):
        if raw is not None:
            raw += chunk
        for phrase in seg.feed(chunk):
            phrases.put(phrase)
    if last := seg.flush():
        phrases.put(last)
    phrases.put(None)
    thread.join()
    os.remove(PIDFILE)
    if raw is not None:
        stamp = time.strftime("%H%M%S")
        with open(f"{DEBUG}/{stamp}.wav", "wb") as f:
            f.write(wav_bytes(bytes(raw)))
        with open(f"{DEBUG}/{stamp}.txt", "w") as f:
            f.write(" ".join(said))
    if said:
        subprocess.run(["wl-copy"], input=" ".join(said).encode())
    else:
        notify("No speech detected")


if __name__ == "__main__":
    sys.exit(main())
