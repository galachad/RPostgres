context("checkInterrupts")

test_that("check_interrupts = TRUE works with queries > 1 second (#244)", {
  con <- postgresDefault(check_interrupts = TRUE)
  expect_equal(dbGetQuery(con, "SELECT pg_sleep(0.2), 'foo' AS x")$x, "foo")
  dbDisconnect(con)
})

test_that("check_interrupts = TRUE interrupts immediately (#336)", {
  skip_if_not(postgresHasDefault())
  skip_if(Sys.getenv("R_COVR") != "")
  skip_if(getRversion() < "4.0")

  # For skipping if not available
  dbDisconnect(postgresDefault())

  session <- callr::r_session$new()

  session$supervise(TRUE)

  session$run(function() {
    library(RPostgres)
    .GlobalEnv$conn <- postgresDefault(check_interrupts = TRUE)
    invisible()
  })

  session$call(function() {
    tryCatch(
      print(dbGetQuery(.GlobalEnv$conn, "SELECT pg_sleep(3)")),
      error = identity
    )
  })

  session$poll_process(500)
  expect_null(session$read())

  session$interrupt()

  # Should take much less than 1.7 seconds
  time <- system.time(
    expect_equal(session$poll_process(3000), "ready")
  )
  expect_lt(time[["elapsed"]], 1.5)

  local_edition(3)

  # Should return a proper error message
  out <- session$read()
  out$message <- NULL
  out$stderr <- gsub("\r\n", "", out$stderr)

  expect_snapshot({
    out
  })

  session$close()
})
