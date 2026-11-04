import math, os, struct, tempfile, unittest
import dictate_stream
from dictate_stream import Segmenter, join_phrases

RATE = 16000


def tone(seconds, amp=4000):
    return b"".join(struct.pack("<h", int(amp * math.sin(i / 5))) for i in range(int(RATE * seconds)))


def quiet(seconds):
    return b"\0\0" * int(RATE * seconds)


def feed_all(seg, audio, chunk=3200):
    out = []
    for i in range(0, len(audio), chunk):
        out += seg.feed(audio[i:i + chunk])
    return out


def seconds(pcm):
    return len(pcm) / 2 / RATE


class Phrases(unittest.TestCase):
    def test_a_pause_ends_a_phrase(self):
        out = feed_all(Segmenter(), tone(1) + quiet(1))
        self.assertEqual(len(out), 1)
        self.assertAlmostEqual(seconds(out[0]), 1.0, delta=0.9)

    def test_a_phrase_is_not_released_until_the_pause(self):
        self.assertEqual(feed_all(Segmenter(), tone(1) + quiet(0.3)), [])

    def test_two_phrases_come_out_in_order(self):
        out = feed_all(Segmenter(), tone(1) + quiet(1) + tone(2) + quiet(1))
        self.assertEqual(len(out), 2)
        self.assertGreater(seconds(out[1]), seconds(out[0]))

    def test_silence_alone_produces_nothing(self):
        seg = Segmenter()
        self.assertEqual(feed_all(seg, quiet(5)), [])
        self.assertEqual(seg.flush(), None)

    def test_flush_returns_a_phrase_still_in_progress(self):
        seg = Segmenter()
        self.assertEqual(feed_all(seg, tone(1)), [])
        self.assertAlmostEqual(seconds(seg.flush()), 1.0, delta=0.4)
        self.assertEqual(seg.flush(), None)

    def test_a_click_shorter_than_a_syllable_is_dropped(self):
        seg = Segmenter()
        self.assertEqual(feed_all(seg, tone(0.06) + quiet(1)), [])
        self.assertEqual(seg.flush(), None)

    def test_a_short_pause_inside_a_sentence_keeps_it_whole(self):
        out = feed_all(Segmenter(), tone(1) + quiet(0.3) + tone(1) + quiet(1))
        self.assertEqual(len(out), 1)
        self.assertGreater(seconds(out[0]), 2.2)

    def test_start_of_speech_keeps_a_little_lead_in(self):
        out = feed_all(Segmenter(), quiet(1) + tone(1) + quiet(1))
        self.assertGreater(seconds(out[0]), 1.0)

    def test_a_long_run_without_a_pause_is_cut(self):
        out = feed_all(Segmenter(), tone(40))
        self.assertGreaterEqual(len(out), 2)
        self.assertTrue(all(seconds(p) <= 16 for p in out))

    def test_chunks_that_split_a_sample_are_handled(self):
        audio = tone(1) + quiet(1)
        out = feed_all(Segmenter(), audio, chunk=3201)
        self.assertEqual(len(out), 1)


class Joining(unittest.TestCase):
    def test_the_first_phrase_has_no_leading_space_and_later_ones_do(self):
        self.assertEqual(join_phrases(0, "Hello there."), "Hello there.")
        self.assertEqual(join_phrases(1, "How are you?"), " How are you?")

    def test_blank_text_types_nothing(self):
        self.assertEqual(join_phrases(1, "  \n"), "")


class Runner(unittest.TestCase):
    def run_main(self, audio):
        home = tempfile.mkdtemp()
        bin = os.path.join(home, "bin")
        os.mkdir(bin)
        header = struct.pack("<4s5I", b"dns.", 24, 0xFFFFFFFF, 3, RATE, 1)
        with open(os.path.join(home, "stream"), "wb") as f:
            f.write(header + audio)
        stubs = {
            "pw-record": f'cat "{home}/stream"',
            "pw-cli": "true",
            "notify-send": f'echo "$2" >> "{home}/notes"',
            "curl": "cat >/dev/null; echo 'word'",
            "wtype": f'shift; printf "[%s]" "$*" >> "{home}/typed"',
            "wl-copy": f'cat > "{home}/clip"',
        }
        for name, body in stubs.items():
            path = os.path.join(bin, name)
            with open(path, "w") as f:
                f.write("#!/bin/sh\n" + body + "\n")
            os.chmod(path, 0o755)
        old = (os.environ["PATH"], dictate_stream.PIDFILE)
        os.environ["PATH"], dictate_stream.PIDFILE = bin + ":" + old[0], os.path.join(home, "pid")
        try:
            dictate_stream.main()
        finally:
            os.environ["PATH"], dictate_stream.PIDFILE = old
        read = lambda n: open(os.path.join(home, n)).read() if os.path.exists(os.path.join(home, n)) else ""
        return read("typed"), read("clip"), read("notes")

    def test_every_phrase_in_the_stream_is_typed_in_order(self):
        typed, clip, _ = self.run_main(quiet(1) + tone(1) + quiet(1) + tone(1) + quiet(1))
        self.assertEqual(typed, "[word][ word]")
        self.assertEqual(clip, "word word")

    def test_a_stream_with_no_speech_says_so_and_types_nothing(self):
        typed, clip, notes = self.run_main(quiet(3))
        self.assertEqual((typed, clip), ("", ""))
        self.assertIn("No speech detected", notes)


if __name__ == "__main__":
    unittest.main()
