import json, sets, strutils
import matrixClient

from credentials import USERNAME, PASSWORD # For testing (not in git)

when isMainModule:
  import os
  var matrix = newMatrix("https://matrix.code0.xyz")
  if not matrix.isLogin(USERNAME, PASSWORD):
    echo "Bot cannot log in. Abort."
    quit()
  echo matrix.whoami()
  echo matrix.joinedRooms()
  echo matrix.joinRoomIdOrAlias("#testroom:matrix.code0.xyz")
  echo matrix.joinRoomIdOrAlias("!JyrqzRzscGrjGVHkil:matrix.code0.xyz") # directchat with sn0re
  echo matrix.roomSend("!JyrqzRzscGrjGVHkil:matrix.code0.xyz", "m.room.notice", %* {
    "msgtype": "m.text",
    "body":  "hi sn0re"
  })

  echo matrix.joinedRooms()

  var processed: HashSet[string]
  matrix.sync().dummyMsgList(processed)

  let roomAlias = "#testroom:matrix.code0.xyz"
  echo matrix.roomResolve(roomAlias)
  let roomId = matrix.roomResolve(roomAlias).room_id

  let contentUri = matrix.uploadFile("testfile.txt", "CONTENT", "text/plain")
  echo contentUri.toDownloadUri()


  while true:
    echo "."
    for event in matrix.events()["chunk"].getElems():
      formatMsg(event)

      if event["type"].getStr() == "m.room.message":
        let sender = event["sender"].getStr().identifiertToUsername()
        let time = event["origin_server_ts"].getStr()
        let body = event["content"]["body"].getStr().strip()
        if body.startsWith("!"):
          echo "BODY FOR ME!!"
          if body == "!help":
            echo matrix.roomSend(roomId, "m.room.notice", %* {
              "msgtype": "m.text",
              "body":  "ich kann noch nix :D"
            })
          else:
            echo matrix.roomSend(roomId, "m.room.notice", %* {
              "msgtype": "m.text",
              "body":  "was willst du von mir???\nIch versteh: '" & body & "' net!"
            })
  echo matrix.logout()