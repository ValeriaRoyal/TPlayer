-- TPlayer v2.0 - Album Browser + Track List + Now Playing

local musicDir = "music"
local screen = "albums"
local albums = {}
local currentAlbum = 1
local albumScroll = 0
local tracks = {}
local currentTrack = 1
local trackScroll = 0
local source = nil
local isPlaying = false
local coverImage = nil
local defaultCover = nil
local coverScale = 1
local targetScale = 1
local transitionAlpha = 1
local isTransitioning = false
local transitionTimer = 0
local currentTitle = ""
local currentArtist = ""
local bgColor = {0.05, 0.06, 0.10}
local targetBgColor = {0.05, 0.06, 0.10}
local gradientShader
local gamepad = nil
local inputCooldown = 0.15
local inputTimer = 0
local controlsLocked = false
local quitting = false
local shuffleMode = false
local repeatMode = 0
local abState = 0 -- 0=off, 1=A set, 2=A-B active
local pointA = 0
local pointB = 0
local shuffleOrder = {}
local shuffleIndex = 1
local showModeTimer = 0
local modeText = ""
local titleScrollX = 0
local titleScrollTimer = 0
local titleScrolling = false
local titleTextWidth = 0
local playIcon, pauseIcon, batteryIcon, lockIcon, unlockIcon
local fontLarge, fontSmall, fontTiny
local albumCovers = {}
local VISIBLE = 7

