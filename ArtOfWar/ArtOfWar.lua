local ADDON = "ArtOfWar"
local TEXTURA = "Interface\\AddOns\\" .. ADDON .. "\\PALADINPOWERTEXTURES"

local COORD_APAGADA   = { 0.01562, 0.52344, 0.02344, 0.30469 }
local COORD_ENCENDIDA = { 0.01172, 0.52344, 0.34375, 0.64062 }
local COORD_RUNA1     = { 0.00000, 0.14453, 0.78125, 0.98438 }
local COORD_RUNA2     = { 0.14844, 0.27734, 0.79688, 0.92188 }
local COORD_ROMBO     = { 0.28125, 0.38672, 0.64844, 0.80469 }

local RUNA1_X, RUNA1_Y = 19, -8
local RUNA2_X, RUNA2_Y = 53, -14
local ROMBO_X, ROMBO_Y = 91, -12

local IDS_PROC = { 53489, 59578 }
local NOMBRES = {
    ["the art of war"] = true,
    ["el arte de la guerra"] = true,
    ["arte de la guerra"] = true,
}
local nombresListos = false

local DURACION_PRUEBA = 15

local ESTRATA = "LOW"

local DEFAULTS = {
    base = true,
    contador = true,
    fade = true, fadeTiempo = 0.25,
    aviso = true, avisoSeg = 3,

    point = "TOPLEFT", relPoint = "TOPLEFT", x = 96, y = -61,
    anclaPF = true,
}

local RANGOS = { fadeTiempo = { 0.1, 1 }, avisoSeg = { 1, 6 } }

local function ValidarDB(db)
    for k, v in pairs(DEFAULTS) do
        if type(db[k]) ~= type(v) then db[k] = v end
    end
    for k, r in pairs(RANGOS) do
        if db[k] ~= db[k] or db[k] < r[1] or db[k] > r[2] then db[k] = DEFAULTS[k] end
    end
end

local procActivo, expira = false, nil
local pruebaFin = nil
local desbloqueado = false
local panelAbierto = false
local alfa, ultimoTexto = 0, nil

local panel, RefrescarPanel

local frame = CreateFrame("Frame", "ArtOfWarFrame", UIParent)
frame:SetWidth(131)
frame:SetHeight(38)

frame:SetPoint("CENTER", UIParent, "CENTER", 0, -100)
frame:SetFrameStrata(ESTRATA)
frame:SetMovable(true)
frame:SetClampedToScreen(true)
frame:RegisterForDrag("LeftButton")

local base = frame:CreateTexture(nil, "BACKGROUND")
base:SetWidth(130)
base:SetHeight(36)
base:SetPoint("CENTER", frame, "CENTER", 0, 0)
base:SetTexture(TEXTURA)
base:SetTexCoord(unpack(COORD_APAGADA))

local lit = CreateFrame("Frame", nil, frame)
lit:SetAllPoints(frame)
lit:SetFrameStrata(ESTRATA)
lit:SetAlpha(0)
lit:Hide()

local glow = lit:CreateTexture(nil, "ARTWORK")
glow:SetWidth(131)
glow:SetHeight(38)
glow:SetPoint("CENTER", frame, "CENTER", 0, 0)
glow:SetTexture(TEXTURA)
glow:SetTexCoord(unpack(COORD_ENCENDIDA))

local runa1 = lit:CreateTexture(nil, "OVERLAY")
runa1:SetWidth(37)
runa1:SetHeight(26)
runa1:SetPoint("TOPLEFT", frame, "TOPLEFT", RUNA1_X, RUNA1_Y)
runa1:SetTexture(TEXTURA)
runa1:SetTexCoord(unpack(COORD_RUNA1))

local runa2 = lit:CreateTexture(nil, "OVERLAY")
runa2:SetWidth(33)
runa2:SetHeight(16)
runa2:SetPoint("TOPLEFT", frame, "TOPLEFT", RUNA2_X, RUNA2_Y)
runa2:SetTexture(TEXTURA)
runa2:SetTexCoord(unpack(COORD_RUNA2))

local rombo = lit:CreateTexture(nil, "OVERLAY")
rombo:SetWidth(27)
rombo:SetHeight(20)
rombo:SetPoint("TOPLEFT", frame, "TOPLEFT", ROMBO_X, ROMBO_Y)
rombo:SetTexture(TEXTURA)
rombo:SetTexCoord(unpack(COORD_ROMBO))

local texto = lit:CreateFontString(nil, "OVERLAY")
texto:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
texto:SetPoint("TOP", frame, "BOTTOM", 0, -2)
texto:SetTextColor(1, 1, 1)

