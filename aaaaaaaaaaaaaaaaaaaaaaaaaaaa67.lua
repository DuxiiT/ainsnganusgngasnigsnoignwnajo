_G.AutoStrat = true

local SendRequest = request or http_request or httprequest or syn and syn.request or fluxus and fluxus.request or GetDevice and GetDevice().request
if not SendRequest then warn("No HTTP request function found.") return end

---------------------------------------------------------------------
-- SERVICES
---------------------------------------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remote = ReplicatedStorage:WaitForChild("RemoteFunction")
local RemoteEvent = ReplicatedStorage:WaitForChild("RemoteEvent")
local NetworkModifiers = ReplicatedStorage:WaitForChild("Network"):WaitForChild("Modifiers"):WaitForChild("RF:BulkVoteModifiers")
local LocalPlayer = game.Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local WebhookURL = "https://discord.com/api/webhooks/1443621075605786665/ZtvYggbqbqe_6cuDwVo5864BAIxm5COiMcxhRHFBF_KP953-MSeZ5ruKnZp4utZqtXbq"

local StartCoins = LocalPlayer.Coins.Value
local TotalCoins = StartCoins
local GamesPlayed = 0
local ScriptStart = os.time()

print("[AutoStrat] Script started. StartCoins:", StartCoins)

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------

local function log(section, message)
    print(string.format("[%s | %s] %s", os.date("%H:%M:%S"), section, message))
end

local function is_successful_response(res)
    if res == true then return true end
    if type(res) == "table" and res.Success == true then return true end

    local ok, isModel = pcall(function()
        return res and res:IsA("Model")
    end)
    if ok and isModel then return true end

    if type(res) == "userdata" then return true end

    return false
end

---------------------------------------------------------------------
-- SKIP VOTE (Universal Skip)
---------------------------------------------------------------------
local function VoteSkip()
    log("VoteSkip", "Sending skip request...")
    repeat
        local ok = pcall(function()
            Remote:InvokeServer("Voting", "Skip")
        end)
        if ok then
            log("VoteSkip", "Skip invoked successfully.")
            break
        else
            log("VoteSkip", "Skip failed, retrying...")
        end
        task.wait(0.15)
    until false
end

-- Override Lobby Voting
local function OverrideLobby(mapName)
    mapName = mapName or "Simplicity"
    local args = {
        "LobbyVoting",
        "Override",
        mapName
    }

    local success, err = pcall(function()
        Remote:InvokeServer(unpack(args))
    end)

    if success then
        log("LobbyVoting", "Override sent for map: "..mapName)
    else
        log("LobbyVoting", "Failed to override: "..tostring(err))
    end
end

-- Vote Modifiers
local function VoteModifiers(modifiers)
    modifiers = modifiers or {
        HiddenEnemies = true,
        Glass = true,
        ExplodingEnemies = true,
        Limitation = true,
        Committed = true,
        Fog = true
    }

    local args = {modifiers}

    local success, err = pcall(function()
        NetworkModifiers:InvokeServer(unpack(args))
    end)

    if success then
        log("Modifiers", "Modifiers voted successfully.")
    else
        log("Modifiers", "Failed to vote modifiers: "..tostring(err))
    end
end

-- Cast Lobby Vote
local function VoteLobby(mapName, positionVector)
    mapName = mapName or "Simplicity"
    positionVector = positionVector or Vector3.new(0,0,0)

    local args = {
        "LobbyVoting",
        "Vote",
        mapName,
        positionVector
    }

    local success, err = pcall(function()
        RemoteEvent:FireServer(unpack(args))
    end)

    if success then
        log("LobbyVoting", "Vote cast for map: "..mapName)
    else
        log("LobbyVoting", "Failed to cast vote: "..tostring(err))
    end
end

-- Ready Up
local function ReadyUp()
    local args = {
        "LobbyVoting",
        "Ready"
    }

    local success, err = pcall(function()
        RemoteEvent:FireServer(unpack(args))
    end)

    if success then
        log("LobbyVoting", "Ready signal sent.")
    else
        log("LobbyVoting", "Failed to send Ready: "..tostring(err))
    end
end

