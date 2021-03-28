import httpclient, json, strformat, uri, strutils, oids, tables, asyncdispatch, mimetypes, os, asyncfile

const DEBUG = true
let  mimedb = newMimetypes()

type
  MatrixBase = ref object of RootObj
    server: string
    userId: string
    accessToken: string
    deviceId: string
    filterId: string
    resolvedRooms: Table[string, string]
  Matrix* = ref object of MatrixBase ## The sync client
    http*: HttpClient
  AsyncMatrix* = ref object of MatrixBase ## The async client
    http*: AsyncHttpClient
  EventHandlerBase = object of RootObj
  EventHandler* = object of EventHandlerBase
    matrix: Matrix
  AsyncEventHandler* = object of EventHandlerBase
    matrix: AsyncMatrix



type
  MatrixError = object of ValueError
    errcode: string
  RespRoomResolve* = object
    room_id*: string
    servers*: seq[string]
  RespLogin* = object
    user_id*: string
    access_token*: string
    home_server*: string
    device_id*: string
  RespWhoami* = object
    user_id*: string #{"user_id":"@hihihi:matrix.code0.xyz"}
  RespJoinedRooms* = object
    joined_rooms*: seq[string] # {"joined_rooms":["!JyrqzRzscGrjGVHkil:matrix.code0.xyz","!FbOAezePNyqTzEAKSx:matrix.code0.xyz","!ZPFhGDZNKYsRPjkUmj:matrix.code0.xyz"]}
  RespJoinRoomIdOrAlias* = object
    room_id*: string # {"room_id":"!JyrqzRzscGrjGVHkil:matrix.code0.xyz"}
  RespRoomSend* = object
    event_id*: string # {"event_id":"$mNzd-QYHgIBPs-b03s7kNkPYbqhlxA9LdQB3axhkbKM"}
  RespSync* = object ## RespSync is a complex response, most of it will still be JsonNode, (TODO ; PRs welcome)
    account_data*: JsonNode #	{…}
    to_device*: JsonNode #	{…}
    device_lists*: JsonNode #	{…}
    presence*: JsonNode #	{…}
    rooms*: JsonNode #	{…}
    groups*: JsonNode #{…}
    device_one_time_keys_count*: JsonNode #	{}
    #org.matrix.msc2732.device_unused_fallback_key_types	[]
    next_batch*: string #	"s9521_103773_12780_8669_17358_22_4270_343_2"
  RespEvents* = object ## Like RespSync, RespEvents also is a complex response, most is JsonNode (TODO; PRs welcome)
    `type`*: string ## TODO `type` is ugly
    room_id*: string
    sender*: string
    content*: JsonNode
    origin_server_ts: int
  RespUploadFile* = object
    content_uri*: string

proc randomId(): string =
  $genOid()

proc req(matrix: Matrix | AsyncMatrix, httpMethod: HttpMethod, api, body: string | JsonNode, headers = newHttpHeaders()): Future[Response | AsyncResponse] {.multisync.} =
  matrix.http.headers = newHttpHeaders({
    "Content-Type": "application/json",
    "Authorization": fmt"Bearer {matrix.accessToken}",
    # "DeviceId": matrix.deviceId
  })
  # Overwrite the default headers with supplied headers
  for key, header in headers.pairs:
    matrix.http.headers[key] = header
  let uri = matrix.server & api
  when DEBUG:
    echo "==============================================="
    echo "REQ URI: ", uri
    echo "HEADERS: ", matrix.http.headers
    echo "REQBODY: ", body
    echo "---"
  result = await matrix.http.request(
    uri,
    httpMethod,
    when body is JsonNode:
      $body
    else:
      body
  )
  when DEBUG:
    echo "RESULT:", result.status
    echo "RESULT BODY: \n", (await result.body)
  if result.code != Http200:
    var errorJs: JsonNode
    try:
      errorJs = (await result.body).parseJson()
    except:
      raise newException(MatrixError, "unknown error:" & (await result.body))
    var ex = newException(MatrixError, errorJs["error"].getStr())
    ex.errcode = errorJs["errcode"].getStr()
    raise ex

func identifiertToUsername*(str: string): string =
  ## @myUserName:matrix.code0.xyz --> myUserName
  if str.startsWith("@"):
    return str[1 .. ^1].split(":", 1)[0]

proc newMatrix*(server: string): Matrix =
  result = Matrix()
  result.http = newHttpClient()
  result.server = server

proc newAsyncMatrix*(server: string): AsyncMatrix =
  result = AsyncMatrix()
  result.http = newAsyncHttpClient()
  result.server = server

proc login*(matrix: Matrix | AsyncMatrix, username, password: string): Future[RespLogin] {.multisync.} =
  let respFut = matrix.req(HttpPost, "/_matrix/client/r0/login"):
    %* {
      "type": "m.login.password",
      "identifier": {
        "type": "m.id.user",
        "user": username
      },
      "password": password
      # "initial_device_display_name": "hihihi bot"
    }
  let resp = await respFut
  echo repr resp
  echo await resp.body
  result = (await resp.body).parseJson().to(RespLogin)
  matrix.accessToken = result.access_token
  matrix.deviceId = result.device_id

proc isLogin*(matrix: Matrix | AsyncMatrix, username, password: string): Future[bool] {.multisync.} =
  ## like `login()`, but returns `true` or `false` instead of Json
  try:
    discard await matrix.login(username, password)
    return true
  except:
    echo getCurrentExceptionMsg()
    return false

