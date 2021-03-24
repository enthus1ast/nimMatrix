import json, sets, strutils
import matrixClient

from credentials import USERNAME, PASSWORD # For testing (not in git)

when isMainModule:
  import os
  var matrix = newMatrix("https://matrix.code0.xyz")
  # echo matrix.logout()
  # echo matrix.whoami()
  echo matrix.login(USERNAME, PASSWORD)
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
  matrix.sync().dummyMsgList(processed) #.pretty()

  let roomAlias = "#testroom:matrix.code0.xyz"
  echo matrix.roomResolve(roomAlias)
  let roomId = matrix.roomResolve(roomAlias)["room_id"].getStr()

  # matrix.roomSend("#testroom:matrix.code0.xyz", "m.room.message", {
  #   "msgtype": "m.text",
  #   "body": "Test"
  # })
  # echo matrix.roomSend(roomId, "m.room.message", %* {
  #   "msgtype": "m.text",
  #   "body": "Test"
  # })
  # echo matrix.roomSend("!ZPFhGDZNKYsRPjkUmj:matrix.code0.xyz", "m.room.message", %* {
  #   "msgtype": "m.text",
  #   "body": "Test2"
  # })

  while true:
    # discard stdin.readLine()
    # echo matrix.sync().pretty()
    echo "."
    for event in matrix.events()["chunk"].getElems(): #.dummyMsgList(processed) #.pretty()
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
    # sleep(5000)
  echo matrix.logout()

# let response = client.request(b"/_matrix/client/r0/login", httpMethod = HttpPost, body = $body)
# echo response.status
# echo response.body