---------------------------------------------------------------------
-- READY VOTE SCREEN DETECTOR
---------------------------------------------------------------------
local function Ready()
    log("Ready", "Waiting for ReactOverridesVote...")

    local root
    repeat
        root = PlayerGui:FindFirstChild("ReactOverridesVote")
        if not root then
            log("Ready", "ReactOverridesVote missing. Waiting...")
            task.wait(0.25)
        end
    until root
    log("Ready", "ReactOverridesVote found.")

    local frame
    repeat
        frame = root:FindFirstChild("Frame")
        if not frame then
            log("Ready", "Frame missing. Waiting...")
            task.wait(0.25)
        end
    until frame
    log("Ready", "Frame found.")

    local votes
    repeat
        votes = frame:FindFirstChild("votes")
        if not votes then
            log("Ready", "votes missing. Waiting...")
            task.wait(0.25)
        end
    until votes
    log("Ready", "votes found. Sending skip...")

    VoteSkip()
    log("Ready", "Ready-up completed.")
end

---------------------------------------------------------------------
-- RESTART GAME DETECTOR
---------------------------------------------------------------------
local function RestartGame()
    log("RestartGame", "Waiting for rewards screen...")
    local root = PlayerGui:WaitForChild("ReactGameNewRewards")

    local rewardsSection = nil

    repeat
        task.wait(0.25)

        local frame = root:FindFirstChild("Frame")
        if frame then
            local gameOver = frame:FindFirstChild("gameOver")
            if gameOver then
                local rewardsScreen = gameOver:FindFirstChild("RewardsScreen")
                if rewardsScreen then
                    rewardsSection = rewardsScreen:FindFirstChild("RewardsSection")
                end
            end
        end
    until rewardsSection

    log("RestartGame", "RewardsSection detected.")
    task.wait(3)
    log("RestartGame", "Match ended. Sending skip...")

    VoteSkip()
end


---------------------------------------------------------------------
-- GET COINS
---------------------------------------------------------------------
local function GetCoinsAfterMatch()
    log("Coins", "Scanning rewards for coins...")
    local rewardsSection = nil
    local root = PlayerGui:WaitForChild("ReactGameNewRewards")

    repeat
        task.wait(0.25)

        local frame = root:FindFirstChild("Frame")
        if frame then
            local gameOver = frame:FindFirstChild("gameOver")
            if gameOver then
                local rewardsScreen = gameOver:FindFirstChild("RewardsScreen")
                if rewardsScreen then
                    rewardsSection = rewardsScreen:FindFirstChild("RewardsSection")
                end
            end
        end
    until rewardsSection

    for _, reward in ipairs(rewardsSection:GetChildren()) do
        if tonumber(reward.Name) then
            local icon = reward:FindFirstChild("icon")
            if icon then
                for _, obj in ipairs(icon:GetDescendants()) do
                    if obj:IsA("TextLabel") and obj.Text and obj.Text:find("Coins") then
                        local num = tonumber(obj.Text:match("(%d+)"))
                        log("Coins", "Found coin reward: "..(num or 0))
                        return num or 0
                    end
                end
            end
        end
    end

    log("Coins", "No coin reward found.")
    return 0
end

---------------------------------------------------------------------
-- TELEPORT AFTER MATCH
---------------------------------------------------------------------
local function TeleportAfterMatch()
    log("Teleport", "Waiting for RewardsSection...")

    local rewardsSection = nil
    local root = PlayerGui:WaitForChild("ReactGameNewRewards")

    repeat
        task.wait(0.25)

        local frame = root:FindFirstChild("Frame")
        if frame then
            local gameOver = frame:FindFirstChild("gameOver")
            if gameOver then
                local rewardsScreen = gameOver:FindFirstChild("RewardsScreen")
                if rewardsScreen then
                    rewardsSection = rewardsScreen:FindFirstChild("RewardsSection")
                end
            end
        end
    until rewardsSection

    log("Teleport", "RewardsSection found, meaning game is over. Teleporting...")

    local TeleportService = game:GetService("TeleportService")
    local targetGameId = 3260590327

    pcall(function()
        TeleportService:Teleport(targetGameId, LocalPlayer)
    end)
end