proc logout*(matrix: Matrix | AsyncMatrix): Future[bool] {.multisync.} =
  let resp = await matrix.req(HttpPost, "/_matrix/client/r0/logout", "")
  return resp.code == Http200

proc whoami*(matrix: Matrix | AsyncMatrix): Future[RespWhoami] {.multisync.} =
  let resp = await matrix.req(HttpGet, "/_matrix/client/r0/account/whoami", "")
  return (await resp.body).parseJson().to(RespWhoami)

proc sync*(matrix: Matrix | AsyncMatrix): Future[RespSync] {.multisync.} =
  let resp = await matrix.req(HttpGet, "/_matrix/client/r0/sync", "")
  return (await resp.body).parseJson().to(RespSync)

proc events*(matrix: Matrix | AsyncMatrix): Future[JsonNode] {.multisync.} =
  let resp = await matrix.req(HttpGet, "/_matrix/client/r0/events", "")
  return (await resp.body).parseJson()

proc joinedRooms*(matrix: Matrix | AsyncMatrix): Future[RespJoinedRooms] {.multisync.} =
  let resp = await matrix.req(HttpGet, "/_matrix/client/r0/joined_rooms", "")
  return (await resp.body).parseJson().to(RespJoinedRooms)

proc joinRoomIdOrAlias*(matrix: Matrix | AsyncMatrix, roomIdOrAlias: string): Future[RespJoinRoomIdOrAlias] {.multisync.} =
  let resp = await matrix.req(HttpPost, "/_matrix/client/r0/join/" & roomIdOrAlias.encodeUrl(), "")
  return (await resp.body).parseJson().to(RespJoinRoomIdOrAlias)

proc roomResolve*(matrix: Matrix | AsyncMatrix, roomAlias: string): Future[RespRoomResolve] {.multisync.} =
  let resp = await matrix.req(HttpGet, fmt"/_matrix/client/r0/directory/room/{roomAlias.encodeUrl()}", "")
  return (await resp.body).parseJson().to(RespRoomResolve)

proc roomSend*(matrix: Matrix | AsyncMatrix, roomId: string, messageType: string, content: JsonNode): Future[RespRoomSend] {.multisync.} =
  let resp = await matrix.req(
    HttpPut,
    fmt"/_matrix/client/r0/rooms/{roomId.encodeUrl()}/send/m.room.message/{randomId()}", $content)
  return (await resp.body).parseJson().to(RespRoomSend)

proc toDownloadUri*(respUploadFile: RespUploadFile | string, scheme = "https", hostname = ""): string =
  ## If host == "", the host will be extracted from the content_uri
  when respUploadFile is string:
    let url = parseUri(respUploadFile)
  else:
    let url = parseUri(respUploadFile.content_uri)
  if url.scheme != "mxc": raise newException(ValueError, "unknown media id (only support mxc)")
  var res: Uri
  res.scheme = scheme
  if hostname == "":
    res.hostname = url.hostname
  else:
    res.hostname = hostname
  res.path = fmt"/_matrix/media/r0/download/{url.hostname}{url.path}"
  return $res

proc uploadFile*(matrix: Matrix | AsyncMatrix, filename, content, mimeType: string): Future[RespUploadFile] {.multisync.} =
  ## Uploads a file to the content repository.
  ## This returns a content uri which can later be posted as a message.
  ## TODO no uploadFile proc streams the data!
  var headers = newHttpHeaders()
  headers["Content-Type"] = mimeType
  let resp = await matrix.req(HttpPost, fmt"/_matrix/media/r0/upload?filename={filename.encodeUrl()}", content, headers)
  return (await resp.body).parseJson().to(RespUploadFile)

proc uploadFile*(matrix: Matrix | AsyncMatrix, path: string): Future[RespUploadFile] {.multisync.} =
  if not fileExists(path): raise newException(OSError, "file does not exists:" & path)
  let (dir, name, ext) = splitFile(path)
  let mimeType = mimedb.getMimetype(ext)
  when matrix is Matrix:
    let content = readFile(path) # TODO async file
  else:
    let afh = openAsync(path, fmRead)
    let content = await afh.readAll()
  return await matrix.uploadFile(name & ext, content, mimeType)

proc uploadFile*(matrix: Matrix | AsyncMatrix, fh: File | AsyncFile, filename, mimeType: string): Future[RespUploadFile] {.multisync.} =
  let content = await fh.readAll() # TODO async file
  return await matrix.uploadFile(filename, content, mimeType)

# proc downloadFile*(matrix: Matrix | AsyncMatrix, )

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

proc dummyMsgList*(js: RespSync, processed: var HashSet[string]) =
  # "rooms": {
  #   "join": {
  #     "!ZPFhGDZNKYsRPjkUmj:matrix.code0.xyz": {
  #       "timeline": {
  #         "events": [
  for event in js.rooms["join"]["!ZPFhGDZNKYsRPjkUmj:matrix.code0.xyz"]["timeline"]["events"].getElems():
    let eventId = event["event_id"].getStr()
    if processed.contains eventId: continue
    processed.incl eventId
    formatMsg(event)

when isMainModule:
  import unittest
  suite "matrix":
    test "ident converter":
      check identifiertToUsername("@myUserName:matrix.code0.xyz") == "myUserName"