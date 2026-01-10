#' @keywords internal
"_PACKAGE"

gen_stream_name <- local({
  counter <- 0L
  function(name = "periscope%03d.mp4") {
    counter <<- counter + 1L
    sprintf(name, counter)
  }
})

#' @export
as.raw.nativeRaster <- function(x) {
  x <- colorfast::int_to_col(x) |>
    colorfast::col_to_rgb()
  NextMethod(x)
}

#' @keywords internal
#' @export
has_ffmpeg <- function() {
  Sys.which("ffmpeg") != ""
}

#' Stream rendered frames from R to ffmpeg
#'
#' @description
#' The `prscp_stream` API provides a minimal mechanism to stream
#' frame-based graphics generated in R using an external ffmpeg process
#' through [base::pipe()].
#'
#' By default, frames are written to the standard input of an ffmpeg
#' process, which performs encoding (H.264) and publishing (FLV/RTMP).
#' This design keeps R responsible only for frame generation, while
#' delegating video encoding and transport to ffmpeg.
#'
#' A `prscp_stream` object represents an open connection to an ffmpeg
#' process. Frames can be sent sequentially using `send_frame()`, and
#' the stream must be explicitly closed with `close()`.
#'
#' @details
#' This API is intended for experimental, generative, or exploratory
#' use cases where the execution of R itself is treated as a temporal
#' process. It does not guarantee a stable frame rate, synchronized
#' playback, or real-time rendering semantics.
#'
#' The target of the stream can be an RTMP server (e.g. MediaMTX),
#' or a local file path. RTMP streaming requires a listening server;
#' direct peer-to-peer connections are not supported by the RTMP
#' protocol.
#'
#' @param name A character string specifying the target of the stream.
#'  If the string contains a `%d` placeholder, it will be replaced
#'  with an incrementing integer (e.g. `"rtmp://localhost/live%03d"`).
#' @param width,height Integer specifying the width and height of the
#'  streamed frames.
#' @param fps Integer specifying the frame rate for encoding.
#' @param x A `prscp_stream` object.
#' @param frame An integer vector of length `width * height * 4` or
#'  a `nativeRaster` object specifying the raw frame data.
#' @returns
#'  * `create_stream()` returns a new `prscp_stream` object.
#'  * `close.prscp_stream()` invisibly returns `x`.
#'  * `send_frame()` invisibly returns the streamed data as a raw vector.
#' @rdname prscp-stream
#' @name prscp-stream
NULL

#' @rdname prscp-stream
#' @export
create_stream <- function(name = "rtmp://localhost/live%03d", width = 720, height = 480, fps = 10) {
  width <- as.integer(width)
  height <- as.integer(height)
  fps <- as.integer(fps)

  if (!all(width >= 1L, height >= 1L, fps >= 1, na.rm = TRUE) || anyNA(c(width, height, fps))) {
    cli::cli_abort("`width`, `height` and `fps` must be positive integers.")
  }
  if (!is.character(name) || length(name) != 1L) {
    cli::cli_abort("`name` must be a single string.")
  }
  if (!has_ffmpeg()) {
    cli::cli_abort("ffmpeg not found. Install ffmpeg and set it in your PATH.")
  }

  if (grepl("%", name, fixed = TRUE)) {
    name_final <- gen_stream_name(name)
  } else {
    name_final <- name
  }
  cmd <- glue::glue(
    "ffmpeg -loglevel error -nostats -f rawvideo -pix_fmt rgba -s {width}x{height} -r {fps} -i pipe:0 -c:v libx264 -preset ultrafast -tune zerolatency -y -f flv {name_final}"
  )
  stream <- structure(
    list(
      name = name_final,
      conn = pipe(cmd, "wb"),
      width = width,
      height = height,
      fps = fps
    ),
    class = "prscp_stream"
  )

  stream
}

#' @rdname prscp-stream
#' @export
is_prscp_stream <- function(x) {
  inherits(x, "prscp_stream")
}

#' @rdname prscp-stream
#' @export
is_available_stream <- function(x) {
  summ <- tryCatch(summary(x$conn), error = function(e) e)
  !is.null(summ$opened) && summ$opened == "opened"
}

#' @rdname prscp-stream
#' @export
close.prscp_stream <- function(x) {
  if (!is_available_stream(x)) {
    cli::cli_warn("`x` has already been closed.")
    return(invisible(x))
  }
  close(x$conn)
  invisible(x)
}

#' @rdname prscp-stream
#' @export
send_frame <- function(x, frame) {
  if (!is_prscp_stream(x) || !is_available_stream(x)) {
    cli::cli_abort("`x` must be a valid prscp_stream object.")
  }
  if (inherits(frame, "nativeRaster")) {
    if (!identical(dim(frame), c(x$height, x$width))) {
      cli::cli_abort("`frame` must have dimensions {x$height}x{x$width}.")
    }
    frame <- as.raw(frame)
  } else {
    if (length(frame) != x$width * x$height * 4L) {
      cli::cli_abort("`frame` must have length {x$height}x{x$width}x4.")
    }
    frame <- as.raw(as.integer(frame) %% 256)
  }
  writeBin(frame, x$conn)
  invisible(frame)
}
