# periscope


<!-- README.qmd is generated from README.Rmd. Please edit that file -->

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

periscope is a tiny R package that lets you publish frames generated in
R as a video stream by piping raw RGBA pixel data into an external
ffmpeg process. This makes it possible to show R-generated graphics in
tools like [OBS Studio](https://obsproject.com/) or
[VLC](https://videolan.org/vlc/) over a local network, e.g. via an RTMP
server such as [MediaMTX](https://mediamtx.org/).

## What periscope can do

- Create a streaming “sink” backed by an ffmpeg process
- Push frames one-by-one from R (either a `nativeRaster` or integers of
  RGBA pixel data)
- Publish the resulting H.264/FLV stream to:
  - an RTMP server (recommended; e.g. MediaMTX), or
  - a local file path (for quick testing)

## Typical workflow: publish to an RTMP server

### 1. Start an RTMP server (MediaMTX)

Run MediaMTX on the machine that will receive and redistribute the
stream (often the same box that runs R).

By default, MediaMTX listens for RTMP publishes. In the examples below
we publish to `rtmp://<SERVER_IP>/live/stream`.

### 2. Publish frames from R

In R, create a stream and send frames to it. The example below uses
[ragg](https://ragg.r-lib.org/) to capture grid drawings as
`nativeRaster`, then streams those frames:

``` r
library(periscope)

w <- 640
h <- 480

cap <- ragg::agg_capture(width = w, height = h, units = "px")

# Publish to MediaMTX (running on localhost in this example)
st <- create_stream(
  name = "rtmp://localhost/live/stream",
  width = w, height = h, fps = 30
)

for (i in 1:300) {
  grid::grid.newpage()
  grid::grid.text(
    paste("Frame", i),
    gp = grid::gpar(fontsize = 60, col = "magenta")
  )
  frame <- cap(native = TRUE) # Capture grid drawing as 'nativeRaster'
  send_frame(st, frame)
}

close(st)
dev.off()
```

**Notes**:

- `send_frame()` accepts either:
  - a `nativeRaster` with dimensions `height x width`, or
  - a vector representing RGBA pixel data, with length
    `width * height * 4`.
- The stream is only “alive” while the `prscp_stream` is open. Always
  call `close()` when done.

### 3. Viewing the stream

#### VLC

On the machine in the same LAN, open VLC:

- ***Media → Open Network Stream…***
- Enter the stream URL, e.g. `rtmp://<SERVER_IP>/live/stream`
- Then press ***Play***.

#### OBS Studio

In OBS on the viewer machine:

- Add a new ***Media Source***
- Enter the same RTMP URL, e.g. `rtmp://<SERVER_IP>/live/stream`

Depending on your environment, OBS may require additional
components/plugins to read RTMP streams directly. If your OBS build does
not support RTMP playback out of the box, use VLC (or an OBS VLC source)
as the receiver.

## How it works

periscope does not implement an RTMP client or a video encoder as part
of the package. Instead:

1.  R generates a frame (typically a `nativeRaster`).
2.  The frame is converted to raw RGBA bytes.
3.  Those bytes are written to the standard input of an ffmpeg process
    using `base::pipe()`.
4.  ffmpeg:
    1.  interprets the incoming bytes as a raw video stream
        (`-f rawvideo -pix_fmt rgba -s WxH`),
    2.  encodes the video (H.264), and
    3.  publishes it as FLV/RTMP to your chosen target.

In other words, R is responsible for frame generation, while ffmpeg is
responsible for encoding and transport.

## Limitations

- Not a real-time renderer: periscope pushes frames only when your R
  code calls `send_frame()`. There is no richer scheduling or
  throttling.
- No guaranteed frame rate: the effective FPS depends on how fast R can
  generate frames (and how often you call `send_frame()`).
- RTMP requires a server: RTMP is not a peer-to-peer protocol. To view a
  stream from another machine, you typically need an RTMP server
  (e.g. MediaMTX) that listens for publishes.

## License

MIT License.