---------------------------------------------------------------------
-- WEBHOOK
---------------------------------------------------------------------
local function SendWebhook(totalCoins, gained)
    log("Webhook", "Preparing webhook... Gained="..gained.." Total="..totalCoins)

    local elapsed = os.time() - ScriptStart
    local hours = math.floor(elapsed / 3600)
    local minutes = math.floor((elapsed % 3600) / 60)

    local payload = {
        username = "🎮 TDS AutoStrat Log",
        embeds = {{
            title = "✅ Match Completed!",
            color = 0x00FF99,
            fields = {
                { name = "🕹 Games Played", value = "**"..GamesPlayed.."**", inline = true },
                { name = "💰 Coins Earned", value = "**"..gained.."**", inline = true },
                { name = "🏆 Total Coins", value = "**"..totalCoins.."**", inline = true },
                { name = "⏱ Runtime", value = "**"..hours.."h "..minutes.."m**" },
            },
            footer = { text = "TDS AutoStrat | Keep farming! 🚀" },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ", os.time())
        }}
    }

    SendRequest({
        Url = WebhookURL,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = game:GetService("HttpService"):JSONEncode(payload)
    })

    log("Webhook", "Webhook sent successfully.")
end

---------------------------------------------------------------------
-- REPORT COINS
---------------------------------------------------------------------
local function ReportCoins()
    task.wait(1)
    local gained = GetCoinsAfterMatch()
    GamesPlayed += 1
    TotalCoins += gained

    log("Report", string.format(
        "Match %d complete | Gained: %d | Total: %d",
        GamesPlayed, gained, TotalCoins
    ))

    SendWebhook(TotalCoins, gained)
end


---------------------------------------------------------------------
-- TOWER ENGINE
---------------------------------------------------------------------
local TDS = {}
TDS.PlacedTowers = {}

local TowerUpgrades = {} -- track upgrades per tower

local function placeTower(towerName, position)
    while true do
        local ok, res = pcall(function()
            return Remote:InvokeServer("Troops", "Pl\208\176ce", {
                Rotation = CFrame.new(),
                Position = position
            }, towerName)
        end)

        if ok and is_successful_response(res) then
            return true
        end

        task.wait(0.25)
    end
end

local function upgradeTower(tower, pathNumber)
    while true do
        local ok, res = pcall(function()
            return Remote:InvokeServer("Troops", "Upgrade", "Set", {
                Troop = tower,
                Path = pathNumber
            })
        end)
        if ok and is_successful_response(res) then
            return true
        end
        task.wait(0.25)
    end
end


local function setTroopOption(tower, optionName, optionValue)
    while true do
        local ok, res = pcall(function()
            return Remote:InvokeServer("Troops", "Option", "Set", {
                Troop = tower,
                Name = optionName,
                Value = optionValue
            })
        end)

        if ok and is_successful_response(res) then
            return true
        end

        task.wait(0.25)
    end

    -- Mercenary Base:
    -- "Unit 1 or 2 or 3" -- > "Grenadier or Rifleman or Riot Guard or Field Medic"

    -- Trapper:
    -- "Trap" --> "Spike or Landmine"
end

-- Commander:
-- "Call Of Arms" (No extra data)
-- "Support Caravan" (No extra data)

-- Medic:
-- "Ubercharge" (No extra data)

-- Hacker:
-- "Hologram Tower" (Extra data under)
-- towerToClone = towerindex (1,2,3,4 etc),
-- towerPosition = Vector3.new(-17.41, 0.97, -14.77) (This is where the copied tower will be placed)

-- Pursuit:
-- "Patrol" (Extra data under)
-- ["position"] = Vector3.new(-15.190120697021484, 1.069571614265442, -7.495200157165527) (This is where the Pursuit will be on)

-- Gatling Gun:
-- "FPS" (Extra data under)
-- ["enabled"] = true (This is if you want to go in FPS mode with Gatling)
-- ["enabled"] = false (This is if you want to go out of FPS mode with Gatling)

-- Brawler:
-- "Reposition" (Extra data under)
-- ["position"] = Vector3.new(12.936247825622559, 0.969571590423584, -30.24891471862793) (This is where the Brawler will move to)

