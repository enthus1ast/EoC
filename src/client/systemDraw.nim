import typesClient
import netlib
import assetLoader
var screenWidth = 800
var screenHeight = 450


proc systemDraw*(gclient: GClient) =
  # var testSprite: Texture2D = loadTexture(getAppDir() / "assets/img/test.png")
  beginDrawing()
  # echo gclient.circle.position
  for idx, msg in enumerate(gclient.serverMessages):
    drawText( $msg , 0, 0 + ((screenHeight div 2) + (15 * idx)), 10, Darkgray)

  case gclient.clientState
  of MAIN_MENU:
    clearBackground(Yellow)
    # if (GuiTextBox((Rectangle){ 25, 215, 125, 30 }, textBoxText, 64, textBoxEditMode)) textBoxEditMode = !textBoxEditMode;
    # proc textBox*(bounds: Rectangle; text: cstring; textSize: cint; editMode: bool): bool
    # var text: cstring
    # if text.isNil:
    #   text = newString(512)
    if textBox(Rectangle(x: 10, y:10, width:150, height:30), gclient.txtServer , textSize = 512, editMode = true):
      echo "TEXT BOX:", gclient.txtServer

    var btnConnect = button(Rectangle(x: 10, y:50, width:50, height:30), "Connect")
    if btnConnect:
      echo "CONNECT"
      gclient.connect($gclient.txtServer)
  of CONNECTING:
    clearBackground(Red)
    let text = fmt"Connecting to server: {gclient.txtServer}"
    drawText(text, 10, 10, 20, Black)
  of MAP:
    beginMode2D gclient.camera
    gclient.camera.target = gclient.myPlayer().pos
    let curTime = getMonoTime()
    clearBackground(Raywhite)

    # Draw some testimages
    for idxy in 0..50:
      for idxx in 0..50:
        drawTexture(
          gclient.assets.textures["assets/img/test.png"],
          0 + (idxx * 32),
          0 + (idxy * 32),
          White
        )

    let mousePos = getMousePosition()
    # drawCircle(playerPos.x.int, playerPos.y.int, 5, LIGHTGRAY)
    drawCircle(mousePos.x.int, mousePos.y.int, 3, RED)
    # draw all other players
    for id, player in gclient.players:
      if id == gclient.myPlayerId:
        ## This is us, we can draw us directly
        drawText($player.id, player.pos.x.int - 20 , player.pos.y.int - 20 , 10, Blue)
        drawCircle(player.pos.x.int, player.pos.y.int, 5, RED)
      else:
        ## these are others, more logic apply
        try:
          ## We must interpolate between the `oldpos` and the `newpos`
          let dif = (curTime - player.lastmove).inMilliseconds.int.clamp(0, 50_000)
          let serverTickTime = calculateFrameTime(gclient.targetServerFps) # TODO ~5fps
          let percent = dif / serverTickTime
          # print (curTime - player.lastmove).inMilliseconds, dif, percent
          let moveVec = player.pos - player.oldpos

          let interpolated =  player.oldpos + (moveVec * percent)

          drawText($player.id, interpolated.x.int - 20, interpolated.y.int - 20 , 10, Darkgray)
          drawCircle(interpolated.x.int, interpolated.y.int, 5, RED)
        except:
          echo getCurrentExceptionMsg()
      # print dif


    endMode2D()



    # drawText("FRAME SPEED: ", 165, 210, 10, Darkgray)
    drawText("FPS: " & $getFPS() , 0, getScreenHeight() - 10, 10, Darkgray)
    drawText("Unacknowledged moves: " & $gclient.moves.len , 10, 10, 10, Darkgray)
  endDrawing()