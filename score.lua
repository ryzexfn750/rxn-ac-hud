local score = 0
local personalBest = 0
local comboMeter = 1
local isRunActive = false
local runTime = 0
local below90Timer = 0
local crashCooldown = 0
local lastRunScore = 0
local statusText = "READY"
local distanceMeters = 0
local logoUrl = 'https://raw.githubusercontent.com/ryzexfn750/rxn-ac-hud/main/rxn_logo.png'

-- leaderboard values (placeholder, da collegare al server)
local currentPlace = 9999
local bestPlace = 9999

local msg = ac.OnlineEvent({
  ac.StructItem.key("overtakeScoreEnd"),
  Score = ac.StructItem.int64(),
  Multiplier = ac.StructItem.int32(),
  Car = ac.StructItem.string(64),
  Driver = ac.StructItem.string(64),
})

local function getComboForDistance(distance)
  if distance >= 12000 then
    return 20
  elseif distance >= 8000 then
    return 10
  elseif distance >= 4000 then
    return 5
  elseif distance >= 1000 then
    return 2
  end
  return 1
end

local function getComboColor(comboValue)
  if comboValue >= 20 then
    return rgbm(1.00, 0.82, 0.18, 1.00) -- gold
  elseif comboValue >= 10 then
    return rgbm(0.92, 0.36, 0.95, 1.00) -- magenta
  elseif comboValue >= 5 then
    return rgbm(0.24, 0.74, 1.00, 1.00) -- cyan
  elseif comboValue >= 2 then
    return rgbm(0.30, 1.00, 0.62, 1.00) -- green
  end
  return rgbm(0.96, 0.97, 0.99, 1.00) -- white
end

local function formatPlace(placeValue)
  if not placeValue or placeValue <= 0 then
    return "-"
  end
  return tostring(placeValue)
end

local function updateLiveLeaderboardEstimate()
  -- Placeholder temporaneo:
  -- finché non colleghiamo la classifica server, simuliamo una posizione live
  -- che migliora all'aumentare dello score senza rompere nulla.
  local liveScore = math.floor(score or 0)

  if liveScore <= 0 then
    currentPlace = 9999
    return
  end

  if liveScore >= 50000 then
    currentPlace = 1
  elseif liveScore >= 35000 then
    currentPlace = 5
  elseif liveScore >= 25000 then
    currentPlace = 15
  elseif liveScore >= 18000 then
    currentPlace = 40
  elseif liveScore >= 12000 then
    currentPlace = 90
  elseif liveScore >= 8000 then
    currentPlace = 180
  elseif liveScore >= 5000 then
    currentPlace = 350
  elseif liveScore >= 3000 then
    currentPlace = 700
  else
    currentPlace = 999
  end
end

local function updateBestPlaceFromRun(finalScore)
  -- Placeholder temporaneo:
  -- aggiorna una best place locale finché non arriva il dato reale dal server.
  local simulatedPlace = currentPlace

  if finalScore <= 0 then return end
  if simulatedPlace <= 0 then return end

  if bestPlace == 9999 or simulatedPlace < bestPlace then
    bestPlace = simulatedPlace
  end
end

local function resetRun()
  score = 0
  comboMeter = 1
  runTime = 0
  below90Timer = 0
  distanceMeters = 0
  isRunActive = false
  currentPlace = 9999
end

local function startRun()
  isRunActive = true
  score = 0
  comboMeter = 1
  runTime = 0
  below90Timer = 0
  distanceMeters = 0
  currentPlace = 9999
  statusText = "RUN"
end

local function crashRun()
  if not isRunActive then return end
  lastRunScore = 0
  resetRun()
  crashCooldown = 3.0
  statusText = "CRASH"
end

local function finishRun()
  if not isRunActive then return end

  local finalScore = math.floor(score)
  local finalCombo = comboMeter
  local driverName = tostring(ac.getDriverName(0) or "Unknown Driver")
  local carName = tostring(ac.getCarName(0) or "Unknown Car")

  lastRunScore = finalScore

  if finalScore > personalBest then
    personalBest = finalScore
  end

  updateBestPlaceFromRun(finalScore)

  msg({
    Score = finalScore,
    Multiplier = finalCombo,
    Car = carName,
    Driver = driverName
  })

  resetRun()
  statusText = "FINISH"
end

function script.update(dt)
  local car = ac.getCar(0)
  if not car then return end

  local speedKmh = math.abs(tonumber(car.speedKmh) or 0)
  local collisionDepth = tonumber(car.collisionDepth) or 0
  local speedMs = speedKmh / 3.6

  if crashCooldown > 0 then
    crashCooldown = math.max(0, crashCooldown - dt)
  end

  if not isRunActive and crashCooldown <= 0 and speedKmh >= 90 then
    startRun()
  end

  if isRunActive then
    runTime = runTime + dt
    distanceMeters = distanceMeters + (speedMs * dt)

    comboMeter = getComboForDistance(distanceMeters)
    score = score + (speedKmh * comboMeter * dt * 0.5)

    updateLiveLeaderboardEstimate()

    if collisionDepth > 0.01 then
      crashRun()
      return
    end

    if speedKmh < 90 then
      below90Timer = below90Timer + dt
      if below90Timer >= 3.0 then
        finishRun()
        return
      end
    else
      below90Timer = 0
    end
  else
    if speedKmh < 5 and statusText == "FINISH" then
      statusText = "READY"
    end
    if speedKmh < 5 and statusText == "CRASH" and crashCooldown <= 0 then
      statusText = "READY"
    end
  end