-- Mercernary Base:
-- "Air-Drop" (Extra data under)
-- ["pathName"] = 1;
-- ["directionCFrame"] = CFrame.new(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1) -- this doesnt really matter
-- ["dist"] = 156 -- this matters alot, but the problem with it is that you cant really grab it anywhere but you gotta test different numbers, 156 is the highest for the map Simplicity as this is basically at the back of the path. (So anything inbetween 0-200) is what you normally need to test, otherwise just set it at let's say 999 and that will basically make it stuck at the end of the path for a while and sooner or later it'll start walking out

-- Military Base:
-- "Airstrike"
-- ["pathName"] = 1,
-- ["pointToEnd"] = 57.86184847354889, -- this matters alot, but the problem with it is that you cant really grab it anywhere but you gotta test different numbers, 156 is the highest for the map Simplicity as this is basically at the back of the path. (So anything inbetween 0-200) is what you normally need to test, otherwise just set it at let's say 999 and that will basically make it stuck at the end of the path for a while and sooner or later it'll start walking out
-- ["directionCFrame"] = CFrame.new(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1) -- this doesnt really matter

local function activateAbility(tower, abilityName, data)
    data = data or {} -- default empty table

    -- Convert tower numbers to actual instances if needed
    if data.towerToClone and type(data.towerToClone) == "number" then
        data.towerToClone = TDS.PlacedTowers[data.towerToClone]
    end

    if data.towerTarget and type(data.towerTarget) == "number" then
        data.towerTarget = TDS.PlacedTowers[data.towerTarget]
    end

    while true do
        local ok, res = pcall(function()
            return Remote:InvokeServer("Troops", "Abilities", "Activate", {
                Troop = tower,
                Name = abilityName,
                Data = data
            })
        end)

        if ok and is_successful_response(res) then
            return true
        end

        task.wait(0.25)
    end
end

-- TICKETS
local function MainTimeScale()
    ReplicatedStorage.RemoteFunction:InvokeServer(
        'TicketsManager',
        'UnlockTimeScale'
    )
end

local function MainUseTimeScale()
    ReplicatedStorage.RemoteFunction:InvokeServer(
        'TicketsManager',
        'CycleTimeScale'
    )
end

function TDS:Place(name, x, y, z)
    local before = {}
    for _, t in ipairs(workspace.Towers:GetChildren()) do
        before[t] = true
    end

    placeTower(name, Vector3.new(x, y, z))

    local newTower
    repeat
        for _, t in ipairs(workspace.Towers:GetChildren()) do
            if not before[t] then
                newTower = t
                break
            end
        end
        task.wait(0.05)
    until newTower

    table.insert(self.PlacedTowers, newTower)
    return #self.PlacedTowers
end

-- Wrap TDS:Upgrade to track upgrades
local oldUpgrade = function(self, index, path)
    local tower = self.PlacedTowers[index]
    if tower then
        upgradeTower(tower, path or 1)
        TowerUpgrades[index] = (TowerUpgrades[index] or 0) + 1
    end
end
function TDS:Upgrade(index, path)
    oldUpgrade(self, index, path)
end

local HackerPositions = {
    Vector3.new(14.0727997, 3.46938467, 16.696434),
    Vector3.new(13.7722702, 3.46936917, 9.73488903),
    Vector3.new(8.10887527, 3.4693706, 9.26754189),
    Vector3.new(1.69235086, 2.0586009, 9.3474369)
}

local HackerIndex = 1 -- keep track of current position

local function AutoMercenaryAbility()
    spawn(function()
        while _G.AutoStrat do
            for i, tower in ipairs(TDS.PlacedTowers) do
                -- Auto Mercenary Base
                if tower.Name == "Graveyard" then
                    local success, err = pcall(function()
                        activateAbility(tower, "Air-Drop", {
                            pathName = 1,
                            directionCFrame = CFrame.new(0,0,0),
                            dist = 150
                        })
                    end)
                    if success then
                        log("Mercenary", "Air-Drop used for tower #" .. i)
                    else
                        log("Mercenary", "Failed Air-Drop: "..tostring(err))
                    end
                end

                -- Hacker Hologram
                if tower.Name == "Hacker" then
                    local targetIndex = 19 -- tower to clone
                    if TDS.PlacedTowers[targetIndex] then
                        local pos = HackerPositions[HackerIndex]
                        local success, err = pcall(function()
                            activateAbility(tower, "Hologram Tower", {
                                towerToClone = targetIndex,
                                towerPosition = pos
                            })
                        end)
                        if success then
                            log("Hacker", "Hologram Tower used for tower #" .. i .. " at position #" .. HackerIndex)
                            -- move to next position
                            HackerIndex = HackerIndex + 1
                            if HackerIndex > #HackerPositions then
                                HackerIndex = 1
                            end
                        else
                            log("Hacker", "Failed Hologram Tower: "..tostring(err))
                        end
                    else
                        log("Hacker", "Target tower for Hologram not ready yet.")
                    end
                end
            end
            task.wait(5)
        end
    end)
