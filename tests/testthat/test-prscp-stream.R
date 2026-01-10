skip_on_ci()
skip_on_cran()
skip_if_not(has_ffmpeg())

test_that("initialization succeeds", {
  st <- create_stream(tempfile(fileext = ".mp4"), width = 640, height = 320)

  expect_true(is_prscp_stream(st))
  expect_true(is_available_stream(st))

  close(st)
  expect_false(is_available_stream(st))
})

test_that("stream accepts frames", {
  st <- create_stream(tempfile(fileext = ".mp4"), width = 640, height = 320)
  on.exit(close(st), add = TRUE)

  frame <- colorfast::col_to_int("navy") |>
    rep_len(640 * 320)
  dim(frame) <- c(320, 640)
  class(frame) <- "nativeRaster"
  expect_type(send_frame(st, frame), "raw")

  frame <- rep_len("hotpink", 640 * 320) |>
    colorfast::col_to_rgb()
  expect_type(send_frame(st, frame), "raw")

  frame <- colorfast::col_to_int("green") |>
    rep_len(640 * 480)
  dim(frame) <- c(480, 640)
  class(frame) <- "nativeRaster"
  expect_snapshot_error(send_frame(st, frame))
})
