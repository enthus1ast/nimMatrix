import httpclient, json, strformat, uri, strutils, oids, tables

type Matrix = ref object
  http: HttpClient
  server: string
  userId: string
  accessToken: string
  deviceId: string
  filterId: string
  resolvedRooms: Table[string, string]

proc randomId(): string =
  $genOid()

proc req(matrix: Matrix, httpMethod: HttpMethod, api, body: string | JsonNode ): Response =
  matrix.http.headers = newHttpHeaders({
    "Content-Type": "application/json",
    "Authorization": fmt"Bearer {matrix.accessToken}",
    # "DeviceId": matrix.deviceId
  })
  result = matrix.http.request(
    matrix.server & api,
    httpMethod,
    when body is JsonNode:
      $body
    else:
      body
  )
  echo result.status
  # echo result.status
  # echo result.body

func identifiertToUsername*(str: string): string =
  ## @sn0re:matrix.code0.xyz --> sn0re
  if str.startsWith("@"):
    return str[1 .. ^1].split(":", 1)[0]

proc newMatrix*(server: string): Matrix =
  result = Matrix()
  result.http = newHttpClient()
  result.server = server

proc login*(matrix: Matrix, username, password: string): bool =
  let resp = matrix.req(HttpPost, "/_matrix/client/r0/login"):
    %* {
      "type": "m.login.password",
      "identifier": {
        "type": "m.id.user",
        "user": username
      },
      "password": password
      # "initial_device_display_name": "hihihi bot"
    }
  let js =
    try:
      resp.body.parseJson()
    except:
      return false
  matrix.accessToken = js["access_token"].getStr()
  matrix.deviceId = js["device_id"].getStr()
  return resp.code == Http200

proc logout*(matrix: Matrix): bool =
  let resp = matrix.req(HttpPost, "/_matrix/client/r0/logout", "")
  return resp.code == Http200

proc whoami*(matrix: Matrix): JsonNode =
  let resp = matrix.req(HttpGet, "/_matrix/client/r0/account/whoami", "")
  return resp.body.parseJson()

proc sync*(matrix: Matrix): JsonNode =
  let resp = matrix.req(HttpGet, "/_matrix/client/r0/sync", "")
  return resp.body.parseJson()

proc events*(matrix: Matrix): JsonNode =
  let resp = matrix.req(HttpGet, "/_matrix/client/r0/events", "")
  return resp.body.parseJson()

proc joinedRooms*(matrix: Matrix): JsonNode =
  let resp = matrix.req(HttpGet, "/_matrix/client/r0/joined_rooms", "")
  return resp.body.parseJson()

proc joinRoomIdOrAlias*(matrix: Matrix, roomIdOrAlias: string): JsonNode =
  let resp = matrix.req(HttpPost, "/_matrix/client/r0/join/" & roomIdOrAlias.encodeUrl(), "")
  return resp.body.parseJson()

proc roomResolve*(matrix: Matrix, roomAlias: string): JsonNode =
  let resp = matrix.req(HttpGet, fmt"/_matrix/client/r0/directory/room/{roomAlias.encodeUrl()}", "")
  return resp.body.parseJson()

# proc roomSend(matrix: Matrix, roomId: string, messageType: string, content: openArray[(string, string)]) =
proc roomSend*(matrix: Matrix, roomId: string, messageType: string, content: JsonNode): JsonNode =
  let resp = matrix.req(
    HttpPut,
    fmt"/_matrix/client/r0/rooms/{roomId.encodeUrl()}/send/m.room.message/{randomId()}", $content)
  return resp.body.parseJson()

##############################################################################
# Some (dummy) debugging procs, will be removed later
##############################################################################
import sets
proc formatMsg*(event: JsonNode) =
  if event["type"].getStr() == "m.room.message":
    let sender = event["sender"].getStr().identifiertToUsername()
    let time = event["origin_server_ts"].getStr()
    let body = event["content"]["body"].getStr()
    echo fmt" {sender} {time} '{body}'"
  else:
    echo event

proc dummyMsgList*(js: JsonNode, processed: var HashSet[string]) =
  # "rooms": {
  #   "join": {
  #     "!ZPFhGDZNKYsRPjkUmj:matrix.code0.xyz": {
  #       "timeline": {
  #         "events": [
  for event in js["rooms"]["join"]["!ZPFhGDZNKYsRPjkUmj:matrix.code0.xyz"]["timeline"]["events"].getElems():
    let eventId = event["event_id"].getStr()
    if processed.contains eventId: continue
    processed.incl eventId
    formatMsg(event)

when isMainModule:
  import unittest
  suite "matrix":
    test "ident converter":
      check identifiertToUsername("@sn0re:matrix.code0.xyz") == "sn0re"