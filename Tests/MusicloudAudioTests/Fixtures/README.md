# Generated audio fixtures

Two-second 440 Hz sine wave, stereo, 48 kHz, 24-bit PCM. Generated for this
project; no third-party music. Covered by the repository's MIT license.

Reproduce from the repository root with FFmpeg (test execution does not require it):

```sh
ffmpeg -f lavfi -i 'sine=frequency=440:sample_rate=48000:duration=2' -ac 2 -c:a pcm_s24le -metadata title='Musicloud Test Tone' -metadata artist='Musicloud' Tests/MusicloudAudioTests/Fixtures/tone.wav
ffmpeg -f lavfi -i 'testsrc2=size=400x400:duration=1' -frames:v 1 -update 1 Tests/MusicloudAudioTests/Fixtures/cover.jpg
ffmpeg -i Tests/MusicloudAudioTests/Fixtures/tone.wav -i Tests/MusicloudAudioTests/Fixtures/cover.jpg -map 0:a -map 1:v -c:a flac -c:v copy -disposition:v attached_pic Tests/MusicloudAudioTests/Fixtures/tone.flac
```

The generated color test pattern verifies both sidecar artwork (WAV) and embedded
artwork (FLAC). It is diagnostic artwork, not a production album cover.