end

function script.drawUI()
  local car = ac.getCar(0)
  local speedKmh = 0
  if car then
    speedKmh = math.abs(tonumber(car.speedKmh) or 0)
  end

  local sStatus = tostring(statusText or "READY")
  local sScore = tostring(math.floor(score or 0))
  local sCombo = tostring(comboMeter or 1)
  local sBest = tostring(personalBest or 0)
  local sLast = tostring(lastRunScore or 0)
  local sDistance = tostring(string.format("%.2f", (distanceMeters or 0) / 1000))
  local sCurrentPlace = formatPlace(currentPlace)
  local sBestPlace = formatPlace(bestPlace)

  local bg = rgbm(0.03, 0.03, 0.04, 0.92)
  local panel = rgbm(0.07, 0.07, 0.09, 0.97)
  local soft = rgbm(0.72, 0.74, 0.78, 1.00)
  local white = rgbm(0.96, 0.97, 0.99, 1.00)
  local line = rgbm(1.00, 1.00, 1.00, 0.08)
  local separator = rgbm(1.00, 1.00, 1.00, 0.20)
  local barBg = rgbm(1.00, 1.00, 1.00, 0.08)
  local barFill = rgbm(0.95, 0.08, 0.08, 1.00)
  local startBarFill = rgbm(0.25, 0.95, 0.45, 1.00)

  local statusColor = rgbm(0.75, 0.75, 0.75, 1.00)
  if sStatus == "RUN" then
    statusColor = rgbm(0.25, 0.95, 0.45, 1.00)
  elseif sStatus == "FINISH" then
    statusColor = rgbm(0.20, 0.70, 1.00, 1.00)
  elseif sStatus == "CRASH" then
    statusColor = rgbm(1.00, 0.25, 0.25, 1.00)
  end

  local comboColor = getComboColor(comboMeter)
  local countdownProgress = math.min((below90Timer or 0) / 3.0, 1.0)
  local showCountdown = (below90Timer or 0) > 0 and isRunActive
  local startProgress = math.min(speedKmh / 90.0, 1.0)
  local showStartBar = not isRunActive and crashCooldown <= 0
  local showAnyBar = showStartBar or showCountdown

  local uiPos = vec2(1520, 30)
  local uiSize = showAnyBar and vec2(340, 304) or vec2(340, 256)

  local outerBottom = showAnyBar and 278 or 230
  local innerBottom = showAnyBar and 270 or 222

  -- header fisso
  local logoTopLeft = vec2(15, 1)
  local logoBottomRight = vec2(75, 59)
  local separatorTop = 17
  local separatorBottom = 45
  local titleCursor = vec2(92, 15)

  -- contenuto dinamico
  local scoreLabelY = showAnyBar and 60 or 56
  local scoreValueY = showAnyBar and 78 or 74

  local statusLabelY = showAnyBar and 60 or 56
  local statusValueY = showAnyBar and 78 or 74

  local row2LabelY = showAnyBar and 118 or 106
  local row2ValueY = showAnyBar and 136 or 126

  local row3LabelY = showAnyBar and 170 or 158
  local row3ValueY = showAnyBar and 188 or 178

  ui.beginTransparentWindow("score_tracker_hud", uiPos, uiSize, true)

  local p = ui.getCursor()

  ui.drawRectFilled(p, p + vec2(316, outerBottom), bg, 14)
  ui.drawRectFilled(p + vec2(8, 8), p + vec2(308, innerBottom), panel, 10)

  ui.drawLine(p + vec2(20, 48), p + vec2(292, 48), line, 1)

  ui.drawImage(logoUrl, p + logoTopLeft, p + logoBottomRight)
  ui.drawLine(p + vec2(81, separatorTop), p + vec2(81, separatorBottom), separator, 1.5)

  ui.setCursor(p + titleCursor)
  ui.pushFont(ui.Font.Title)
  ui.pushStyleColor(ui.StyleColor.Text, white)
  ui.text("RxN AC Servers")
  ui.popStyleColor()
  ui.popFont()

  ui.setCursor(p + vec2(24, scoreLabelY))
  ui.pushStyleColor(ui.StyleColor.Text, soft)
  ui.text("CURRENT SCORE")
  ui.popStyleColor()

  ui.setCursor(p + vec2(24, scoreValueY))
  ui.pushFont(ui.Font.Title)
  ui.pushStyleColor(ui.StyleColor.Text, comboColor)
  ui.text(sScore)
  ui.popStyleColor()
  ui.popFont()

  ui.setCursor(p + vec2(220, statusLabelY))
  ui.pushStyleColor(ui.StyleColor.Text, soft)
  ui.text("STATUS")
  ui.popStyleColor()

  ui.setCursor(p + vec2(220, statusValueY))
  if not showAnyBar then ui.pushFont(ui.Font.Title) end
  ui.pushStyleColor(ui.StyleColor.Text, statusColor)
  ui.text(sStatus)
  ui.popStyleColor()
  if not showAnyBar then ui.popFont() end

  ui.setCursor(p + vec2(24, row2LabelY))
  ui.pushStyleColor(ui.StyleColor.Text, soft)
  ui.text("Combo")
  ui.popStyleColor()

  ui.setCursor(p + vec2(24, row2ValueY))
  ui.pushFont(ui.Font.Title)
  ui.pushStyleColor(ui.StyleColor.Text, comboColor)
  ui.text("x" .. sCombo)
  ui.popStyleColor()
  ui.popFont()

  ui.setCursor(p + vec2(96, row2LabelY))
  ui.pushStyleColor(ui.StyleColor.Text, soft)
  ui.text("Distance")
  ui.popStyleColor()

  ui.setCursor(p + vec2(96, row2ValueY))
  if not showAnyBar then ui.pushFont(ui.Font.Title) end
  ui.pushStyleColor(ui.StyleColor.Text, white)
  ui.text(sDistance .. " km")
  ui.popStyleColor()
  if not showAnyBar then ui.popFont() end

  ui.setCursor(p + vec2(192, row2LabelY))
  ui.pushStyleColor(ui.StyleColor.Text, soft)
  ui.text("Best")
  ui.popStyleColor()

  ui.setCursor(p + vec2(192, row2ValueY))
  if not showAnyBar then ui.pushFont(ui.Font.Title) end
  ui.pushStyleColor(ui.StyleColor.Text, white)
  ui.text(sBest)
  ui.popStyleColor()
  if not showAnyBar then ui.popFont() end

  ui.setCursor(p + vec2(248, row2LabelY))
  ui.pushStyleColor(ui.StyleColor.Text, soft)
  ui.text("Last")
  ui.popStyleColor()

  ui.setCursor(p + vec2(248, row2ValueY))
  if not showAnyBar then ui.pushFont(ui.Font.Title) end
  ui.pushStyleColor(ui.StyleColor.Text, white)
  ui.text(sLast)
  ui.popStyleColor()
  if not showAnyBar then ui.popFont() end

  ui.setCursor(p + vec2(24, row3LabelY))
  ui.pushStyleColor(ui.StyleColor.Text, soft)
  ui.text("Current place")
  ui.popStyleColor()

  ui.setCursor(p + vec2(24, row3ValueY))
  if not showAnyBar then ui.pushFont(ui.Font.Title) end
  ui.pushStyleColor(ui.StyleColor.Text, white)
  ui.text("#" .. sCurrentPlace)
  ui.popStyleColor()
  if not showAnyBar then ui.popFont() end

  ui.setCursor(p + vec2(170, row3LabelY))
  ui.pushStyleColor(ui.StyleColor.Text, soft)
  ui.text("Best place")
  ui.popStyleColor()

  ui.setCursor(p + vec2(170, row3ValueY))
  if not showAnyBar then ui.pushFont(ui.Font.Title) end
  ui.pushStyleColor(ui.StyleColor.Text, white)
  ui.text("#" .. sBestPlace)
  ui.popStyleColor()
  if not showAnyBar then ui.popFont() end

  local nextY = 220

  if showStartBar then
    local startBarLeft = p + vec2(24, nextY)
    local startBarRight = p + vec2(286, nextY + 12)
    local startBarWidth = 286 - 24
    local startFillWidth = startBarWidth * startProgress

    ui.drawRectFilled(startBarLeft, startBarRight, barBg, 5)
    ui.drawRectFilled(startBarLeft, startBarLeft + vec2(startFillWidth, 12), startBarFill, 5)

    ui.setCursor(p + vec2(24, nextY + 20))
    ui.pushStyleColor(ui.StyleColor.Text, soft)
    ui.text("Reach 90 km/h to start the run")
    ui.popStyleColor()

    nextY = nextY + 40
  end

  if showCountdown then
    local barLeft = p + vec2(24, nextY)
    local barRight = p + vec2(286, nextY + 12)
    local barWidth = 286 - 24
    local fillWidth = barWidth * countdownProgress

    ui.drawRectFilled(barLeft, barRight, barBg, 5)
    ui.drawRectFilled(barLeft, barLeft + vec2(fillWidth, 12), barFill, 5)

    ui.setCursor(p + vec2(24, nextY + 20))
    ui.pushStyleColor(ui.StyleColor.Text, soft)
    ui.text("Below minimum speed")
    ui.popStyleColor()
  end

  ui.endTransparentWindow()
end
