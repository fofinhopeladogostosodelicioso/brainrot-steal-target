-- ============================================================
-- STEAL TARGET MERGED - Combina UI simples com sorting avançado
-- ============================================================
do
    pcall(function()
        local _old = guiParent:FindFirstChild("TT3StealTargetUI")
        if _old then _old:Destroy() end
    end)
    
    local stg = Instance.new("ScreenGui")
    stg.Name = "TT3StealTargetUI"
    stg.ResetOnSpawn = false
    stg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() stg.Parent = guiParent end)

    local stealTargetPanel = Instance.new("Frame", stg)
    stealTargetPanel.Name = "StealTarget"
    stealTargetPanel.Active = true
    stealTargetPanel.Size = UDim2.fromOffset(262, 360)
    stealTargetPanel.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
    stealTargetPanel.BorderSizePixel = 0
    Instance.new("UICorner", stealTargetPanel).CornerRadius = UDim.new(0, 10)
    _restorePos("stealtarget", stealTargetPanel, 300, 200)

    local pt = Instance.new("TextButton", stealTargetPanel)
    pt.Size = UDim2.new(1, 0, 0, 30)
    pt.BackgroundTransparency = 1
    pt.Text = "STEAL TARGET"
    pt.Font = Enum.Font.GothamBlack
    pt.TextSize = 13
    pt.TextColor3 = Color3.new(1, 1, 1)
    pt.AutoButtonColor = false
    pt.Active = true
    makeDraggable(pt, stealTargetPanel, "stealtarget")
    makeDraggable(stealTargetPanel, stealTargetPanel, "stealtarget")

    local scroll = Instance.new("ScrollingFrame", stealTargetPanel)
    scroll.Size = UDim2.new(1, -12, 1, -42)
    scroll.Position = UDim2.new(0, 6, 0, 36)
    scroll.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 5
    scroll.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 90)
    scroll.CanvasSize = UDim2.new()
    Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 6)
    
    local layout = Instance.new("UIListLayout", scroll)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 3)
    
    local spad = Instance.new("UIPadding", scroll)
    spad.PaddingTop = UDim.new(0, 4)
    spad.PaddingBottom = UDim.new(0, 4)
    spad.PaddingLeft = UDim.new(0, 4)
    spad.PaddingRight = UDim.new(0, 4)
    
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
    end)

    -- ============================================================
    -- IMAGE CACHE SYSTEM
    -- ============================================================
    local imageCache = {}
    do
        local cacheStorage = {}
        local cachePending = {}
        local cacheFailures = {}
        local cacheLocked = false

        if typeof(makefolder) == "function" then
            pcall(makefolder, "skyr0_brainrots")
            pcall(makefolder, "clt_brainrots")
        end

        local requestFunc = request or http_request or (http and http.request)
            or (syn and syn.request) or (fluxus and fluxus.request)
            or (getgenv and getgenv().request)
        
        local customAssetFunc = (typeof(getcustomasset) == "function" and getcustomasset)
            or (typeof(getsynasset) == "function" and getsynasset)
            or (typeof(getcustomasseturl) == "function" and getcustomasseturl)
            or (syn and typeof(syn.getcustomasset) == "function" and syn.getcustomasset)
            or nil
        
        local hasFileSystem = typeof(writefile) == "function" and typeof(isfile) == "function"

        local function isValidImageData(data)
            return type(data) == "string" and #data > 200
                and data:sub(1, 1) ~= "{" and data:sub(1, 1) ~= "<"
        end

        local function downloadImageData(url)
            if requestFunc then
                local ok, response = pcall(requestFunc, {Url = url, Method = "GET"})
                if ok and type(response) == "table" then
                    local body = response.Body or response.body
                    if isValidImageData(body) then return body end
                end
            end
            local ok, body = pcall(function() return game:HttpGet(url) end)
            if ok and isValidImageData(body) then return body end
            return nil
        end

        function imageCache.get(brainrotName, callback)
            if not brainrotName or brainrotName == "" then return nil end
            
            local cleanName = tostring(brainrotName):gsub("^%s+", ""):gsub("%s+$", "")
            local cacheName = cleanName:gsub("%s+", "_")

            -- Retorna se já está em cache
            if cacheStorage[cacheName] then
                if callback then pcall(callback, cacheStorage[cacheName]) end
                return cacheStorage[cacheName]
            end

            -- Registra callback para quando terminar
            if callback then
                cachePending[cacheName] = cachePending[cacheName] or {}
                table.insert(cachePending[cacheName], callback)
            end

            -- Se já está processando, retorna
            if cacheLocked and cachePending[cacheName] then
                return nil
            end

            -- Se falhou antes, não tenta novamente
            if cacheFailures[cacheName] and cacheFailures[cacheName] >= 3 then
                return nil
            end

            cacheLocked = true
            task.spawn(function()
                local sanitized = cacheName:gsub("[^%w_%-]", "")
                local filePaths = {
                    "skyr0_brainrots/" .. sanitized .. ".png",
                    "clt_brainrots/" .. sanitized .. ".png",
                    "skyr0_br_" .. sanitized .. ".png",
                    "clt_br_" .. sanitized .. ".png",
                    sanitized .. ".png"
                }

                local imageUrl = nil
                local error_msg = nil

                -- Tenta carregar de arquivo local
                if hasFileSystem and customAssetFunc then
                    for _, filePath in ipairs(filePaths) do
                        local fileExists = false
                        pcall(function() fileExists = isfile(filePath) end)
                        
                        if fileExists then
                            local ok, asset = pcall(customAssetFunc, filePath)
                            if ok and asset then
                                imageUrl = asset
                                break
                            end
                        end
                    end
                end

                -- Se não encontrou localmente, tenta download
                if not imageUrl then
                    local downloadUrls = {
                        string.format("https://cdn.lura.blue/sab/%s.png", cacheName),
                        string.format("https://cdn.lura.blue/sab/%s.png", sanitized),
                    }

                    local imageData = nil
                    for _, url in ipairs(downloadUrls) do
                        imageData = downloadImageData(url)
                        if imageData then break end
                    end

                    if imageData then
                        -- Tenta salvar em arquivo
                        if hasFileSystem then
                            for _, filePath in ipairs(filePaths) do
                                if pcall(writefile, filePath, imageData) then
                                    local ok, asset = pcall(customAssetFunc, filePath)
                                    if ok and asset then
                                        imageUrl = asset
                                        break
                                    else
                                        error_msg = "getcustomasset error"
                                    end
                                else
                                    error_msg = error_msg or "writefile error"
                                end
                            end
                        end
                    else
                        error_msg = "download failed"
                    end
                end

                -- Processa resultado
                if imageUrl then
                    cacheStorage[cacheName] = imageUrl
                    cacheFailures[cacheName] = nil
                    local pendingCallbacks = cachePending[cacheName]
                    cachePending[cacheName] = nil
                    if pendingCallbacks then
                        for _, cb in ipairs(pendingCallbacks) do
                            pcall(cb, imageUrl)
                        end
                    end
                else
                    cacheFailures[cacheName] = (cacheFailures[cacheName] or 0) + 1
                    local pendingCallbacks = cachePending[cacheName]
                    cachePending[cacheName] = nil
                    if pendingCallbacks then
                        for _, cb in ipairs(pendingCallbacks) do
                            pcall(cb, nil)
                        end
                    end
                    
                    if (cacheFailures[cacheName] or 0) < 3 then
                        task.delay(10, function()
                            if cacheFailures[cacheName] == (cacheFailures[cacheName] or 0) then
                                cacheFailures[cacheName] = nil
                            end
                        end)
                    end
                end
                cacheLocked = false
            end)
            return nil
        end
    end

    -- ============================================================
    -- UI FUNCTIONS
    -- ============================================================
    local function fmtVal(v)
        v = tonumber(v) or 0
        if v >= 1e9 then return string.format("%.1fB", v / 1e9) end
        if v >= 1e6 then return string.format("%.1fM", v / 1e6) end
        if v >= 1e3 then return string.format("%.1fK", v / 1e3) end
        return tostring(math.floor(v))
    end

    local rowByUid, lastSig = {}, nil
    local priorityList = _G.StealPriorityList or {}

    local function applyHighlight()
        local locked = _G.TT3StealTargetUID
        for uid, row in pairs(rowByUid) do
            if row and row.Parent then
                row.BackgroundColor3 = (uid == locked) and Color3.fromRGB(30, 70, 45) or Color3.fromRGB(28, 28, 28)
            end
        end
    end

    local function sortPets(pets)
        local stealMode = _G.StealSortMode or "Highest"
        local processedPets = {}

        for _, p in ipairs(pets) do
            local petInfo = {
                pet = p,
                uid = _petUid(p),
                mps = p.mps or 0,
                name = p.name or "?",
                isPriority = false,
                priorityIndex = 999
            }

            -- Verificar se é prioridade
            for idx, priority in ipairs(priorityList) do
                local priorityLower = priority:lower()
                local petName = (p.name or ""):lower()
                if petName:find(priorityLower, 1, true) or petName == priorityLower then
                    petInfo.isPriority = true
                    petInfo.priorityIndex = idx
                    break
                end
            end

            table.insert(processedPets, petInfo)
        end

        -- Aplicar sorting
        if stealMode == "Priority" then
            table.sort(processedPets, function(a, b)
                if a.isPriority ~= b.isPriority then
                    return a.isPriority
                end
                return a.priorityIndex < b.priorityIndex
            end)
        elseif stealMode == "Highest" then
            table.sort(processedPets, function(a, b)
                return a.mps > b.mps
            end)
        else
            table.sort(processedPets, function(a, b)
                return a.mps > b.mps
            end)
        end

        return processedPets
    end

    local function rebuild(pets)
        for _, c in ipairs(scroll:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        rowByUid = {}

        local sortedPets = sortPets(pets)

        for i, petInfo in ipairs(sortedPets) do
            local p = petInfo.pet
            local uid = petInfo.uid

            local row = Instance.new("Frame", scroll)
            row.Size = UDim2.new(1, -4, 0, 32)
            row.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
            row.BorderSizePixel = 0
            row.LayoutOrder = i
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)
            rowByUid[uid] = row

            -- Indicador de prioridade
            if petInfo.isPriority then
                local indicator = Instance.new("UIStroke", row)
                indicator.Color = Color3.fromRGB(255, 90, 120)
                indicator.Thickness = 0.75
                indicator.Transparency = 0.3
            end

            local nm = Instance.new("TextLabel", row)
            nm.Size = UDim2.new(1, -16, 0, 16)
            nm.Position = UDim2.fromOffset(8, 3)
            nm.BackgroundTransparency = 1
            nm.Font = Enum.Font.GothamBold
            nm.TextSize = 12
            nm.TextColor3 = Color3.new(1, 1, 1)
            nm.TextXAlignment = Enum.TextXAlignment.Left
            nm.TextTruncate = Enum.TextTruncate.AtEnd
            nm.Text = petInfo.name

            local sub = Instance.new("TextLabel", row)
            sub.Size = UDim2.new(1, -16, 0, 12)
            sub.Position = UDim2.fromOffset(8, 18)
            sub.BackgroundTransparency = 1
            sub.Font = Enum.Font.Gotham
            sub.TextSize = 11
            sub.TextColor3 = Color3.fromRGB(120, 210, 150)
            sub.TextXAlignment = Enum.TextXAlignment.Left
            sub.Text = fmtVal(petInfo.mps) .. "/s"

            local click = Instance.new("TextButton", row)
            click.Size = UDim2.new(1, 0, 1, 0)
            click.BackgroundTransparency = 1
            click.Text = ""
            click.MouseButton1Click:Connect(function()
                if _G.TT3StealTargetUID == uid then
                    _clearTPSync()
                    notify("TARGET", "cleared")
                else
                    _G.TT3StealTargetUID = uid
                    _G.TT3StealTarget = p
                    _G.TT3TPSyncActive = true
                    notify("TARGET", petInfo.name)
                end
                applyHighlight()
            end)
        end
    end

    local function refresh()
        if not (stealTargetPanel and stealTargetPanel.Visible) then return end
        local ok, pets = pcall(scanAllPets)
        if not ok or type(pets) ~= "table" then return end

        local locked, stillThere, sig = _G.TT3StealTargetUID, false, ""
        for _, p in ipairs(pets) do
            local u = _petUid(p)
            sig = sig .. u .. "|"
            if u == locked then stillThere = true end
        end

        if locked and locked ~= "" and not stillThere then _clearTPSync() end
        if sig ~= lastSig then
            lastSig = sig
            rebuild(pets)
        end
        applyHighlight()
    end

    task.spawn(function()
        while stealTargetPanel and stealTargetPanel.Parent do
            pcall(refresh)
            task.wait(0.4)
        end
    end)
end

-- Exporta cache para uso global
_G.Skyr0_GetBrainrotImg = imageCache and imageCache.get or function() return nil end
_G.CLTHUB_GetBrainrotImg = imageCache and imageCache.get or function() return nil end
