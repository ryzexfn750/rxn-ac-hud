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

local msg = ac.OnlineEvent({
  ac.StructItem.key("overtakeScoreEnd"),
  Score = ac.StructItem.int64(),
  Multiplier = ac.StructItem.int32(),
  Car = ac.StructItem.string(64),
})

local function resetRun()
  score = 0
  comboMeter = 1
  runTime = 0
  below90Timer = 0
  distanceMeters = 0
  isRunActive = false
end

local function startRun()
  isRunActive = true
  score = 0
  comboMeter = 1
  runTime = 0
  below90Timer = 0
  distanceMeters = 0
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

  lastRunScore = finalScore

  if finalScore > personalBest then
    personalBest = finalScore
  end

  msg({
    Score = finalScore,
    Multiplier = finalCombo,
    Car = ac.getCarName(0)
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

  if not isRunActive and crashCooldown <= 0 and speedKmh > 90 then
    startRun()
  end

  if isRunActive then
    runTime = runTime + dt
    distanceMeters = distanceMeters + (speedMs * dt)

    comboMeter = math.floor(distanceMeters / 1000) + 1
    if comboMeter > 10 then
      comboMeter = 10
    end

    score = score + (speedKmh * comboMeter * dt * 0.5)

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
  local sStatus = tostring(statusText or "READY")
  local sScore = tostring(math.floor(score or 0))
  local sCombo = tostring(comboMeter or 1)
  local sBest = tostring(personalBest or 0)
  local sLast = tostring(lastRunScore or 0)
  local sDistance = tostring(string.format("%.2f", (distanceMeters or 0) / 1000))

  local bg = rgbm(0.03, 0.03, 0.04, 0.92)
  local panel = rgbm(0.07, 0.07, 0.09, 0.97)
  local soft = rgbm(0.72, 0.74, 0.78, 1.00)
  local white = rgbm(0.96, 0.97, 0.99, 1.00)
  local line = rgbm(1.00, 1.00, 1.00, 0.08)
  local separator = rgbm(1.00, 1.00, 1.00, 0.20)
  local barBg = rgbm(1.00, 1.00, 1.00, 0.08)
  local barFill = rgbm(0.95, 0.08, 0.08, 1.00)

  local uiPos = vec2(1520, 30)
  local uiSize = vec2(340, 240)

  local statusColor = rgbm(0.75, 0.75, 0.75, 1.00)
  if sStatus == "RUN" then
    statusColor = rgbm(0.25, 0.95, 0.45, 1.00)
  elseif sStatus == "FINISH" then
    statusColor = rgbm(0.20, 0.70, 1.00, 1.00)
  elseif sStatus == "CRASH" then
    statusColor = rgbm(1.00, 0.25, 0.25, 1.00)
  end

  local countdownProgress = math.min((below90Timer or 0) / 3.0, 1.0)
  local showCountdown = (below90Timer or 0) > 0 and isRunActive

  ui.beginTransparentWindow("score_tracker_hud", uiPos, uiSize, true)

  local p = ui.getCursor()

  ui.drawRectFilled(p, p + vec2(316, 214), bg, 14)
  ui.drawRectFilled(p + vec2(8, 8), p + vec2(308, 206), panel, 10)

  ui.drawLine(p + vec2(20, 48), p + vec2(292, 48), line, 1)

   ui.drawImage(logoUrl, p + vec2(14, 40), p + vec2(77, 73))
  ui.drawLine(p + vec2(81, 10), p + vec2(81, 32), separator, 1.5)

  ui.setCursor(p + vec2(92, 12))
  ui.pushFont(ui.Font.Title)
  ui.pushStyleColor(ui.StyleColor.Text, white)
  ui.text("RxN AC Servers")
  ui.popStyleColor()
  ui.popFont()

  ui.setCursor(p + vec2(24, 60))
  ui.pushStyleColor(ui.StyleColor.Text, soft)
  ui.text("CURRENT SCORE")
  ui.popStyleColor()

  ui.setCursor(p + vec2(24, 78))
  ui.pushFont(ui.Font.Title)
  ui.pushStyleColor(ui.StyleColor.Text, white)
  ui.text(sScore)
  ui.popStyleColor()
  ui.popFont()

  ui.setCursor(p + vec2(220, 60))
  ui.pushStyleColor(ui.StyleColor.Text, soft)
  ui.text("STATUS")
  ui.popStyleColor()

  ui.setCursor(p + vec2(220, 78))
  ui.pushStyleColor(ui.StyleColor.Text, statusColor)
  ui.text(sStatus)
  ui.popStyleColor()

  ui.setCursor(p + vec2(24, 118))
  ui.pushStyleColor(ui.StyleColor.Text, soft)
  ui.text("Combo")
  ui.popStyleColor()

  ui.setCursor(p + vec2(24, 136))
  ui.pushStyleColor(ui.StyleColor.Text, white)
  ui.text("x" .. sCombo)
  ui.popStyleColor()

  ui.setCursor(p + vec2(96, 118))
  ui.pushStyleColor(ui.StyleColor.Text, soft)
  ui.text("Distance")
  ui.popStyleColor()

  ui.setCursor(p + vec2(96, 136))
  ui.pushStyleColor(ui.StyleColor.Text, white)
  ui.text(sDistance .. " km")
  ui.popStyleColor()

  ui.setCursor(p + vec2(192, 118))
  ui.pushStyleColor(ui.StyleColor.Text, soft)
  ui.text("Best")
  ui.popStyleColor()

  ui.setCursor(p + vec2(192, 136))
  ui.pushStyleColor(ui.StyleColor.Text, white)
  ui.text(sBest)
  ui.popStyleColor()

  ui.setCursor(p + vec2(248, 118))
  ui.pushStyleColor(ui.StyleColor.Text, soft)
  ui.text("Last")
  ui.popStyleColor()

  ui.setCursor(p + vec2(248, 136))
  ui.pushStyleColor(ui.StyleColor.Text, white)
  ui.text(sLast)
  ui.popStyleColor()

  if showCountdown then
    local barLeft = p + vec2(24, 168)
    local barRight = p + vec2(286, 180)
    local barWidth = 286 - 24
    local fillWidth = barWidth * countdownProgress

    ui.drawRectFilled(barLeft, barRight, barBg, 5)
    ui.drawRectFilled(barLeft, barLeft + vec2(fillWidth, 12), barFill, 5)

    ui.setCursor(p + vec2(24, 188))
    ui.pushStyleColor(ui.StyleColor.Text, soft)
    ui.text("Below minimum speed")
    ui.popStyleColor()
  end

  ui.endTransparentWindow()
end
