import times, strformat
type
  ChatMsg* = object
    sender*: string
    timestamp*: DateTime
    data*: string
  Chatbox* = object
    msgs: seq[ChatMsg]
    max: int


proc newChatbox*(max: int = 10): Chatbox =
  result.msgs = @[]
  result.max = max

proc add*(chatbox: var Chatbox, data: string, sender: string = "server") =
  chatbox.msgs.add ChatMsg(sender: sender, data: data, timestamp: now())
  if chatbox.msgs.len > chatbox.max:
    chatbox.msgs.delete(0)

iterator items*(chatbox: Chatbox): ChatMsg =
  for msg in chatbox.msgs:
    yield msg

proc `$`*(msg: ChatMsg): string =
  return fmt"""<{msg.timestamp.format("yy-MM-dd hh:mm:ss")}> {msg.sender}: {msg.data}"""

when isMainModule:
  var cb = newChatbox(3)
  cb.add("1")
  cb.add("2")
  cb.add("3")
  cb.add("4")
  for msg in cb:
    echo msg