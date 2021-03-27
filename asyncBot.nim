import json, sets, strutils
import matrixClient, asyncdispatch

from credentials import USERNAME, PASSWORD # For testing (not in git)

proc main() {.async.} =
  var matrix = newAsyncMatrix("https://matrix.code0.xyz")
  if not (await matrix.isLogin(USERNAME, PASSWORD)):
    echo "Bot cannot log in. Abort."
    quit()
  echo await matrix.whoami()
  echo await matrix.joinedRooms()
  echo await matrix.joinRoomIdOrAlias("#testroom:matrix.code0.xyz")
  echo await matrix.joinRoomIdOrAlias("!JyrqzRzscGrjGVHkil:matrix.code0.xyz") # directchat with sn0re
  echo await matrix.roomSend("!JyrqzRzscGrjGVHkil:matrix.code0.xyz", "m.room.notice", %* {
    "msgtype": "m.text",
    "body":  "hi sn0re"
  })

  echo await matrix.joinedRooms()

  var processed: HashSet[string]
  (await matrix.sync()).dummyMsgList(processed)

  let roomAlias = "#testroom:matrix.code0.xyz"
  echo (await matrix.roomResolve(roomAlias))
  let roomId = (await matrix.roomResolve(roomAlias)).room_id

  while true:
    for event in (await matrix.events())["chunk"].getElems():
      formatMsg(event)

      if event["type"].getStr() == "m.room.message":
        let sender = event["sender"].getStr().identifiertToUsername()
        let time = event["origin_server_ts"].getStr()
        let body = event["content"]["body"].getStr().strip()
        if body.startsWith("!"):
          echo "BODY FOR ME!!"
          if body == "!help":
            echo await matrix.roomSend(roomId, "m.room.notice", %* {
              "msgtype": "m.text",
              "body":  "ich kann noch nix :D"
            })
          else:
            echo await matrix.roomSend(roomId, "m.room.notice", %* {
              "msgtype": "m.text",
              "body":  "was willst du von mir???\nIch versteh: '" & body & "' net!"
            })
  echo await matrix.logout()

waitFor main()
