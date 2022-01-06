import norm/[model, sqlite]

type
  Database* = object
    conn*: DbConn