local function Msg(txt)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Art of War:|r " .. txt)
end

local function CargarNombres()
    if nombresListos then return end
    for i = 1, #IDS_PROC do
        local n = GetSpellInfo(IDS_PROC[i])
        if n then NOMBRES[strlower(n)] = true end
    end
    nombresListos = true
end

local function BuscarProc()
    CargarNombres()
    for i = 1, 40 do
        local nombre, _, _, _, _, _, expiracion = UnitBuff("player", i)
        if not nombre then return false end
        if NOMBRES[strlower(nombre)] then
            if expiracion and expiracion > 0 then return true, expiracion end
            return true
        end
    end
    return false
end

local function Estado()
    if procActivo then return true, expira end
    if pruebaFin then return true, pruebaFin end
    return false
end

local function Actualizar()
    local db = ArtOfWarDB or DEFAULTS
    if db.base or desbloqueado then base:Show() else base:Hide() end
end

local function FormatoTiempo(t)
    if t >= 10 then return string.format("%d", math.ceil(t)) end
    return string.format("%.1f", t)
end

local function AplicarEstrata()
    local s = ESTRATA
    if desbloqueado then s = "HIGH" end
    if panelAbierto then s = "TOOLTIP" end
    frame:SetFrameStrata(s)
    lit:SetFrameStrata(s)

    local p = frame:GetParent()
    if p and p ~= UIParent then
        frame:SetFrameLevel(p:GetFrameLevel() + 10)
        lit:SetFrameLevel(frame:GetFrameLevel() + 1)
    end
end

local function MarcoJugador()
    return _G.NidhausPlayerFrame or PlayerFrame
end

local anclaPendiente = false

local function Anclar()
    local db = ArtOfWarDB
    if not db then return end
    if InCombatLockdown() then anclaPendiente = true return end
    anclaPendiente = false
    local pf = MarcoJugador()
    frame:SetParent(pf)

    frame:SetUserPlaced(false)
    frame:ClearAllPoints()
    frame:SetPoint(db.point, pf, db.relPoint, db.x, db.y)
    AplicarEstrata()
end

local function GuardarPosicion()
    local db, pf = ArtOfWarDB, MarcoJugador()
    if not db or not frame:GetLeft() or not pf:GetLeft() then return end
    local ef, ep = frame:GetEffectiveScale(), pf:GetEffectiveScale()

    db.point, db.relPoint = "TOPLEFT", "TOPLEFT"
    db.x = math.floor((frame:GetLeft() * ef - pf:GetLeft() * ep) / ef + 0.5)
    db.y = math.floor((frame:GetTop() * ef - pf:GetTop() * ep) / ef + 0.5)
    db.anclaPF = true
end

frame:SetScript("OnUpdate", function(self, dt)
    local ahora = GetTime()
    if pruebaFin and ahora >= pruebaFin then pruebaFin = nil end

    local activo, fin = Estado()
    local objetivo = activo and 1 or 0
    if alfa == 0 and objetivo == 0 then return end

    local db = ArtOfWarDB or DEFAULTS
    if db.fade and db.fadeTiempo > 0 then
        local paso = dt / db.fadeTiempo
        if alfa < objetivo then
            alfa = math.min(objetivo, alfa + paso)
        elseif alfa > objetivo then
            alfa = math.max(objetivo, alfa - paso)
        end
    else
        alfa = objetivo
    end

    if alfa <= 0 then
        alfa = 0
        lit:SetAlpha(0)
        lit:Hide()
        ultimoTexto = nil
        return
    end
    if not lit:IsShown() then lit:Show() end

    local restante = fin and (fin - ahora) or nil
    local enAviso = activo and db.aviso and restante and restante > 0 and restante <= db.avisoSeg

    local pulso = 1
    if enAviso then pulso = 0.65 + 0.35 * math.sin(ahora * 12) end
    lit:SetAlpha(alfa * pulso)

    local txt = ""
    if activo and db.contador and restante then
        txt = FormatoTiempo(math.max(restante, 0))
    end
    if txt ~= ultimoTexto then
        texto:SetText(txt)
        ultimoTexto = txt
    end
    if enAviso then texto:SetTextColor(1, 0.25, 0.25) else texto:SetTextColor(1, 1, 1) end
end)

local function AlternarMover()
    desbloqueado = not desbloqueado
    frame:EnableMouse(desbloqueado)
    AplicarEstrata()
    Actualizar()
    if RefrescarPanel then RefrescarPanel() end
    Msg(desbloqueado and "unlocked: drag it with left click. /aow move to lock it." or "locked.")
end

