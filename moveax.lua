local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local DrillShop = game:GetService("ReplicatedStorage"):WaitForChild("DrillShop")

local KPets = game:GetService("ReplicatedStorage"):WaitForChild("KPets")
local Events = KPets:WaitForChild("Events")

getgenv().ExecutorVars = {
    AutoCashEnabled = false,
    CashSpeedSlider = nil,
    LogFunction = nil,
    MinCashDelay = 0.1,
    PurchaseDelay = 1,
    PurchaseBuffer = 0,
    RandomDelay = 0,
    AutoRetry = true,
    RetryDelay = 1,
    UIUpdateDelay = 1,
    VerboseLogging = false
}

local function getPlayerCash()
    local player = game:GetService("Players").LocalPlayer
    local leaderstats = player:WaitForChild("leaderstats", 2)
    if leaderstats then
        local cash = leaderstats:FindFirstChild("Cash")
        if cash then
            return cash.Value
        end
    end
    return 0
end

local function formatNumber(number)
    return tostring(number):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function getNextDrill()
    local ownedDrills = DrillShop.GetOwnedDrills:InvokeServer()
    local skinPrices = DrillShop.GetSkinPrices:InvokeServer()
    local currentCash = getPlayerCash()

    local drillsList = {}
    for drill, info in pairs(skinPrices) do
        table.insert(drillsList, {
            name = drill,
            price = info.Price,
            type = info.Type,
            owned = ownedDrills[drill] or false
        })
    end

    table.sort(drillsList, function(a, b) return a.price < b.price end)

    for _, drill in ipairs(drillsList) do
        if not drill.owned and drill.type == "Cash" then
            return {
                name = drill.name,
                price = drill.price,
                needed = math.max(0, drill.price - currentCash)
            }
        end
    end

    return nil
end

local function getEggInfo()
    local eggFolder = KPets:WaitForChild("Eggs", 5)

    if not eggFolder then
        warn("Eggs folder not found, using default eggs")
        return {
            ["Basic Egg"] = {cost = 100, pets = 5},
            ["Lava Egg"] = {cost = 1000, pets = 8}
        }
    end

    local eggInfo = {}

    for _, eggFolder in ipairs(eggFolder:GetChildren()) do
        local costValue = eggFolder:FindFirstChild("Cost")
        local petsFolder = eggFolder:FindFirstChild("Pets")

        if costValue then
            eggInfo[eggFolder.Name] = {
                cost = costValue.Value,
                pets = petsFolder and #petsFolder:GetChildren() or 0
            }
        end
    end

    if not next(eggInfo) then
        eggInfo = {
            ["Basic Egg"] = {cost = 100, pets = 5},
            ["Lava Egg"] = {cost = 1000, pets = 8}
        }
    end

    return eggInfo
end

local function teleportToBottom()
    local player = game:GetService("Players").LocalPlayer
    local character = player.Character

    if character and character:FindFirstChild("HumanoidRootPart") then

        local bottomPlatePosition = Vector3.new(-74.93, 6913.11, -1.56)

        character.HumanoidRootPart.CFrame = CFrame.new(bottomPlatePosition)

        return true
    end

    return false
end