function scanLibrary()
    albums = {}
    local items = love.filesystem.getDirectoryItems(musicDir)
    table.sort(items)
    for _, item in ipairs(items) do
        local path = musicDir .. "/" .. item
        local info = love.filesystem.getInfo(path)
        if info and info.type == "directory" then
            local t = {}
            local files = love.filesystem.getDirectoryItems(path)
            table.sort(files)
            for _, f in ipairs(files) do
                if f:match("%.mp3$") or f:match("%.ogg$") or f:match("%.flac$") then
                    table.insert(t, f)
                end
            end
            if #t > 0 then
                table.insert(albums, {name=item, path=path, tracks=t, count=#t})
            end
        end
    end
end

function getAlbumCover(idx)
    if albumCovers[idx] then return albumCovers[idx] end
    local a = albums[idx]
    if not a then albumCovers[idx] = {img=defaultCover}; return albumCovers[idx] end
    for _, name in ipairs({"cover.jpg","cover.png","folder.jpg"}) do
        local p = a.path .. "/" .. name
        if love.filesystem.getInfo(p) then
            local ok, d = pcall(love.image.newImageData, p)
            if ok and d then
                albumCovers[idx] = {img=love.graphics.newImage(d), data=d}
                return albumCovers[idx]
            end
        end
    end
    albumCovers[idx] = {img=defaultCover}
    return albumCovers[idx]
end

local function extractColor(d)
    if not d then return 0.05, 0.06, 0.10 end
    local w,h = d:getWidth(), d:getHeight()
    local r,g,b,n = 0,0,0,0
    for y=0,h-1,10 do for x=0,w-1,10 do
        local pr,pg,pb = d:getPixel(x,y)
        r=r+pr; g=g+pg; b=b+pb; n=n+1
    end end
    if n==0 then return 0.05,0.06,0.10 end
    r,g,b = r/n, g/n, b/n
    local mx = math.max(r,g,b,0.01)
    local bo = math.max(0.35/mx, 1.0)
    return math.min(r*bo,0.45), math.min(g*bo,0.45), math.min(b*bo,0.45)
end

local function sanitize(s)
    if not s then return nil end
    s = s:gsub("[^\32-\126]",""):match("^%s*(.-)%s*$")
    return s ~= "" and s or nil
end

function readID3v2(path)
    local f = love.filesystem.newFile(path,"r")
    if not f then return nil end
    f:open("r")
    local h = f:read(10)
    if not h or h:sub(1,3) ~= "ID3" then f:close(); return nil end
    local sz = h:byte(7)*2097152+h:byte(8)*16384+h:byte(9)*128+h:byte(10)
    local data = f:read(sz)
    f:close()
    if not data then return nil end
    local pos,md = 1,{}
    while pos < #data do
        local id = data:sub(pos,pos+3)
        local fs = data:byte(pos+4)*16777216+data:byte(pos+5)*65536+data:byte(pos+6)*256+data:byte(pos+7)
        if fs <= 0 then break end
        local fd = data:sub(pos+10,pos+9+fs)
        if id=="TIT2" then
            local t = fd:sub(2); if fd:byte(1)==1 or fd:byte(1)==2 then t=t:gsub("%z","") end
            md.title = sanitize(t)
        elseif id=="TPE1" then
            local t = fd:sub(2); if fd:byte(1)==1 or fd:byte(1)==2 then t=t:gsub("%z","") end
            md.artist = sanitize(t)
        end
        pos = pos+10+fs
    end
    return (md.title or md.artist) and md or nil
end

function loadAlbumTracks(idx)
    local a = albums[idx]
    if not a then return end
    tracks = {}
    for _, f in ipairs(a.tracks) do
        table.insert(tracks, {file=f, path=a.path.."/"..f, name=f:gsub("%.%w+$","")})
    end
    currentTrack = 1
    trackScroll = 0
end

function playTrack(idx)
    if source then source:stop() end
    abState = 0; pointA = 0; pointB = 0
    isTransitioning = true; transitionAlpha = 0; transitionTimer = 0
    titleScrollX = 0; titleScrollTimer = 0; titleScrolling = false

    local t = tracks[idx]
    local ok, src = pcall(love.audio.newSource, t.path, "stream")
    if not ok or not src then
        currentTitle = "Error: " .. t.name
        currentArtist = ""; return
    end
    source = src; source:setLooping(false)

    local md = readID3v2(t.path)
    currentTitle = (md and md.title) or t.name
    currentArtist = (md and md.artist) or albums[currentAlbum].name

    local c = getAlbumCover(currentAlbum)
    coverImage = c.img
    local r,g,b = extractColor(c.data)
    targetBgColor = {r,g,b}

    titleTextWidth = fontLarge:getWidth(currentTitle)
    source:play(); isPlaying = true; screen = "playing"
end

function buildShuffle()
    shuffleOrder = {}
    for i=1,#tracks do shuffleOrder[i]=i end
    for i=#shuffleOrder,2,-1 do
        local j=math.random(1,i)
        shuffleOrder[i],shuffleOrder[j]=shuffleOrder[j],shuffleOrder[i]
    end
    shuffleIndex = 1
end

function love.load()
    love.window.setTitle("TPlayer v2")
    love.window.setMode(640,480)
    math.randomseed(os.time())
    fontLarge = love.graphics.newFont(24)
    fontSmall = love.graphics.newFont(16)
    fontTiny = love.graphics.newFont(12)
    defaultCover = love.graphics.newImage("cover_default.png")
    playIcon = love.graphics.newImage("play_btn.png")
    pauseIcon = love.graphics.newImage("pause_btn.png")
    batteryIcon = love.graphics.newImage("battery.png")
    lockIcon = love.graphics.newImage("icon_lock.png")
    unlockIcon = love.graphics.newImage("icon_unlock.png")
    gradientShader = love.graphics.newShader([[
        extern vec3 topColor; extern vec3 bottomColor;
        vec4 effect(vec4 c, Image t, vec2 tc, vec2 sc) {
            return vec4(mix(topColor, bottomColor, sc.y/love_ScreenSize.y), 1.0);
        }
    ]])
    scanLibrary()
end

function love.quit()
    if source then source:stop() end
    love.audio.stop()
    return false
end

function love.update(dt)
    local js = love.joystick.getJoysticks()
    gamepad = js[1]
    if not gamepad then return end
    inputTimer = inputTimer + dt

    if quitting then
        if source then source:stop() end
        love.audio.stop(); love.event.quit(); return
    end

    if gamepad:isGamepadDown("back") and gamepad:isGamepadDown("rightshoulder") then
        if inputTimer >= inputCooldown then controlsLocked = not controlsLocked; inputTimer = 0 end
        return
    end
    if controlsLocked then return end

    if inputTimer >= inputCooldown then
        if gamepad:isGamepadDown("start") and gamepad:isGamepadDown("back") then
            quitting = true; inputTimer = 0; return
        end
        if screen == "albums" then
            if gamepad:isGamepadDown("dpdown") then
                currentAlbum = math.min(currentAlbum+1, #albums)
                if currentAlbum > albumScroll+VISIBLE then albumScroll = currentAlbum-VISIBLE end
                inputTimer = 0
            elseif gamepad:isGamepadDown("dpup") then
                currentAlbum = math.max(currentAlbum-1, 1)
                if currentAlbum <= albumScroll then albumScroll = currentAlbum-1 end
                inputTimer = 0
            elseif gamepad:isGamepadDown("a") and #albums > 0 then
                loadAlbumTracks(currentAlbum); screen = "tracks"; inputTimer = 0
            end
        elseif screen == "tracks" then
            if gamepad:isGamepadDown("dpdown") then
                currentTrack = math.min(currentTrack+1, #tracks)
                if currentTrack > trackScroll+VISIBLE then trackScroll = currentTrack-VISIBLE end
                inputTimer = 0
            elseif gamepad:isGamepadDown("dpup") then
                currentTrack = math.max(currentTrack-1, 1)
                if currentTrack <= trackScroll then trackScroll = currentTrack-1 end
                inputTimer = 0
            elseif gamepad:isGamepadDown("a") and #tracks > 0 then
                playTrack(currentTrack); inputTimer = 0
            elseif gamepad:isGamepadDown("b") then
                screen = "albums"; inputTimer = 0
            end
        elseif screen == "playing" then
            if gamepad:isGamepadDown("a") then
                if source then
                    if isPlaying then source:pause(); isPlaying=false
                    else source:play(); isPlaying=true end
                end
                inputTimer = 0
            elseif gamepad:isGamepadDown("dpright") then
                nextTrack(); inputTimer = 0
            elseif gamepad:isGamepadDown("dpleft") then
                prevTrack(); inputTimer = 0
            elseif gamepad:isGamepadDown("b") then
                screen = "tracks"; inputTimer = 0
            elseif gamepad:isGamepadDown("leftshoulder") then
                shuffleMode = not shuffleMode
                if shuffleMode then buildShuffle() end
                modeText = "Shuffle: "..(shuffleMode and "ON" or "OFF")
                showModeTimer = 2; inputTimer = 0
            elseif gamepad:isGamepadDown("rightshoulder") then
                repeatMode = (repeatMode+1)%3
                modeText = ({"Repeat: OFF","Repeat: One","Repeat: All"})[repeatMode+1]
                showModeTimer = 2; inputTimer = 0
            elseif gamepad:isGamepadDown("y") and source then
                if abState == 0 then
                    pointA = source:tell("seconds")
                    abState = 1
                    modeText = "A: " .. fmt(pointA)
                elseif abState == 1 then
                    pointB = source:tell("seconds")
                    if pointB <= pointA then pointB = pointA + 1 end
                    abState = 2
                    modeText = "A-B: " .. fmt(pointA) .. " - " .. fmt(pointB)
                else
                    abState = 0; pointA = 0; pointB = 0
                    modeText = "A-B: OFF"
                end
                showModeTimer = 2; inputTimer = 0
            end
        end
    end

    -- Analog seek
    if screen=="playing" and source and gamepad then
        local ax = gamepad:getGamepadAxis("leftx")
        if math.abs(ax) > 0.25 then
            local dur = source:getDuration("seconds")
            if dur and dur > 0 then
                source:seek(math.max(0, math.min(source:tell("seconds")+ax*math.abs(ax)*8*dt, dur)))
            end
        end
    end

    if showModeTimer > 0 then showModeTimer = showModeTimer - dt end
    if isTransitioning then
        transitionTimer = transitionTimer + dt
        transitionAlpha = math.min(transitionTimer*2, 1)
        if transitionAlpha >= 1 then isTransitioning = false end
    end
    for i=1,3 do bgColor[i] = bgColor[i]+(targetBgColor[i]-bgColor[i])*dt*2 end
    targetScale = isPlaying and 1.03 or 1
    coverScale = coverScale+(targetScale-coverScale)*dt*5

    if screen=="playing" and titleTextWidth > 600 then
        if not titleScrolling then
            titleScrollTimer = titleScrollTimer+dt
            if titleScrollTimer >= 2 then titleScrolling=true; titleScrollTimer=0 end
        else
            titleScrollX = titleScrollX+40*dt
            if titleScrollX >= titleTextWidth-560 then titleScrolling=false; titleScrollX=0; titleScrollTimer=0 end
        end
    end

    if source and not source:isPlaying() and isPlaying then
        if repeatMode==1 then source:seek(0); source:play()
        else nextTrack() end
    end

    -- A-B repeat loop
    if abState==2 and source and isPlaying then
        if source:tell("seconds") >= pointB then
            source:seek(pointA)
        end
    end
    love.timer.sleep(0.01)
end

function nextTrack()
    if #tracks==0 then return end
    if shuffleMode then
        shuffleIndex = shuffleIndex+1
        if shuffleIndex > #shuffleOrder then
            if repeatMode==0 then isPlaying=false; return end
            buildShuffle()
        end
        currentTrack = shuffleOrder[shuffleIndex]
    else
        currentTrack = currentTrack+1
        if currentTrack > #tracks then
            if repeatMode==0 then currentTrack=#tracks; isPlaying=false; return end
            currentTrack = 1
        end
    end
    playTrack(currentTrack)
end

function prevTrack()
    if #tracks==0 then return end
    if shuffleMode then
        shuffleIndex = shuffleIndex-1
        if shuffleIndex < 1 then shuffleIndex=#shuffleOrder end
        currentTrack = shuffleOrder[shuffleIndex]
    else
        currentTrack = currentTrack-1
        if currentTrack < 1 then currentTrack=#tracks end
    end
    playTrack(currentTrack)
end

function fmt(s) return string.format("%02d:%02d", math.floor(s/60), math.floor(s%60)) end

function love.draw()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setShader(gradientShader)
    gradientShader:send("topColor", bgColor)
    gradientShader:send("bottomColor", {bgColor[1]*0.6, bgColor[2]*0.6, bgColor[3]*0.6})
    love.graphics.rectangle("fill",0,0,w,h)
    love.graphics.setShader()

    if screen=="albums" then drawAlbums(w,h)
    elseif screen=="tracks" then drawTracks(w,h)
    elseif screen=="playing" then drawPlaying(w,h) end

    -- Top bar
    local bx = w-54
    local _,pct = love.system.getPowerInfo()
    local icoSz = 44
    local icoScale = icoSz/batteryIcon:getWidth()

    -- Battery icon
    if pct and pct < 20 then love.graphics.setColor(1,0.3,0.3)
    else love.graphics.setColor(1,1,1,0.9) end
    if batteryIcon then love.graphics.draw(batteryIcon,bx,14,0,icoScale,icoScale) end

    -- Battery text centered on icon
    love.graphics.setColor(1,1,1)
    love.graphics.setFont(fontTiny)
    local bt = pct and (pct.."%") or "--"
    love.graphics.print(bt, bx+icoSz/2-fontTiny:getWidth(bt)/2, 4+icoSz/2-fontTiny:getHeight()/2)

    -- Clock
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(1,1,1,0.9)
    local ct = os.date("%H:%M")
    local timeX = bx-fontSmall:getWidth(ct)-14
    love.graphics.print(ct, timeX, 16)

    -- Lock icon
    local lIcon = controlsLocked and lockIcon or unlockIcon
    if lIcon then
        local ls = 20
        love.graphics.setColor(1,1,1, controlsLocked and 1 or 0.4)
        love.graphics.draw(lIcon, timeX-ls-10, 18, 0, ls/lIcon:getHeight(), ls/lIcon:getHeight())
    end

    -- Mini bar
    if screen~="playing" and source and isPlaying then
        love.graphics.setColor(0,0,0,0.8)
        love.graphics.rectangle("fill",0,h-32,w,32)
        love.graphics.setColor(0.2,0.8,0.5)
        love.graphics.setFont(fontTiny)
        love.graphics.printf("  ♪ "..currentTitle.." - "..currentArtist, 0, h-22, w-10, "left")
    end

    if showModeTimer > 0 then
        love.graphics.setColor(0,0,0,0.7)
        love.graphics.rectangle("fill",w/2-100,h-80,200,40,8,8)
        love.graphics.setColor(1,1,1)
        love.graphics.setFont(fontSmall)
        love.graphics.printf(modeText,0,h-70,w,"center")
    end
end

function drawAlbums(w,h)
    love.graphics.setColor(1,1,1)
    love.graphics.setFont(fontLarge)
    love.graphics.printf("Albums",0,15,w,"center")

    if #albums==0 then
        love.graphics.setFont(fontSmall)
        love.graphics.printf("No albums found.\nAdd folders to tplayer/gui/music/",0,h/2-20,w,"center")
        return
    end

    local y0 = 55
    for i=1,math.min(VISIBLE,#albums) do
        local idx = i+albumScroll
        if idx > #albums then break end
        local a = albums[idx]
        local y = y0+(i-1)*55
        local sel = idx==currentAlbum

        if sel then
            love.graphics.setColor(0.2,0.8,0.5,0.3)
            love.graphics.rectangle("fill",10,y,w-20,50,8,8)
        end

        local cv = getAlbumCover(idx)
        love.graphics.setColor(1,1,1)
        love.graphics.draw(cv.img,20,y+2,0,45/cv.img:getWidth(),45/cv.img:getHeight())

        love.graphics.setColor(1,1,1,sel and 1 or 0.7)
        love.graphics.setFont(fontSmall)
        love.graphics.print(a.name,75,y+5)
        love.graphics.setFont(fontTiny)
        love.graphics.setColor(1,1,1,0.5)
        love.graphics.print(a.count.." tracks",75,y+27)
    end

    love.graphics.setFont(fontTiny)
    love.graphics.setColor(1,1,1,0.4)
    love.graphics.printf("D-Pad: Navigate | A: Open | START+SELECT: Quit",0,h-15,w,"center")
end

function drawTracks(w,h)
    love.graphics.setColor(1,1,1)
    love.graphics.setFont(fontSmall)
    love.graphics.printf(albums[currentAlbum].name,0,15,w,"center")

    local y0 = 45
    for i=1,math.min(VISIBLE+1,#tracks) do
        local idx = i+trackScroll
        if idx > #tracks then break end
        local t = tracks[idx]
        local y = y0+(i-1)*45
        local sel = idx==currentTrack

        if sel then
            love.graphics.setColor(0.2,0.8,0.5,0.3)
            love.graphics.rectangle("fill",10,y,w-20,40,8,8)
        end

        love.graphics.setFont(fontTiny)
        love.graphics.setColor(0.2,0.8,0.5,sel and 1 or 0.5)
        love.graphics.print(string.format("%02d",idx),20,y+12)

        love.graphics.setFont(fontSmall)
        love.graphics.setColor(1,1,1,sel and 1 or 0.7)
        love.graphics.print(t.name:gsub("^%d+%s*%-?%s*",""),50,y+10)
    end

    love.graphics.setFont(fontTiny)
    love.graphics.setColor(1,1,1,0.4)
    love.graphics.printf("D-Pad: Navigate | A: Play | B: Back",0,h-15,w,"center")
end

function drawPlaying(w,h)
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(1,1,1,0.8)
    love.graphics.print(currentTrack.."/"..#tracks,15,15)

    local ind = ""
    if shuffleMode then ind = ind.."SHF " end
    if repeatMode==1 then ind=ind.."RPT1" elseif repeatMode==2 then ind=ind.."RPT" end
    if ind~="" then
        love.graphics.setFont(fontTiny)
        love.graphics.setColor(0.2,0.8,0.5)
        love.graphics.print(ind,15,35)
    end

    if coverImage then
        local cs,cx,cy = 200, w/2-100, 55
        love.graphics.setColor(0,0,0,0.4)
        love.graphics.rectangle("fill",cx+6,cy+6,cs,cs,12,12)
        love.graphics.setColor(1,1,1,transitionAlpha)
        local sf = (cs/coverImage:getWidth())*coverScale
        love.graphics.draw(coverImage,cx+cs/2,cy+cs/2,0,sf,sf,coverImage:getWidth()/2,coverImage:getHeight()/2)

        love.graphics.setFont(fontLarge)
        local ty = cy+cs+15
        if titleTextWidth > w-40 then
            love.graphics.setScissor(20,ty,w-40,fontLarge:getHeight())
            love.graphics.setColor(1,1,1)
            love.graphics.print(currentTitle,20-titleScrollX,ty)
            love.graphics.setScissor()
        else
            love.graphics.setColor(1,1,1)
            love.graphics.printf(currentTitle,0,ty,w,"center")
        end

        love.graphics.setFont(fontSmall)
        love.graphics.setColor(1,1,1,0.8)
        love.graphics.printf(currentArtist,0,ty+30,w,"center")

        local icon = isPlaying and pauseIcon or playIcon
        if icon then
            love.graphics.setColor(1,1,1,0.9)
            love.graphics.draw(icon,w/2-24,ty+55,0,48/icon:getWidth(),48/icon:getWidth())
        end

        if source then
            local cur = source:tell("seconds")
            local dur = source:getDuration("seconds")
            if dur > 0 then
                local bx,by,bw = w/2-200, ty+115, 400
                love.graphics.setColor(0.25,0.25,0.25)
                love.graphics.rectangle("fill",bx,by,bw,8,4,4)
                love.graphics.setColor(0.2,0.8,0.5)
                love.graphics.rectangle("fill",bx,by,bw*(cur/dur),8,4,4)
                -- A-B markers on progress bar
                if abState >= 1 then
                    love.graphics.setColor(1,0.8,0.2)
                    love.graphics.rectangle("fill",bx+bw*(pointA/dur)-1,by-3,3,14)
                end
                if abState == 2 then
                    love.graphics.setColor(1,0.4,0.2)
                    love.graphics.rectangle("fill",bx+bw*(pointB/dur)-1,by-3,3,14)
                end
                love.graphics.setColor(1,1,1)
                love.graphics.setFont(fontTiny)
                local timeText = fmt(cur).." / "..fmt(dur)
                if abState==1 then timeText = timeText.."  [A]"
                elseif abState==2 then timeText = timeText.."  [A-B]" end
                love.graphics.printf(timeText,0,by+14,w,"center")
            end
        end
    end

    love.graphics.setFont(fontTiny)
    love.graphics.setColor(1,1,1,0.4)
    love.graphics.printf("A:Play  D-Pad:Tracks  L1:Shf  R1:Rpt  Y:A-B  B:Back",0,h-15,w,"center")
end