end

AutoMercenaryAbility() -- start background

while _G.AutoStrat do
    OverrideLobby("Simplicity")
    VoteModifiers()
    VoteLobby("Simplicity", Vector3.new(12.59, 10.64, 52.01))
    ReadyUp()

	task.wait(7)

    Ready()

    TDS:Place("Shotgunner", -18.2444096, 2.35000038, -2.11120796, 1, 0, 0, 0, 1, 0, 0, 0, 1) -- 1
    TDS:Place("Shotgunner", -18.1074963, 2.35000086, -4.19810009, 1, 0, 0, 0, 1, 0, 0, 0, 1) -- 2
    TDS:Place("Shotgunner", -18.2207069, 2.34998345, -6.32968712, 1, 0, 0, 0, 1, 0, 0, 0, 1) -- 3

    TDS:Place("Farm", -21.2611122, 2.05861616, 9.60305405, 1, 0, 0, 0, 1, 0, 0, 0, 1) -- 4
    TDS:Upgrade(4)
    TDS:Upgrade(4)

    TDS:Upgrade(1)
    TDS:Upgrade(1)
    TDS:Upgrade(2)
    TDS:Upgrade(2)
    TDS:Upgrade(3)
    TDS:Upgrade(3)

    TDS:Upgrade(4)

    TDS:Place("Farm", -17.5390682, 2.05861616, 9.54426956, 1, 0, 0, 0, 1, 0, 0, 0, 1) -- 5
    TDS:Upgrade(5)
    TDS:Upgrade(5)
    TDS:Upgrade(5)

    TDS:Place("Military Base", 21.2580929, 0.999991834, 2.33692908, 1, 0, 0, 0, 1, 0, 0, 0, 1) -- 6
    TDS:Place("Military Base", 25.9344501, 0.999991179, 2.33882356, 1, 0, 0, 0, 1, 0, 0, 0, 1) -- 7
    TDS:Upgrade(6)
    TDS:Upgrade(7)
    TDS:Upgrade(6)
    TDS:Upgrade(7)
    TDS:Upgrade(6)
    TDS:Upgrade(7)

    TDS:Place("Farm", -21.2268219, 2.05861545, 13.2982063, 1, 0, 0, 0, 1, 0, 0, 0, 1) -- 8
    TDS:Upgrade(8)
    TDS:Upgrade(8)
    TDS:Upgrade(8)


    TDS:Place("Farm", -17.3977451, 2.05861545, 13.4780464, 1, 0, 0, 0, 1, 0, 0, 0, 1) -- 9
    TDS:Upgrade(9)
    TDS:Upgrade(9)
    TDS:Upgrade(9)

    TDS:Place("Farm", -13.6051178, 2.05861616, 9.3183012, 1, 0, 0, 0, 1, 0, 0, 0, 1) -- 10
    TDS:Upgrade(10)
    TDS:Upgrade(10)
    TDS:Upgrade(10)

    TDS:Place("Farm", -13.5365696, 2.50634384, 13.4370337, 1, 0, 0, 0, 1, 0, 0, 0, 1)-- 11
    TDS:Upgrade(11)
    TDS:Upgrade(11)
    TDS:Upgrade(11)

    TDS:Place("Farm", -9.79834652, 2.05861616, 9.56763935, 1, 0, 0, 0, 1, 0, 0, 0, 1) -- 12
    TDS:Upgrade(12)
    TDS:Upgrade(12)
    TDS:Upgrade(12)

    TDS:Place("Farm", -9.90616417, 2.92481112, 13.4517527, 1, 0, 0, 0, 1, 0, 0, 0, 1) -- 13
    TDS:Upgrade(13)
    TDS:Upgrade(13)
    TDS:Upgrade(13)

    TDS:Upgrade(6)
    TDS:Upgrade(7)

    TDS:Place("Military Base", 26.3864651, 0.999987066, 6.92674494, 1, 0, 0, 0, 1, 0, 0, 0, 1)-- 14
    TDS:Upgrade(14)
    TDS:Upgrade(14)
    TDS:Upgrade(14)

    TDS:Place("Military Base", 25.3445587, 0.999998093, 11.9134378, 1, 0, 0, 0, 1, 0, 0, 0, 1) -- 15
    TDS:Upgrade(15)
    TDS:Upgrade(15)
    TDS:Upgrade(15)

    TDS:Place("Military Base", 20.7863598, 0.999997973, 12.4927025, 1, 0, 0, 0, 1, 0, 0, 0, 1) -- 16
    TDS:Upgrade(16)
    TDS:Upgrade(16)
    TDS:Upgrade(16)

    TDS:Upgrade(14)
    TDS:Upgrade(15)
    TDS:Upgrade(16)

    TDS:Place("Hacker", -23.8852863, 2.40311527, -0.322607517, 1, 0, 0, 0, 1, 0, 0, 0, 1) -- 17
    TDS:Place("Hacker", -11.4988575, 2.40310717, -9.18709946, 1, 0, 0, 0, 1, 0, 0, 0, 1) -- 18

    TDS:Upgrade(17)
    TDS:Upgrade(17)

    TDS:Upgrade(18)
    TDS:Upgrade(18)

    TDS:Place("Mercenary Base", 21.2219849, 3.46938634, 7.49417973, 1, 0, 0, 0, 1, 0, 0, 0, 1) -- 19
    TDS:Place("Mercenary Base", 20.1408691, 3.46938443, 18.6890182, 1, 0, 0, 0, 1, 0, 0, 0, 1) -- 20
    TDS:Place("Mercenary Base", 24.8927498, 3.46938443, 18.7783165, 1, 0, 0, 0, 1, 0, 0, 0, 1) -- 21

    TDS:Upgrade(19)
    TDS:Upgrade(20)
    TDS:Upgrade(21)

    TDS:Upgrade(19)
    TDS:Upgrade(20)
    TDS:Upgrade(21)

    TDS:Upgrade(19)
    TDS:Upgrade(20)
    TDS:Upgrade(21)

    TDS:Upgrade(19)
    TDS:Upgrade(19)
    TDS:Upgrade(19)

    TDS:Upgrade(20)
    TDS:Upgrade(20)
    TDS:Upgrade(20)

    TDS:Upgrade(21)
    TDS:Upgrade(21)
    TDS:Upgrade(21)

    TDS:Upgrade(6)
    TDS:Upgrade(7)
    TDS:Upgrade(14)
    TDS:Upgrade(15)
    TDS:Upgrade(16)

    TDS:Upgrade(17)
    TDS:Upgrade(18)

	TDS:Upgrade(17)
    TDS:Upgrade(18)

	TDS:Upgrade(17, 2)
    TDS:Upgrade(18, 2)

	task.wait(70)

	setTroopOption(TDS.PlacedTowers[19], "Unit 1", "Riot Guard")
	setTroopOption(TDS.PlacedTowers[19], "Unit 2", "Riot Guard")
	setTroopOption(TDS.PlacedTowers[19], "Unit 3", "Riot Guard")

	setTroopOption(TDS.PlacedTowers[20], "Unit 1", "Riot Guard")
	setTroopOption(TDS.PlacedTowers[20], "Unit 2", "Riot Guard")
	setTroopOption(TDS.PlacedTowers[20], "Unit 3", "Riot Guard")

	setTroopOption(TDS.PlacedTowers[21], "Unit 1", "Riot Guard")
	setTroopOption(TDS.PlacedTowers[21], "Unit 2", "Riot Guard")
	setTroopOption(TDS.PlacedTowers[21], "Unit 3", "Field Medic")

	GetCoinsAfterMatch()

	TeleportAfterMatch()
end