local function createUI()

    local success, errorMsg = pcall(function()
        local Window = Rayfield:CreateWindow({
            Name = "⛏️ Drill Drill Drill",
            LoadingTitle = "Drill Drill Drill",
            LoadingSubtitle = "by Fizz",
            ConfigurationSaving = {
                Enabled = true,
                FolderName = "DrillConfig",
                FileName = "Config"
            },
            Discord = {
                Enabled = false,
                Invite = "discord.gg",
                RememberJoins = true
            },
            KeySystem = false,
        })

        local LogsTab = Window:CreateTab("📋 Logs", 4483362458)
        local AutoFarmTab = Window:CreateTab("⚒️ AutoFarm", 4483362458)
        local DrillsTab = Window:CreateTab("🔧 Drills", 4483362458)
        local PetsTab = Window:CreateTab("🐾 Pets", 4483362458)
        local AdvancedTab = Window:CreateTab("⚙️ Advanced", 4483362458)

        local EggSection = PetsTab:CreateSection("🥚 Egg Stuff")
        local PetSection = PetsTab:CreateSection("🐶 Pet ")

        local eggInfo = {}
        local eggTypes = {}

        pcall(function()
            eggInfo = getEggInfo()
            for eggName, _ in pairs(eggInfo) do
                table.insert(eggTypes, eggName)
            end
        end)

        if #eggTypes == 0 then
            eggTypes = {"Basic Egg", "Lava Egg"}
        end

        local selectedEgg = eggTypes[1] or "Basic"  
        local autoHatchEnabled = false
        local autoEquipEnabled = false

        PetsTab:CreateDropdown({
            Name = "🥚 Pick an Egg",
            Info = "Which egg u wanna hatch?",
            Options = eggTypes,
            CurrentOption = selectedEgg,
            Flag = "SelectedEgg", 
            Callback = function(Value)
                selectedEgg = Value
                ExecutorVars.LogFunction("Picked " .. Value .. " egg")
            end
        })

        PetsTab:CreateToggle({
            Name = "🔄 Auto Hatch",
            Info = "Auto hatches eggs for u",
            CurrentValue = false,
            Flag = "AutoHatchEnabled",
            Callback = function(Value)
                autoHatchEnabled = Value
                if Value then
                    spawn(function()
                        while task.wait(1) do
                            if not autoHatchEnabled then break end

                            local args = {
                                [1] = selectedEgg,
                                [2] = 1
                            }

                            local success = pcall(function()
                                game:GetService("ReplicatedStorage").KPets.Events.Hatch:FireServer(unpack(args))
                            end)

                            if success then
                                ExecutorVars.LogFunction("Hatched " .. selectedEgg)
                            else
                                ExecutorVars.LogFunction("Failed to hatch " .. selectedEgg)
                            end
                        end
                    end)
                    ExecutorVars.LogFunction("Auto Hatch on")

                    Rayfield:Notify({
                        Title = "Auto Hatch On",
                        Content = "Hatching " .. selectedEgg .. " now",
                        Duration = 3,
                        Image = 4483362458,
                    })
                else
                    ExecutorVars.LogFunction("Auto Hatch off")
                end
            end
        })

        PetsTab:CreateToggle({
            Name = "⭐ Auto Equip Best",
            Info = "Equips ur best pets automatically",
            CurrentValue = false,
            Flag = "AutoEquipEnabled",
            Callback = function(Value)
                autoEquipEnabled = Value

                if Value then
                    spawn(function()
                        while autoEquipEnabled do
                            local success = pcall(function()
                                game:GetService("ReplicatedStorage").KPets.Events.EquipBest:FireServer()
                            end)

                            if success then
                                ExecutorVars.LogFunction("Equipped best pets")
                            end

                            task.wait(5)  
                        end
                    end)
                    ExecutorVars.LogFunction("Auto Equip Best on")
                else
                    ExecutorVars.LogFunction("Auto Equip Best off")
                end
            end
        })

        local LogSection = LogsTab:CreateSection("Action Logs")

        local CashInfoParagraph = LogsTab:CreateParagraph({
            Title = "Cash Info",
            Content = "Loading..."
        })

        local function updateCashInfo()
            local currentCash = getPlayerCash()
            local nextDrill = getNextDrill()

            local content = string.format("Cash: $%s", formatNumber(currentCash))

            if nextDrill then
                content = content .. string.format("\nNext Drill: %s", nextDrill.name)
                content = content .. string.format("\nPrice: $%s", formatNumber(nextDrill.price))
                content = content .. string.format("\nNeeded: $%s", formatNumber(nextDrill.needed))
            else
                content = content .. "\nU own all cash drills!"
            end

            CashInfoParagraph:Set({
                Title = "Cash Info",
                Content = content
            })
        end

        local LogBox = LogsTab:CreateParagraph({
            Title = "Recent Actions",
            Content = ""
        })

        ExecutorVars.LogFunction = function(action)
            if not LogBox then return end

            local timestamp = os.date("%H:%M:%S")
            local currentContent = LogBox.Content or ""

            local lines = {}
            for line in (currentContent .. "\n"):gmatch("([^\n]*)\n") do
                if line ~= "" then
                    table.insert(lines, line)
                end
            end

            while #lines > 9 do
                table.remove(lines, 1)
            end

            table.insert(lines, string.format("[%s] %s", timestamp, tostring(action)))

            pcall(function()
                LogBox:Set({
                    Title = "Recent Actions",
                    Content = table.concat(lines, "\n")
                })

                updateCashInfo()
            end)
        end

        LogsTab:CreateButton({
            Name = "Refresh Cash",
            Callback = function()
                updateCashInfo()
                ExecutorVars.LogFunction("Refreshed cash info")
            end
        })

        updateCashInfo()

        local AutoFarmSection = AutoFarmTab:CreateSection("AutoFarm Section")

        ExecutorVars.CashSpeedSlider = AutoFarmTab:CreateSlider({
            Name = "Auto Cash Speed",
            Range = {1, 100},
            Increment = 1,
            Suffix = "x",
            CurrentValue = 5,
            Flag = "AutoCashSpeedSlider",
            Callback = function(Value)
                pcall(function()  
                    ExecutorVars.LogFunction("Cash speed set to " .. tostring(Value) .. "x")
                end)
            end
        })

        AutoFarmTab:CreateToggle({
            Name = "Auto Cash",
            Flag = "AutoCashToggle",
            Callback = function(Value)
                if Value then
                    ExecutorVars.AutoCashEnabled = true
                    ExecutorVars.LogFunction("Auto Cash on")

                    local function autoCash()
                        while ExecutorVars.AutoCashEnabled do
                            local player = game:GetService("Players").LocalPlayer
                            local character = player.Character

                            local equippedTool = character and character:FindFirstChildOfClass("Tool")

                            if equippedTool then
                                local args = {
                                    [1] = equippedTool
                                }
                                game:GetService("ReplicatedStorage").GiveCash:FireServer(unpack(args))
                                ExecutorVars.LogFunction("Using " .. equippedTool.Name .. " for cash")
                            end

                            local speed = ExecutorVars.CashSpeedSlider and ExecutorVars.CashSpeedSlider.CurrentValue or 5
                            local waitTime = 0.1 / speed
                            wait(waitTime)
                        end
                    end

                    spawn(autoCash)
                else
                    ExecutorVars.AutoCashEnabled = false
                    ExecutorVars.LogFunction("Auto Cash off")
                end
            end
        })

        AutoFarmTab:CreateToggle({
            Name = "Auto Equip Drill",
            Flag = "AutoEquipDrillToggle",
            Callback = function(Value)
                if Value then

                    local function autoEquipDrill()
                        while AutoFarmTab.Flags.AutoEquipDrillToggle do
                            local inventory = game:GetService("Players").LocalPlayer.Backpack:GetChildren()
                            for _, item in ipairs(inventory) do
                                if item:IsA("Tool") then
                                    local drillName = item.Name

                                    break
                                end
                            end
                            wait(1)
                        end
                    end
                    spawn(autoEquipDrill)
                else

                end
            end
        })

        AutoFarmTab:CreateToggle({
            Name = "Auto Buy",
            Flag = "AutoBuyToggle",
            Callback = function(Value)
                if Value then

                    local function autoBuy()
                        while AutoFarmTab.Flags.AutoBuyToggle do
                            local nextDrill = getNextDrill()
                            if nextDrill then
                                local currentCash = getPlayerCash()

                                if currentCash >= nextDrill.price then

                                    local buyArgs = {
                                        [1] = nextDrill.name
                                    }
                                    local buyResponse = DrillShop.BuySkin:InvokeServer(unpack(buyArgs))

                                    ExecutorVars.LogFunction("Bought " .. nextDrill.name .. " drill")

                                    local equipArgs = {
                                        [1] = nextDrill.name,
                                        [2] = true
                                    }
                                    local equipResponse = DrillShop.EquipSkin:InvokeServer(unpack(equipArgs))

                                    ExecutorVars.LogFunction("Equipped " .. nextDrill.name .. " drill")

                                    updateDrillsInfo()
                                    updateCashInfo()
                                end
                            else

                                AutoFarmTab.Flags.AutoBuyToggle = false
                                ExecutorVars.LogFunction("Auto Buy off - No more drills")
                            end
                            wait(1) 
                        end
                    end

                    spawn(autoBuy)
                    ExecutorVars.LogFunction("Auto Buy on")
                else
                    ExecutorVars.LogFunction("Auto Buy off")
                end
            end
        })

        AutoFarmTab:CreateToggle({
            Name = "Auto Mine",
            Flag = "AutoMineToggle",
            Callback = function(Value)
                if Value then

                else

                end
            end
        })

        local BottomSection = AutoFarmTab:CreateSection("🔽 Bottom Farming")

        local autoBottomEnabled = false

        AutoFarmTab:CreateToggle({
            Name = "🔽 Auto Bottom",
            Info = "Teleports to bottom plate for +1 bottom",
            CurrentValue = false,
            Flag = "AutoBottomToggle",
            Callback = function(Value)
                autoBottomEnabled = Value

                if Value then
                    spawn(function()
                        while autoBottomEnabled do
                            local success = teleportToBottom()

                            if success then
                                ExecutorVars.LogFunction("Teleported to bottom plate")
                            else
                                ExecutorVars.LogFunction("Failed to teleport to bottom plate")
                            end

                            task.wait(5)  
                        end
                    end)

                    ExecutorVars.LogFunction("Auto Bottom enabled")

                    Rayfield:Notify({
                        Title = "Auto Bottom Enabled",
                        Content = "Now teleporting to bottom plate",
                        Duration = 3,
                        Image = 4483362458,
                    })
                else
                    ExecutorVars.LogFunction("Auto Bottom disabled")
                end
            end
        })

        AutoFarmTab:CreateButton({
            Name = "Teleport to Bottom Once",
            Callback = function()
                local success = teleportToBottom()

                if success then
                    ExecutorVars.LogFunction("Teleported to bottom plate")

                    Rayfield:Notify({
                        Title = "Teleported",
                        Content = "Successfully teleported to bottom plate",
                        Duration = 2,
                        Image = 4483362458,
                    })
                else
                    ExecutorVars.LogFunction("Failed to teleport to bottom plate")

                    Rayfield:Notify({
                        Title = "Teleport Failed",
                        Content = "Could not teleport to bottom plate",
                        Duration = 2,
                        Image = 4483362458,
                    })
                end
            end
        })

        AutoFarmTab:CreateSlider({
            Name = "Bottom Teleport Interval",
            Info = "Seconds between teleports",
            Range = {1, 30},
            Increment = 1,
            Suffix = "s",
            CurrentValue = 5,
            Flag = "BottomTeleportInterval",
            Callback = function(Value)
                ExecutorVars.LogFunction("Bottom teleport interval set to " .. Value .. "s")
            end
        })

        local DrillsSection = DrillsTab:CreateSection("Drills Info")

        local OwnedDrillsParagraph = DrillsTab:CreateParagraph({
            Title = "Owned Drills",
            Content = "Loading..."
        })

        local UnownedDrillsParagraph = DrillsTab:CreateParagraph({
            Title = "Available Drills (Prices)",
            Content = "Loading..."
        })

        local function updateDrillsInfo()
            local ownedDrills = DrillShop.GetOwnedDrills:InvokeServer()
            local skinPrices = DrillShop.GetSkinPrices:InvokeServer()

            local ownedList = {}
            for drill, isOwned in pairs(ownedDrills) do
                if isOwned == true then
                    table.insert(ownedList, "✓ " .. drill)
                end
            end
            table.sort(ownedList)

            local unownedList = {}
            for drill, info in pairs(skinPrices) do
                if not ownedDrills[drill] or ownedDrills[drill] == false then
                    local price = info.Price
                    local priceStr = tostring(price):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
                    local drillType = info.Type
                    table.insert(unownedList, string.format("• %s (%s) - $%s", drill, drillType, priceStr))
                end
            end
            table.sort(unownedList)

            OwnedDrillsParagraph:Set({
                Title = "Owned Drills",
                Content = #ownedList > 0 and table.concat(ownedList, "\n") or "No drills owned"
            })

            UnownedDrillsParagraph:Set({
                Title = "Available Drills (Prices)",
                Content = #unownedList > 0 and table.concat(unownedList, "\n") or "No drills available"
            })
        end

        DrillsTab:CreateButton({
            Name = "Refresh Drills",
            Callback = function()
                updateDrillsInfo()
                ExecutorVars.LogFunction("Refreshed drills info")
            end
        })

        updateDrillsInfo()

        local AutoCashSection = AdvancedTab:CreateSection("Auto Cash Config")

        AdvancedTab:CreateSlider({
            Name = "Min Cash Delay",
            Info = "Min delay between cash attempts",
            Range = {1, 1000},
            Increment = 1,
            Suffix = "ms",
            CurrentValue = 100,
            Flag = "MinCashDelay",
            Callback = function(Value)
                ExecutorVars.MinCashDelay = Value / 1000
                ExecutorVars.LogFunction("Min Cash Delay: " .. Value .. "ms")
            end
        })

        local AutoBuySection = AdvancedTab:CreateSection("Auto Buy Config")

        AdvancedTab:CreateSlider({
            Name = "Purchase Check Delay",
            Info = "Time between checking if can afford",
            Range = {100, 5000},
            Increment = 100,
            Suffix = "ms",
            CurrentValue = 1000,
            Flag = "PurchaseDelay",
            Callback = function(Value)
                ExecutorVars.PurchaseDelay = Value / 1000
                ExecutorVars.LogFunction("Purchase Check Delay: " .. Value .. "ms")
            end
        })

        AdvancedTab:CreateSlider({
            Name = "Purchase Buffer",
            Info = "Extra cash needed before buying",
            Range = {0, 50},
            Increment = 1,
            Suffix = "%",
            CurrentValue = 0,
            Flag = "PurchaseBuffer",
            Callback = function(Value)
                ExecutorVars.PurchaseBuffer = Value / 100
                ExecutorVars.LogFunction("Purchase Buffer: " .. Value .. "%")
            end
        })

        local SafetySection = AdvancedTab:CreateSection("Safety Features")

        AdvancedTab:CreateSlider({
            Name = "Action Randomization",
            Info = "Adds random delay to actions",
            Range = {0, 1000},
            Increment = 10,
            Suffix = "ms",
            CurrentValue = 0,
            Flag = "RandomDelay",
            Callback = function(Value)
                ExecutorVars.RandomDelay = Value / 1000
                ExecutorVars.LogFunction("Action Randomization: " .. Value .. "ms")
            end
        })

        local ErrorSection = AdvancedTab:CreateSection("Error Handling")

        AdvancedTab:CreateToggle({
            Name = "Auto-Retry Failed Actions",
            Info = "Auto retry failed purchases",
            CurrentValue = true,
            Flag = "AutoRetry",
            Callback = function(Value)
                ExecutorVars.AutoRetry = Value
                ExecutorVars.LogFunction("Auto-Retry " .. (Value and "on" or "off"))
            end
        })

        AdvancedTab:CreateSlider({
            Name = "Retry Delay",
            Info = "Delay before retrying",
            Range = {100, 5000},
            Increment = 100,
            Suffix = "ms",
            CurrentValue = 1000,
            Flag = "RetryDelay",
            Callback = function(Value)
                ExecutorVars.RetryDelay = Value / 1000
                ExecutorVars.LogFunction("Retry Delay: " .. Value .. "ms")
            end
        })

        local PerformanceSection = AdvancedTab:CreateSection("Performance")

        AdvancedTab:CreateSlider({
            Name = "UI Update Frequency",
            Info = "How often to update UI",
            Range = {100, 5000},
            Increment = 100,
            Suffix = "ms",
            CurrentValue = 1000,
            Flag = "UIUpdateDelay",
            Callback = function(Value)
                ExecutorVars.UIUpdateDelay = Value / 1000
                ExecutorVars.LogFunction("UI Update Frequency: " .. Value .. "ms")
            end
        })

        local DebugSection = AdvancedTab:CreateSection("Debug Options")

        local printingCoords = false

        AdvancedTab:CreateToggle({
            Name = "Print Coordinates",
            Info = "Prints current position to F9 console",
            CurrentValue = false,
            Flag = "PrintCoords",
            Callback = function(Value)
                printingCoords = Value

                if Value then
                    spawn(function()
                        while printingCoords do
                            local player = game:GetService("Players").LocalPlayer
                            local character = player.Character

                            if character and character:FindFirstChild("HumanoidRootPart") then
                                local pos = character.HumanoidRootPart.Position
                                local formatted = string.format("Position: Vector3.new(%.2f, %.2f, %.2f)", pos.X, pos.Y, pos.Z)
                                print(formatted)

                                if ExecutorVars.VerboseLogging then
                                    ExecutorVars.LogFunction(formatted)
                                end
                            end

                            task.wait(1) 
                        end
                    end)

                    ExecutorVars.LogFunction("Coordinate printing enabled")
                else
                    ExecutorVars.LogFunction("Coordinate printing disabled")
                end
            end
        })

        AdvancedTab:CreateButton({
            Name = "Print Current Position",
            Info = "Prints current position once to F9",
            Callback = function()
                local player = game:GetService("Players").LocalPlayer
                local character = player.Character

                if character and character:FindFirstChild("HumanoidRootPart") then
                    local pos = character.HumanoidRootPart.Position
                    local formatted = string.format("Current position: Vector3.new(%.2f, %.2f, %.2f)", pos.X, pos.Y, pos.Z)
                    print(formatted)

                    setclipboard(string.format("Vector3.new(%.2f, %.2f, %.2f)", pos.X, pos.Y, pos.Z))

                    ExecutorVars.LogFunction("Position copied to clipboard")

                    Rayfield:Notify({
                        Title = "Position Copied",
                        Content = "Current position copied to clipboard",
                        Duration = 3,
                        Image = 4483362458,
                    })
                else
                    ExecutorVars.LogFunction("Failed to get position")
                end
            end
        })

        AdvancedTab:CreateButton({
            Name = "Set Bottom Position",
            Info = "Sets current position as bottom teleport target",
            Callback = function()
                local player = game:GetService("Players").LocalPlayer
                local character = player.Character

                if character and character:FindFirstChild("HumanoidRootPart") then
                    local pos = character.HumanoidRootPart.Position

                    local oldFunc = teleportToBottom

                    _G.teleportToBottom = function()
                        local player = game:GetService("Players").LocalPlayer
                        local character = player.Character

                        if character and character:FindFirstChild("HumanoidRootPart") then
                            character.HumanoidRootPart.CFrame = CFrame.new(pos)
                            return true
                        end

                        return false
                    end

                    teleportToBottom = _G.teleportToBottom

                    ExecutorVars.LogFunction("Bottom position updated")

                    Rayfield:Notify({
                        Title = "Bottom Position Updated",
                        Content = "Current position set as bottom teleport target",
                        Duration = 3,
                        Image = 4483362458,
                    })
                else
                    ExecutorVars.LogFunction("Failed to set bottom position")
                end
            end
        })

        AdvancedTab:CreateToggle({
            Name = "Verbose Logging",
            Info = "Show more detailed logs",
            CurrentValue = false,
            Flag = "VerboseLogging",
            Callback = function(Value)
                ExecutorVars.VerboseLogging = Value
                ExecutorVars.LogFunction("Verbose Logging " .. (Value and "on" or "off"))
            end
        })

        AdvancedTab:CreateButton({
            Name = "Reset All Settings",
            Info = "Reset everything to default",
            Callback = function()

                ExecutorVars.MinCashDelay = 0.1
                ExecutorVars.PurchaseDelay = 1
                ExecutorVars.PurchaseBuffer = 0
                ExecutorVars.RandomDelay = 0
                ExecutorVars.AutoRetry = true
                ExecutorVars.RetryDelay = 1
                ExecutorVars.UIUpdateDelay = 1
                ExecutorVars.VerboseLogging = false

                for _, flag in pairs({
                    "MinCashDelay", "PurchaseDelay", "PurchaseBuffer",
                    "RandomDelay", "AutoRetry", "RetryDelay",
                    "UIUpdateDelay", "VerboseLogging"
                }) do
                    Rayfield.Flags[flag]:Set(ExecutorVars[flag])
                end

                ExecutorVars.LogFunction("Reset all settings to default")
            end
        })

        Rayfield:LoadConfiguration()
    end)

    if not success then
        warn("UI Creation Error: " .. tostring(errorMsg))

        local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
        local Window = Rayfield:CreateWindow({
            Name = "⛏️ Drill Drill Drill - Error",
            LoadingTitle = "Error Occurred",
            LoadingSubtitle = "Please report this to Fizz",
        })

        local ErrorTab = Window:CreateTab("❌ Error", 4483362458)

        ErrorTab:CreateParagraph({
            Title = "Script Error",
            Content = "An error occurred while loading the script:\n\n" .. tostring(errorMsg)
        })

        ErrorTab:CreateButton({
            Name = "Copy Error to Clipboard",
            Callback = function()
                setclipboard(tostring(errorMsg))
            end
        })
    end
end

createUI()
