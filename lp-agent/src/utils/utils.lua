local enums = require('libs.enums')
local bint = require ".bint"(1024)

local utils = {
    add = function(a, b) return tostring(bint(a) + bint(b)) end,
    subtract = function(a, b) return tostring(bint(a) - bint(b)) end,
    mul = function(a, b) return tostring(bint.__mul(bint(a), bint(b))) end,
    div = function(a, b) return tostring(bint.udiv(bint(a), bint(b))) end,
    lt = function(a, b) return bint.__lt(bint(a), bint(b)) end,
    lte = function(a, b) return bint.__lt(bint(a), bint(b)) or bint.__eq(bint(a), bint(b)) end,
    gt = function(a, b) return bint.__lt(bint(b), bint(a)) end,
    gte = function(a, b) return bint.__lt(bint(b), bint(a)) or bint.__eq(bint(b), bint(a)) end,
    isZero = function(a) return bint.__eq(bint(a), bint("0")) end,
    isEqual = function(a, b) return bint.__eq(bint(a), bint(b)) end
}

-- Address validation
function utils.isAddress(addr)
    if type(addr) ~= "string" then return false end
    if string.len(addr) ~= 43 then return false end
    if string.match(addr, "^[A-z0-9_-]+$") == nil then return false end
    return true
end

-- Number validation
function utils.isValidNumber(val)
    return type(val) == "number" and val == val and val ~= math.huge and val ~= -math.huge
end

function utils.isValidInteger(val)
    return utils.isValidNumber(val) and val % 1 == 0
end

function utils.isBintRaw(val)
    local success, result = pcall(function()
        if type(val) ~= "number" and type(val) ~= "string" and not bint.isbint(val) then return false end
        if type(val) == "number" and not utils.isValidInteger(val) then return false end
        return true
    end)
    return success and result
end

-- Token quantity validation
function utils.isTokenQuantity(qty)
    local numVal = tonumber(qty)
    if not numVal or numVal <= 0 then return false end
    if not utils.isBintRaw(qty) then return false end
    if type(qty) == "number" and qty < 0 then return false end
    if type(qty) == "string" and string.sub(qty, 1, 1) == "-" then return false end
    return true
end

-- Percentage validation
function utils.isPercentage(val)
    if not val or type(val) ~= "number" then return false end
    return val // 1 == val and val >= 0 and val <= 100
end

-- DEX validation
function utils.isValidDex(val)
    return val == enums.DexType.PERMASWAP or
           val == enums.DexType.BOTEGA or
           val == enums.DexType.AUTO
end

-- Slippage validation
function utils.isValidSlippage(val)
    if not val or type(val) ~= "number" then return false end
    return val // 1 == val and val >= 0.5 and val <= 10
end

-- Running time validation
function utils.isValidRunningTime(startDate, endDate)
    if not startDate or not endDate then return false end
    return startDate <= endDate
end

-- Boolean validation
function utils.isValidBoolean(val)
    return val == "true" or val == "false"
end

-- Status validation
function utils.isValidStatus(val)
    return val == enums.AgentStatus.ACTIVE or
           val == enums.AgentStatus.PAUSED or
           val == enums.AgentStatus.COMPLETED or
           val == enums.AgentStatus.CANCELLED
end

-- Agent version validation
function utils.isValidAgentVersion(version)
    if not version or type(version) ~= "string" then return false end
    local major, minor, patch = version:match("^(%d+)%.(%d+)%.(%d+)$")
    if not major then return false end
    major = tonumber(major)
    minor = tonumber(minor)
    patch = tonumber(patch)
    if not major or not minor or not patch then return false end
    if major < 0 or minor < 0 or patch < 0 then return false end
    return true
end

-- Strategy validation
function utils.isValidStrategy(val)
    return val == enums.StrategyType.SWAP_50_LP_50 or
           val == enums.StrategyType.CUSTOM
end

-- Check if end date has been reached
function utils.hasReachedEndDate()
    if not EndDate then return false end
    local currentTime = os.time()
    local processedOrSwapped = (ProcessedUpToDate or SwappedUpToDate or 0)
    return currentTime >= EndDate and currentTime >= processedOrSwapped
end

-- Check if the current time is within the configured active window
function utils.isWithinActiveWindow(now)
    local t = now or os.time()
    -- If running indefinitely, only require start date reached
    if RunIndefinitely then
        return t >= StartDate
    end
    if not StartDate or not EndDate then return false end
    return t >= StartDate and t <= EndDate
end

-- Split quantity into two parts based on percentage
function utils.splitQuantity(quantity, percentage)
    local qty = bint(quantity)
    local splitAmount = bint.udiv(bint.__mul(qty, bint(percentage)), bint(100))
    local remainder = bint.__sub(qty, splitAmount)
    return tostring(splitAmount), tostring(remainder)
end

-- Calculate minimum output after slippage
function utils.calculateMinOutput(amount, slippagePercent)
    local adjustedSlippage = math.floor(slippagePercent * 100)
    return utils.div(utils.mul(amount, utils.subtract(10000, adjustedSlippage)), 10000)
end

return utils