local function AlternarPrueba()
    if pruebaFin then
        pruebaFin = nil
        Msg("test stopped")
    else
        pruebaFin = GetTime() + DURACION_PRUEBA
        Msg(DURACION_PRUEBA .. " second test")
    end
end

local function Restaurar()
    local db = ArtOfWarDB
    if not db then return end
    for k, v in pairs(DEFAULTS) do db[k] = v end
    Anclar()
    Actualizar()
    if RefrescarPanel then RefrescarPanel() end
    Msg("settings and position reset")
end

local function AbrirPanel()

    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
end

local refrescando = false

panel = CreateFrame("Frame", "ArtOfWarOpciones", UIParent)
panel.name = "Art of War"

local titulo = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
titulo:SetPoint("TOPLEFT", 16, -16)
titulo:SetText("Art of War")

local subtitulo = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitulo:SetPoint("TOPLEFT", titulo, "BOTTOMLEFT", 0, -8)
subtitulo:SetWidth(520)
subtitulo:SetJustifyH("LEFT")
subtitulo:SetText("Bar that lights up when The Art of War procs. Changes apply instantly.")

local function NuevoCheck(nombre, textoCheck, anclaA, dx, dy, clave)
    local cb = CreateFrame("CheckButton", nombre, panel, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", anclaA, "BOTTOMLEFT", dx, dy)
    _G[nombre .. "Text"]:SetText(textoCheck)
    cb:SetScript("OnClick", function(self)
        PlaySound(self:GetChecked() and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
        if not ArtOfWarDB then return end
        ArtOfWarDB[clave] = self:GetChecked() and true or false
        Actualizar()
        RefrescarPanel()
    end)
    return cb
end

local function PonerTituloSlider(s, valor)
    _G[s.nombre .. "Text"]:SetText(string.format(s.fmt, valor))
end

local function NuevoSlider(nombre, anclaA, dx, dy, minimo, maximo, paso, clave, fmt, txtMin, txtMax)
    local s = CreateFrame("Slider", nombre, panel, "OptionsSliderTemplate")
    s.nombre, s.fmt = nombre, fmt
    s:SetPoint("TOPLEFT", anclaA, "BOTTOMLEFT", dx, dy)
    s:SetWidth(220)
    s:SetMinMaxValues(minimo, maximo)
    s:SetValueStep(paso)
    _G[nombre .. "Low"]:SetText(txtMin)
    _G[nombre .. "High"]:SetText(txtMax)
    PonerTituloSlider(s, minimo)
    s:SetScript("OnValueChanged", function(self, valor)
        valor = math.floor(valor / paso + 0.5) * paso
        PonerTituloSlider(self, valor)
        if refrescando or not ArtOfWarDB then return end
        ArtOfWarDB[clave] = valor
    end)
    return s
end

local function HabilitarSlider(s, si)
    s:EnableMouse(si and true or false)
    s:SetAlpha(si and 1 or 0.5)
end

local chkBase     = NuevoCheck("ArtOfWarChkBase", "Show the unlit bar when there is no proc", subtitulo, 0, -14, "base")
local chkContador = NuevoCheck("ArtOfWarChkContador", "Show duration timer (below the bar)", chkBase, 0, -4, "contador")
local chkFade     = NuevoCheck("ArtOfWarChkFade", "Fade in / fade out when showing and hiding", chkContador, 0, -4, "fade")
local sldFade     = NuevoSlider("ArtOfWarSldFade", chkFade, 28, -24, 0.1, 1, 0.05, "fadeTiempo",
                                "Fade duration: %.2f s", "0.1 s", "1 s")
local chkAviso    = NuevoCheck("ArtOfWarChkAviso", "Flash when the proc is about to expire", sldFade, -28, -20, "aviso")
local sldAviso    = NuevoSlider("ArtOfWarSldAviso", chkAviso, 28, -24, 1, 6, 0.5, "avisoSeg",
                                "Warn in the last: %.1f s", "1 s", "6 s")

local btnProbar = CreateFrame("Button", "ArtOfWarBtnProbar", panel, "UIPanelButtonTemplate")
btnProbar:SetWidth(130)
btnProbar:SetHeight(22)
btnProbar:SetPoint("TOPLEFT", sldAviso, "BOTTOMLEFT", -28, -32)
btnProbar:SetText("Test (15 s)")
btnProbar:SetScript("OnClick", function() AlternarPrueba() end)

local btnMover = CreateFrame("Button", "ArtOfWarBtnMover", panel, "UIPanelButtonTemplate")
btnMover:SetWidth(130)
btnMover:SetHeight(22)
btnMover:SetPoint("LEFT", btnProbar, "RIGHT", 8, 0)
btnMover:SetText("Move bar")
btnMover:SetScript("OnClick", function()
    AlternarMover()

    if desbloqueado and InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then
        HideUIPanel(InterfaceOptionsFrame)
    end
end)

local btnReset = CreateFrame("Button", "ArtOfWarBtnReset", panel, "UIPanelButtonTemplate")
btnReset:SetWidth(130)
btnReset:SetHeight(22)
btnReset:SetPoint("LEFT", btnMover, "RIGHT", 8, 0)
btnReset:SetText("Reset settings")
btnReset:SetScript("OnClick", function() Restaurar() end)

RefrescarPanel = function()
    local db = ArtOfWarDB
    if not db then return end
    refrescando = true
    chkBase:SetChecked(db.base)
    chkContador:SetChecked(db.contador)
    chkFade:SetChecked(db.fade)
    chkAviso:SetChecked(db.aviso)
    sldFade:SetValue(db.fadeTiempo)
    sldAviso:SetValue(db.avisoSeg)
    refrescando = false
    PonerTituloSlider(sldFade, db.fadeTiempo)
    PonerTituloSlider(sldAviso, db.avisoSeg)
    HabilitarSlider(sldFade, db.fade)
    HabilitarSlider(sldAviso, db.aviso)
    btnMover:SetText(desbloqueado and "Lock bar" or "Move bar")
end

panel:SetScript("OnShow", function()
    panelAbierto = true
    AplicarEstrata()
    RefrescarPanel()
end)
panel:SetScript("OnHide", function()
    panelAbierto = false
    AplicarEstrata()
end)

panel.okay = function() end
panel.cancel = function() end
panel.default = function() Restaurar() end

frame:SetScript("OnDragStart", function(self)
    if desbloqueado then self:StartMoving() end
end)

frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()

    self:SetUserPlaced(false)
    GuardarPosicion()
    Anclar()
end)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("UNIT_ENTERED_VEHICLE")
frame:RegisterEvent("UNIT_EXITED_VEHICLE")

local function ActualizarVehiculo()
    if UnitHasVehicleUI("player") then frame:Hide() else frame:Show() end
end

local esPaladin = true
local migrar = false

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end

        local _, clase = UnitClass("player")
        if clase ~= "PALADIN" then
            esPaladin = false
            self:UnregisterAllEvents()
            self:SetScript("OnUpdate", nil)
            self:Hide()
            return
        end
        InterfaceOptions_AddCategory(panel)
        if type(ArtOfWarDB) ~= "table" then

            if type(MiDestelloDB) == "table" then ArtOfWarDB = MiDestelloDB else ArtOfWarDB = {} end
        end
        MiDestelloDB = nil

        migrar = ArtOfWarDB.anclaPF == nil and type(ArtOfWarDB.x) == "number"
        ValidarDB(ArtOfWarDB)
        if migrar then

            self:ClearAllPoints()
            self:SetPoint(ArtOfWarDB.point, UIParent, ArtOfWarDB.relPoint, ArtOfWarDB.x, ArtOfWarDB.y)
        end
        return
    elseif event == "PLAYER_ENTERING_WORLD" then
        if migrar and not InCombatLockdown() then
            migrar = false
            GuardarPosicion()
        end
        Anclar()
        ActualizarVehiculo()
    elseif event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
        if arg1 == "player" then ActualizarVehiculo() end
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        if anclaPendiente then
            if migrar then migrar = false GuardarPosicion() end
            Anclar()
        end
        return
    elseif event == "UNIT_AURA" and arg1 ~= "player" then
        return
    end
    procActivo, expira = BuscarProc()
    Actualizar()
end)

SLASH_ARTOFWAR1 = "/aow"
SLASH_ARTOFWAR2 = "/artofwar"
SLASH_ARTOFWAR3 = "/destello"
SlashCmdList["ARTOFWAR"] = function(msg)
    if not esPaladin then
        Msg("this addon is only for Paladins.")
        return
    end
    msg = strlower(strtrim(msg or ""))
    local db = ArtOfWarDB
    if not db then return end

    if msg == "" or msg == "options" or msg == "opciones" then
        AbrirPanel()
    elseif msg == "move" or msg == "mover" then
        AlternarMover()
    elseif msg == "base" then
        db.base = not db.base
        Actualizar()
        RefrescarPanel()
        Msg("background bar " .. (db.base and "shown" or "hidden"))
    elseif msg == "test" then
        AlternarPrueba()
    elseif msg == "reset" then
        Restaurar()
    else
        Msg("/aow [options | move | base | test | reset]")
    end
end
