#[
  This is the database abstraction for the server.
]#
import norm
import typesDatabase

const DBFILE = "test.sqlite"

proc newDatabase*(): Database =
  result = Database()
  result.conn = open(DBFILE, "", "", "")

proc init(db: Database): bool =
  return false

