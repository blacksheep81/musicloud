# Generated audio fixtures

Two-second 440 Hz sine wave, stereo, 48 kHz, 24-bit PCM. Generated for this
project; no third-party music. Covered by the repository's MIT license.

Reproduce from the repository root with FFmpeg (test execution does not require it):

```sh
ffmpeg -f lavfi -i 'sine=frequency=440:sample_rate=48000:duration=2' -ac 2 -c:a pcm_s24le -metadata title='Musicloud Test Tone' -metadata artist='Musicloud' Tests/MusicloudAudioTests/Fixtures/tone.wav
ffmpeg -i Tests/MusicloudAudioTests/Fixtures/tone.wav -c:a flac Tests/MusicloudAudioTests/Fixtures/tone.flac
```
