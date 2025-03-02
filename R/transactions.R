#' Transaction management.
#'
#' `dbBegin()` starts a transaction. `dbCommit()` and `dbRollback()`
#' end the transaction by either committing or rolling back the changes.
#'
#' @param conn a [PqConnection-class] object, produced by
#'   [DBI::dbConnect()]
#' @param ... Unused, for extensibility.
#' @return A boolean, indicating success or failure.
#' @examplesIf postgresHasDefault()
#' library(DBI)
#' con <- dbConnect(RPostgres::Postgres())
#' dbWriteTable(con, "USarrests", datasets::USArrests, temporary = TRUE)
#' dbGetQuery(con, 'SELECT count(*) from "USarrests"')
#'
#' dbBegin(con)
#' dbExecute(con, 'DELETE from "USarrests" WHERE "Murder" > 1')
#' dbGetQuery(con, 'SELECT count(*) from "USarrests"')
#' dbRollback(con)
#'
#' # Rolling back changes leads to original count
#' dbGetQuery(con, 'SELECT count(*) from "USarrests"')
#'
#' dbRemoveTable(con, "USarrests")
#' dbDisconnect(con)
#' @name postgres-transactions
NULL

#' @export
#' @param name If provided, uses the `SAVEPOINT` SQL syntax
#'   to establish, remove (commit) or undo a ßsavepoint.
#' @rdname postgres-transactions
setMethod("dbBegin", "PqConnection", function(conn, ..., name = NULL) {
  if (is.null(name)) {
    if (connection_is_transacting(conn@ptr)) {
      stop("Nested transactions not supported.", call. = FALSE)
    }
    dbExecute(conn, "BEGIN")
    connection_set_transacting(conn@ptr, TRUE)
  } else {
    if (!connection_is_transacting(conn@ptr)) {
      stop("Savepoints require an active transaction.", call. = FALSE)
    }
    dbExecute(conn, paste0("SAVEPOINT ", dbQuoteIdentifier(conn, name)))
  }
  invisible(TRUE)
})

#' @export
#' @rdname postgres-transactions
setMethod("dbCommit", "PqConnection", function(conn, ..., name = NULL) {
  if (is.null(name)) {
    if (!connection_is_transacting(conn@ptr)) {
      stop("Call dbBegin() to start a transaction.", call. = FALSE)
    }
    dbExecute(conn, "COMMIT")
    connection_set_transacting(conn@ptr, FALSE)
  } else {
    dbExecute(conn, paste0("RELEASE SAVEPOINT ", dbQuoteIdentifier(conn, name)))
  }
  invisible(TRUE)
})

#' @export
#' @rdname postgres-transactions
setMethod("dbRollback", "PqConnection", function(conn, ..., name = NULL) {
  if (is.null(name)) {
    if (!connection_is_transacting(conn@ptr)) {
      stop("Call dbBegin() to start a transaction.", call. = FALSE)
    }
    dbExecute(conn, "ROLLBACK")
    connection_set_transacting(conn@ptr, FALSE)
  } else {
    name_quoted <- dbQuoteIdentifier(conn, name)
    dbExecute(conn, paste0("ROLLBACK TO ", name_quoted))
    dbExecute(conn, paste0("RELEASE SAVEPOINT ", name_quoted))
  }
  invisible(TRUE)
})
