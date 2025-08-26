do
local _ENV = _ENV
package.preload[ "libs.assertions" ] = function( ... ) local arg = _G.arg;
---@diagnostic disable: undefined-global
local utils = require('utils.utils')
local enums = require('libs.enums')

local mod = {}

-- Validate token quantity
function mod.isTokenQuantity(name, quantity)
    local numQuantity = tonumber(quantity)
    assert(utils.isTokenQuantity(numQuantity),
        "Invalid quantity `" .. name .. "`. Must be a valid token quantity.")
end

-- Validate address
function mod.isAddress(name, value)
    assert(utils.isAddress(value),
        "Invalid address `" .. name .. "`. Must be a valid Arweave address.")
end

-- Validate percentage
function mod.isPercentage(name, value)
    assert(utils.isPercentage(value),
        "Invalid percentage `" .. name .. "`. Must be a valid percentage.")
end

-- Validate slippage
function mod.isValidSlippage(name, value)
    assert(utils.isValidSlippage(value),
        "Invalid slippage `" .. name .. "`. Must be a valid slippage percentage.")
end

-- Validate DEX type
function mod.isValidDex(name, value)
    assert(utils.isValidDex(value),
        "Invalid dex `" .. name .. "`. Must be a valid dex type.")
end

-- Validate running time
function mod.isValidRunningTime(name1, name2, startDate, endDate)
    assert(utils.isValidRunningTime(startDate, endDate),
        "Invalid running time `" .. name1 .. "` and `" .. name2 .. "`. Must be a valid running time.")
end

-- Validate strategy type
function mod.isValidStrategy(name, value)
    assert(utils.isValidStrategy(value),
        "Invalid strategy `" .. name .. "`. Must be a valid strategy type.")
end

-- Validate agent version
function mod.isValidAgentVersion(name, value)
    assert(utils.isValidAgentVersion(value),
        "Invalid agent version `" .. name .. "`. Must be a valid version format.")
end

-- Validate boolean
function mod.isValidBoolean(name, value)
    assert(utils.isValidBoolean(value),
        "Invalid boolean `" .. name .. "`. Must be 'true' or 'false'.")
end

-- Validate status
function mod.isValidStatus(name, value)
    assert(utils.isValidStatus(value),
        "Invalid status `" .. name .. "`. Must be a valid agent status.")
end

-- Check wallet permission
function mod.checkWalletForPermission(msg, errorMessage)
    assert(ao.id == msg.From or Owner == msg.From,
        errorMessage or "Wallet does not have permission to perform this action.")
end

-- Check if agent is active
function mod.isAgentActive()
    assert(Status == enums.AgentStatus.ACTIVE,
        "Agent is not active and cannot perform operations.")
end

-- Check if operation is valid
function mod.isValidOperation(name, value)
    assert(value == enums.OperationType.SWAP or
           value == enums.OperationType.LIQUIDITY_PROVISION or
           value == enums.OperationType.WITHDRAWAL,
        "Invalid operation type `" .. name .. "`. Must be a valid operation.")
end

return mod
end
end

do
local _ENV = _ENV
package.preload[ "libs.botega" ] = function( ... ) local arg = _G.arg;
---@diagnostic disable: undefined-global
local utils = require('utils.utils')
local constants = require('libs.constants')

local mod = {}

-- Check if message is a swap confirmation
function mod.isSwapConfirmation(msg, poolId)
    return msg.From == constants.BOTEGA_AMM_FACTORY_ID and
           msg.Tags["Relayed-From"] == poolId and
           msg.Tags["Relay-To"] == ao.id and
           msg.Tags.Action == 'Order-Confirmation'
end

-- Check if message is a swap refund
function mod.isSwapRefund(msg, poolId)
    return msg.Tags.Action == 'Credit-Notice' and
           msg.Tags.Sender == poolId and
           msg.Tags["X-Refunded-Order"] ~= nil
end

-- Await swap completion
function mod._awaitSwap(poolId)
    local response = Receive(function(msg)
        return mod.isSwapConfirmation(msg, poolId) or mod.isSwapRefund(msg, poolId)
    end)

    if mod.isSwapConfirmation(response, poolId) then
        return true, response
    else
        return false, response
    end
end

-- Get expected output for a swap
function mod.getExpectedOutput(poolId, tokenIn, amountIn)
    local swapOutput = ao.send({
        Target = poolId,
        Action = "Get-Swap-Output",
        Tags = {
            Token = tokenIn,
            Quantity = tostring(amountIn),
            Swapper = ao.id
        }
    }).receive()

    local amountOut = (swapOutput and swapOutput.Output) or "0"
    local slippage = Slippage or 0.5
    local expectedMinOutput = utils.calculateMinOutput(amountOut, slippage)

    return {
        amountOut = tostring(amountOut),
        expectedMinOutput = tostring(expectedMinOutput)
    }
end

-- Get swap nonce
function mod.getSwapNonce()
    return os.time() .. "-" .. math.random(100000000, 999999999)
end

-- Execute swap
function mod.swap(result)
    ao.send({
        Target = result.tokenIn,
        Action = "Transfer",
        Recipient = result.poolId,
        Quantity = result.amountIn,
        ["X-Expected-Min-Output"] = result.expectedMinOutput,
        ["X-Swap-Nonce"] = mod.getSwapNonce(),
        ["X-Action"] = "Swap"
    })

    return mod._awaitSwap(result.poolId)
end

-- Get liquidity pool information
function mod.getPoolInfo(poolId)
    local poolInfo = ao.send({
        Target = poolId,
        Action = "Info"
    }).receive()

    return poolInfo
end

return mod
end
end

do
local _ENV = _ENV
package.preload[ "libs.constants" ] = function( ... ) local arg = _G.arg;
local constants = {
    -- AO Ecosystem Token IDs
    AO_PROCESS_ID = "0syT13r0s0tgPmIed95bJnuSqaD29HQNN8D3ElLSrsc",
    GAME_PROCESS_ID = "s6jcB3ctSbiDNwR-paJgy5iOAhahXahLul8exSLHbGE",

    -- DEX Pool IDs
    PERMASWAP_AO_GAME_POOL_ID = "hbRwutwINSXCNxXxVNoNRT2YQk-OIX3Objqu85zJrLo",
    BOTEGA_AO_GAME_POOL_ID = "rG-b4gQwhfjnbmYhrnvCMDPuXguqmAmYwHZf4y24WYs",

    -- DEX Factory IDs
    BOTEGA_AMM_FACTORY_ID = "3XBGLrygs11K63F_7mldWz4veNx6Llg6hI2yZs8LKHo",

    -- Fee Process ID
    FEE_PROCESS_ID = "oOx8YhMyPkeV78LqGw2_BZSKSb4LzwdKEPo0_xwCdLk",

    -- Strategy Configuration
    SWAP_PERCENTAGE = 50,  -- 50% for swapping
    LP_PERCENTAGE = 50,    -- 50% for liquidity provision

    -- Default Configuration
    DEFAULT_SLIPPAGE = 1.0,
    DEFAULT_LP_SLIPPAGE = 1.0,  -- Higher slippage tolerance for LP
    AGENT_VERSION = "0.1.3"
}

-- Pool ID mappings
constants.PERMASWAP_POOL_IDS = {
    [constants.GAME_PROCESS_ID] = constants.PERMASWAP_AO_GAME_POOL_ID
}

constants.BOTEGA_POOL_IDS = {
    [constants.GAME_PROCESS_ID] = constants.BOTEGA_AO_GAME_POOL_ID
}

return constants
end
end

do
local _ENV = _ENV
package.preload[ "libs.enums" ] = function( ... ) local arg = _G.arg;
local enums = {
    DexType = {
        PERMASWAP = "Permaswap",
        BOTEGA = "Botega",
        AUTO = "Auto"
    },

    AgentStatus = {
        ACTIVE = "Active",
        PAUSED = "Paused",
        COMPLETED = "Completed",
        CANCELLED = "Cancelled"
    },

    OperationType = {
        SWAP = "Swap",
        LIQUIDITY_PROVISION = "LiquidityProvision",
        WITHDRAWAL = "Withdrawal"
    },

    StrategyType = {
        SWAP_50_LP_50 = "Swap50LP50",
        CUSTOM = "Custom"
    },

    -- LP staged flow states
    LPFlowState = {
        AWAIT_TOKEN_OUT_CREDIT = "AwaitTokenOutCredit",
        TOKEN_OUT_SENT = "TokenOutSent",
        COMPLETED = "Completed"
    }
}

return enums
end
end

do
local _ENV = _ENV
package.preload[ "libs.permaswap" ] = function( ... ) local arg = _G.arg;
---@diagnostic disable: undefined-global
local utils = require('utils.utils')
local json = require('json')

local mod = {}

-- Check if message is a swap confirmation
function mod.isSwapConfirmation(msg, noteSettle)
    return msg.Tags.Action == 'Credit-Notice' and
           msg.Tags.Sender == noteSettle and
           msg.Tags["X-FFP-For"] == "Settled"
end

-- Check if message is a swap refund
function mod.isSwapRefund(msg, noteSettle)
    return msg.Tags.Action == 'Credit-Notice' and
           msg.Tags.Sender == noteSettle and
           msg.Tags["X-FFP-For"] == "Refund"
end

-- Await swap completion
function mod._awaitSwap(noteSettle)
    local response = Receive(function(msg)
        return mod.isSwapConfirmation(msg, noteSettle) or mod.isSwapRefund(msg, noteSettle)
    end)

    if mod.isSwapConfirmation(response, noteSettle) then
        return true, response
    else
        return false, response
    end
end

-- Get expected output for a swap
function mod.getExpectedOutput(poolId, tokenIn, amountIn)
    local swapOutput = ao.send({
        Target = poolId,
        Action = "GetAmountOut",
        AmountIn = amountIn,
        TokenIn = tokenIn
    }).receive()

    local amountOut = (swapOutput and swapOutput.AmountOut) or "0"
    local slippage = Slippage or 0.5
    local expectedMinOutput = utils.calculateMinOutput(amountOut, slippage)

    return {
        amountOut = tostring(amountOut),
        expectedMinOutput = tostring(expectedMinOutput)
    }
end

-- Request an order for swap
function mod.requestOrder(poolId, tokenIn, tokenOut, amountIn, amountOut)
    local requestOrder = ao.send({
        Target = poolId,
        Action = "RequestOrder",
        TokenIn = tokenIn,
        TokenOut = tokenOut,
        AmountIn = tostring(amountIn),
        AmountOut = tostring(amountOut)
    }).receive()

    return requestOrder
end

-- Execute swap
function mod.swap(result)
    ao.send({
        Target = result.tokenIn,
        Action = "Transfer",
        Recipient = result.noteSettle,
        Quantity = result.amountIn,
        ["X-FFP-For"] = "Settle",
        ["X-FFP-NoteIDs"] = json.encode({ result.noteId })
    })

    return mod._awaitSwap(result.noteSettle)
end

-- Alternative: Direct AddLiquidity call equivalent to permaswap-amm
function mod.addLiquidityDirect(poolId, amountA, amountB, minLiquidity)
    ao.send({
        Target = poolId,
        Action = "AddLiquidity",
        MinLiquidity = minLiquidity or "0",
        AmountA = amountA,
        AmountB = amountB
    }).receive()
end

return mod
end
end

do
local _ENV = _ENV
package.preload[ "libs.strategy" ] = function( ... ) local arg = _G.arg;
---@diagnostic disable: undefined-global
local constants = require('libs.constants')
local utils = require('utils.utils')
local enums = require('libs.enums')
local permaswap = require('libs.permaswap')
local botega = require('libs.botega')
local json = require('json')

local mod = {}

-- Choose DEX and pool for a given tokenOut and amount (used by staged LP flow)
function mod.getBaseTokenId()
    return BaseToken or constants.AO_PROCESS_ID
end

-- Validate that a pool contains the expected base and out tokens for the given dex
function mod.validatePoolPair(dex, poolId, baseToken, outToken)
    if not dex or not baseToken or not outToken then return false, "Missing params" end
    if dex == enums.DexType.PERMASWAP then
        local pid = poolId or constants.PERMASWAP_POOL_IDS[outToken]
        if not pid then return false, "No Permaswap pool mapping for out token" end
        local out1 = permaswap.getExpectedOutput(pid, baseToken, "1") or { amountOut = "0" }
        local out2 = permaswap.getExpectedOutput(pid, outToken, "1") or { amountOut = "0" }
        if utils.isZero(out1.amountOut) or utils.isZero(out2.amountOut) then
            return false, "Tokens not supported by Permaswap pool"
        end
        return true
    elseif dex == enums.DexType.BOTEGA then
        local pid = poolId or constants.BOTEGA_POOL_IDS[outToken]
        if not pid then return false, "No Botega pool mapping for out token" end
        local out1 = botega.getExpectedOutput(pid, baseToken, "1") or { amountOut = "0" }
        local out2 = botega.getExpectedOutput(pid, outToken, "1") or { amountOut = "0" }
        if utils.isZero(out1.amountOut) or utils.isZero(out2.amountOut) then
            return false, "Tokens not supported by Botega pool"
        end
        return true
    else
        -- AUTO: validate that at least one mapped pool supports both tokens
        if poolId then
            return false, "Cannot validate AUTO with explicit Pool-Id; specify Dex"
        end
        local permaPid = constants.PERMASWAP_POOL_IDS[outToken]
        local botePid = constants.BOTEGA_POOL_IDS[outToken]
        local permaOk = false
        local boteOk = false
        if permaPid then
            local a = permaswap.getExpectedOutput(permaPid, baseToken, "1") or { amountOut = "0" }
            local b = permaswap.getExpectedOutput(permaPid, outToken, "1") or { amountOut = "0" }
            permaOk = (not utils.isZero(a.amountOut)) and (not utils.isZero(b.amountOut))
        end
        if botePid then
            local a = botega.getExpectedOutput(botePid, baseToken, "1") or { amountOut = "0" }
            local b = botega.getExpectedOutput(botePid, outToken, "1") or { amountOut = "0" }
            boteOk = (not utils.isZero(a.amountOut)) and (not utils.isZero(b.amountOut))
        end
        if permaOk or boteOk then return true end
        return false, "No valid pools found for AUTO mode"
    end
end

function mod.chooseDexAndPool(tokenOutId, swapAmount)
    local dex = Dex or enums.DexType.AUTO
    local chosenDex = dex
    local poolId = nil

    if dex == enums.DexType.AUTO then
        local permaPool = constants.PERMASWAP_POOL_IDS[tokenOutId]
        local botePool = constants.BOTEGA_POOL_IDS[tokenOutId]
        local permaOut = { amountOut = "0" }
        local boteOut = { amountOut = "0" }
        local base = mod.getBaseTokenId()
        if permaPool then
            permaOut = permaswap.getExpectedOutput(permaPool, base, swapAmount)
        end
        if botePool then
            boteOut = botega.getExpectedOutput(botePool, base, swapAmount)
        end
        if utils.gt(permaOut.amountOut, boteOut.amountOut) then
            chosenDex = enums.DexType.PERMASWAP
        else
            chosenDex = enums.DexType.BOTEGA
        end
    end

    if dex == enums.DexType.PERMASWAP then
        poolId = PoolIdOverride or constants.PERMASWAP_POOL_IDS[tokenOutId]
    elseif dex == enums.DexType.BOTEGA then
        poolId = PoolIdOverride or constants.BOTEGA_POOL_IDS[tokenOutId]
    else
        if chosenDex == enums.DexType.PERMASWAP then
            poolId = constants.PERMASWAP_POOL_IDS[tokenOutId]
        elseif chosenDex == enums.DexType.BOTEGA then
            poolId = constants.BOTEGA_POOL_IDS[tokenOutId]
        end
    end
    -- Respect explicit PoolIdOverride even in AUTO mode after choosing a dex
    if PoolIdOverride then
        -- Try to infer dex from known mappings to avoid mismatches
        if PoolIdOverride == constants.PERMASWAP_POOL_IDS[tokenOutId] then
            chosenDex = enums.DexType.PERMASWAP
        elseif PoolIdOverride == constants.BOTEGA_POOL_IDS[tokenOutId] then
            chosenDex = enums.DexType.BOTEGA
        end
        poolId = PoolIdOverride
    end

    return chosenDex, poolId
end

-- Fire-and-forget swap trigger; rely on later Credit-Notice for TokenOut
function mod.triggerSwapFireAndForget(dex, poolId, tokenOutId, swapAmount)
    if utils.isZero(swapAmount) then return end
    local base = mod.getBaseTokenId()
    if dex == enums.DexType.PERMASWAP then
        if not poolId then return end
        local out = permaswap.getExpectedOutput(poolId, base, swapAmount)
        -- Update stats using expected minimum output
        TotalSwaps = (TotalSwaps or 0) + 1
        local minOut = tostring(out.expectedMinOutput)
        TotalBought[tokenOutId] = utils.add(TotalBought[tokenOutId] or "0", minOut)
        local order = permaswap.requestOrder(poolId, base, tokenOutId, tostring(swapAmount), out.expectedMinOutput)
        if order and order.NoteID and order.NoteSettle then
            ao.send({
                Target = base,
                Action = "Transfer",
                Recipient = order.NoteSettle,
                Quantity = tostring(swapAmount),
                ["X-FFP-For"] = "Settle",
                ["X-FFP-NoteIDs"] = json.encode({ order.NoteID })
            })
        end
        return
    end
    if dex == enums.DexType.BOTEGA then
        if not poolId then return end
        local out = botega.getExpectedOutput(poolId, base, swapAmount)
        -- Update stats using expected minimum output
        TotalSwaps = (TotalSwaps or 0) + 1
        local minOut = tostring(out.expectedMinOutput)
        TotalBought[tokenOutId] = utils.add(TotalBought[tokenOutId] or "0", minOut)
        ao.send({
            Target = base,
            Action = "Transfer",
            Recipient = poolId,
            Quantity = tostring(swapAmount),
            ["X-Expected-Min-Output"] = tostring(out.expectedMinOutput),
            ["X-Swap-Nonce"] = botega.getSwapNonce(),
            ["X-Action"] = "Swap"
        })
        return
    end
end

-- Send a token to pool appropriately for LP depending on dex
function mod.lpSendTokenToPool(dex, poolId, tokenId, quantity, amountA, amountB)
    print("LP Send Token To Pool " .. dex .. " " .. poolId .. " " .. tokenId .. " " .. quantity .. " " .. amountA .. " " .. amountB)
    if not poolId or not tokenId or utils.isZero(quantity) then return end
    if dex == enums.DexType.BOTEGA then
        print("LP Send Token To Pool Botega")
        local sendMsg = {
            Target = tokenId,
            Action = "Transfer",
            Recipient = poolId,
            Quantity = tostring(quantity),
            ["X-Action"] = "Provide",
        }
        -- Include slippage tolerance only when providing the base token
        if tokenId == mod.getBaseTokenId() then
            sendMsg["X-Slippage-Tolerance"] = tostring(Slippage or 0.5)
        end
        ao.send(sendMsg)
        return
    end
    if dex == enums.DexType.PERMASWAP then
        print("LP Send Token To Pool Permaswap")
        ao.send({
            Target = tokenId,
            Action = "Transfer",
            Recipient = poolId,
            Quantity = tostring(quantity),
            ["X-PS-For"] = "LP",
            ["X-Amount-A"] = tostring(amountA or "0"),
            ["X-Amount-B"] = tostring(amountB or "0"),
        })
        return
    end
end

-- Add liquidity call for permaswap after deposits
function mod.lpAddLiquidityPermaswap(poolId, amountA, amountB)
    if not poolId then return end
    ao.send({
        Target = poolId,
        Action = "AddLiquidity",
        MinLiquidity = "1",
        ["X-Amount-A"] = tostring(amountA or "0"),
        ["X-Amount-B"] = tostring(amountB or "0")
    })
end

-- Get strategy statistics
function mod.getStrategyStats()
    return {
        totalTransactions = TotalTransactions or 0,
        totalAOSold = TotalAOSold or "0",
        totalSwaps = TotalSwaps or 0,
        totalSwapValue = TotalSwapValue or "0",
        totalLPs = TotalLPs or 0,
        totalLPValue = TotalLPValue or "0",
        totalBought = TotalBought or {},
        strategyType = enums.StrategyType.SWAP_50_LP_50
    }
end

return mod
end
end

do
local _ENV = _ENV
package.preload[ "libs.token" ] = function( ... ) local arg = _G.arg;
---@diagnostic disable: undefined-global
local constants = require('libs.constants')
local utils = require('utils.utils')

local mod = {}

-- Get balance for a token
function mod.getBalance(tokenId)
    local result = ao.send({ Target = tokenId, Action = "Balance" }).receive()
    return result.Tags.Balance or "0"
end

-- Get Base token balance (defaults to AO if BaseToken not set)
function mod.getBaseBalance()
    local base = BaseToken or constants.AO_PROCESS_ID
    return mod.getBalance(base)
end

--  AO balance
function mod.getAOBalance()
    return mod.getBalance(constants.AO_PROCESS_ID)
end

-- Transfer tokens back to owner
function mod.transferToSelf(tokenId, quantity)
    ao.send({
        Target = tokenId,
        Action = "Transfer",
        Recipient = Owner,
        Quantity = quantity
    })
end

-- Transfer all remaining balances to owner
function mod.transferRemainingBalanceToSelf()
    -- Build a unique list of token IDs to return balances for
    local toCheck = {}
    local seen = {}

    local function addToken(id)
        if id and not seen[id] then
            table.insert(toCheck, id)
            seen[id] = true
        end
    end

    -- Always include AO
    addToken(constants.AO_PROCESS_ID)
    -- Include BaseToken if different from AO
    if BaseToken and BaseToken ~= constants.AO_PROCESS_ID then
        addToken(BaseToken)
    end
    -- Include configured TokenOut when set and not AO
    if TokenOut and TokenOut ~= constants.AO_PROCESS_ID then
        addToken(TokenOut)
    end

    -- Transfer any non-zero balances back to owner
    for _, tokenId in ipairs(toCheck) do
        local balance = mod.getBalance(tokenId)
        if not utils.isZero(balance) then
            mod.transferToSelf(tokenId, balance)
        end
    end
end

return mod
end
end

do
local _ENV = _ENV
package.preload[ "utils.utils" ] = function( ... ) local arg = _G.arg;
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
end
end

---@diagnostic disable: undefined-global
-- Yield LP Agent
-- A modular agent that implements a 50% swap + 50% liquidity provision strategy
-- Author: Ikem (x.com/ikempeter3) - YAO TEAM

-- Load modules
local constants = require('libs.constants')
local utils = require('utils.utils')
local enums = require('libs.enums')
local token = require('libs.token')
local strategy = require('libs.strategy')
local assertions = require('libs.assertions')
local json = require('json')

-- Agent State
Status = Status or enums.AgentStatus.ACTIVE
Dex = Dex or ao.env.Process.Tags["Dex"] or enums.DexType.BOTEGA
TokenOut = TokenOut or ao.env.Process.Tags["Token-Out"] or constants.GAME_PROCESS_ID
Slippage = Slippage or tonumber(ao.env.Process.Tags["Slippage"]) or constants.DEFAULT_SLIPPAGE
StartDate = StartDate or tonumber(ao.env.Process.Tags["Start-Date"]) or os.time()
EndDate = EndDate or tonumber(ao.env.Process.Tags["End-Date"]) or math.huge
RunIndefinitely = RunIndefinitely or ao.env.Process.Tags["Run-Indefinitely"] == "true"
ConversionPercentage = ConversionPercentage or tonumber(ao.env.Process.Tags["Conversion-Percentage"]) or 50
StrategyType = StrategyType or ao.env.Process.Tags["Strategy-Type"] or enums.StrategyType.SWAP_50_LP_50
BaseToken = BaseToken or ao.env.Process.Tags["Base-Token"] or constants.AO_PROCESS_ID
PoolIdOverride = PoolIdOverride or ao.env.Process.Tags["Pool-Id"]

-- Statistics
TotalTransactions = TotalTransactions or 0
TotalAOSold = TotalAOSold or "0"
TotalSwaps = TotalSwaps or 0
TotalSwapValue = TotalSwapValue or "0"
TotalLPs = TotalLPs or 0
TotalLPValue = TotalLPValue or "0"
TotalLPTransactions = TotalLPTransactions or 0
TotalLPTokens = TotalLPTokens or "0"
TotalBought = TotalBought or {}
ProcessedUpToDate = ProcessedUpToDate or nil
SwapInProgress = SwapInProgress or false
SwappedUpToDate = SwappedUpToDate or nil
FeeProcessId = FeeProcessId or constants.FEE_PROCESS_ID
AgentVersion = AgentVersion or ao.env.Process.Tags["Agent-Version"] or constants.AGENT_VERSION

-- Staged LP flow state (Credit/Debit driven)
LPFlowActive = LPFlowActive or false
LPFlowState = LPFlowState or nil -- enums.LPFlowState
LPFlowDex = LPFlowDex or nil     -- enums.DexType
LPFlowTokenOutId = LPFlowTokenOutId or nil
LPFlowPoolId = LPFlowPoolId or nil
LPFlowAoAmount = LPFlowAoAmount or nil             -- string
LPFlowTokenOutAmount = LPFlowTokenOutAmount or nil -- string
LPFlowPending = LPFlowPending or false             -- when true, start a new flow after current completes

-- Staged LP helpers moved to libs/strategy.lua to avoid duplication

-- Local helper: initiate staged swap+LP flow given current AO balance
local function initiateStagedFlow(msg, tokenOutId)
    local totalAmount = token.getBaseBalance()
    if utils.isZero(totalAmount) then
        SwapInProgress = false
        return false
    end

    local swapAmount, aoForLP = utils.splitQuantity(totalAmount, ConversionPercentage or constants.SWAP_PERCENTAGE)
    local chosenDex, poolId = strategy.chooseDexAndPool(tokenOutId, swapAmount)

    -- Fire-and-forget swap; rely on TokenOut credit notice later
    print("triggerSwapFireAndForget: " .. chosenDex .. " " .. poolId .. " " .. tokenOutId .. " " .. swapAmount)
    strategy.triggerSwapFireAndForget(chosenDex, poolId, tokenOutId, swapAmount)

    -- Stage LP flow
    LPFlowActive = true
    LPFlowState = enums.LPFlowState.AWAIT_TOKEN_OUT_CREDIT
    LPFlowDex = chosenDex
    LPFlowTokenOutId = tokenOutId
    LPFlowPoolId = poolId
    LPFlowAoAmount = tostring(aoForLP)
    LPFlowTokenOutAmount = nil

    ProcessedUpToDate = tonumber(msg and msg.Tags and msg.Tags["X-Swap-Date-To"]) or os.time()
    return true
end

-- Info handler
Handlers.add("Info", "Info",
    function(msg)
        local strategyStats = strategy.getStrategyStats()

        msg.reply({
            Action = "Info-Response",
            ["Start-Date"] = tostring(StartDate),
            ["End-Date"] = tostring(EndDate),
            Dex = Dex,
            ["Token-Out"] = TokenOut,
            ["Base-Token"] = BaseToken or constants.AO_PROCESS_ID,
            ["Pool-Id"] = PoolIdOverride or "",
            Slippage = tostring(Slippage),
            Status = Status,
            ["Run-Indefinitely"] = tostring(RunIndefinitely),
            ["Conversion-Percentage"] = tostring(ConversionPercentage),
            ["Strategy-Type"] = StrategyType,
            ["Agent-Version"] = AgentVersion,
            ["Total-Transactions"] = tostring(strategyStats.totalTransactions),
            ["Total-AO-Sold"] = tostring(strategyStats.totalAOSold),
            ["Total-Swaps"] = tostring(strategyStats.totalSwaps),
            ["Total-Swap-Value"] = tostring(strategyStats.totalSwapValue),
            ["Total-LPs"] = tostring(strategyStats.totalLPs),
            ["Total-LP-Value"] = tostring(strategyStats.totalLPValue),
            ["Total-LP-Transactions"] = tostring(TotalLPTransactions),
            ["Total-LP-Tokens"] = tostring(TotalLPTokens),
            ["Total-Bought"] = json.encode(strategyStats.totalBought),
            ["Swap-In-Progress"] = tostring(SwapInProgress),
            ["Processed-Up-To-Date"] = tostring(ProcessedUpToDate),
            ["Swapped-Up-To-Date"] = tostring(SwappedUpToDate),
            ["LP-Flow-Active"] = tostring(LPFlowActive),
            ["LP-Flow-State"] = tostring(LPFlowState),
        })
    end
)

-- Update agent configuration
Handlers.add("Update-Agent", "Update-Agent",
    function(msg)
        assertions.checkWalletForPermission(msg)
        assertions.isAgentActive()

        -- Stage potential updates for Dex/TokenOut/BaseToken/PoolId for validation
        local desiredDex = Dex
        if utils.isValidDex(msg.Tags.Dex) then desiredDex = msg.Tags.Dex end

        -- Update slippage
        if utils.isValidSlippage(tonumber(msg.Tags.Slippage)) then
            Slippage = tonumber(msg.Tags.Slippage)
        end

        -- Update running time
        if utils.isValidRunningTime(tonumber(msg.Tags["Start-Date"]), tonumber(msg.Tags["End-Date"])) then
            StartDate = tonumber(msg.Tags["Start-Date"])
            EndDate = tonumber(msg.Tags["End-Date"])
        end

        -- Stage Token-Out
        local desiredTokenOut = TokenOut
        if utils.isAddress(msg.Tags["Token-Out"]) then desiredTokenOut = msg.Tags["Token-Out"] end

        -- Update run indefinitely
        if utils.isValidBoolean(msg.Tags["Run-Indefinitely"]) then
            RunIndefinitely = msg.Tags["Run-Indefinitely"] == "true"
        end

        -- Update conversion percentage
        if utils.isPercentage(tonumber(msg.Tags["Conversion-Percentage"])) then
            ConversionPercentage = tonumber(msg.Tags["Conversion-Percentage"])
        end

        -- Update strategy type
        if utils.isValidStrategy(msg.Tags["Strategy-Type"]) then
            StrategyType = msg.Tags["Strategy-Type"]
        end

        -- Stage Base-Token and Pool-Id overrides
        local desiredBase = BaseToken or constants.AO_PROCESS_ID
        if utils.isAddress(msg.Tags["Base-Token"]) then desiredBase = msg.Tags["Base-Token"] end

        local desiredPool = PoolIdOverride
        if utils.isAddress(msg.Tags["Pool-Id"]) then desiredPool = msg.Tags["Pool-Id"] end

        -- If any of Dex/TokenOut/Base-Token/Pool-Id provided, validate pair/pool
        local needsValidation = (msg.Tags.Dex ~= nil) or (msg.Tags["Token-Out"] ~= nil) or
        (msg.Tags["Base-Token"] ~= nil) or (msg.Tags["Pool-Id"] ~= nil)
        if needsValidation then
            local ok, err = strategy.validatePoolPair(desiredDex, desiredPool, desiredBase or constants.AO_PROCESS_ID,
                desiredTokenOut)
            if not ok then
                msg.reply({ Action = "Update-Failed", Error = tostring(err or "Validation failed") })
                return
            end
            -- Commit validated updates
            Dex = desiredDex
            TokenOut = desiredTokenOut
            BaseToken = desiredBase
            PoolIdOverride = desiredPool
        end

        -- Update status
        if utils.isValidStatus(msg.Tags.Status) then
            Status = msg.Tags.Status
            if Status == enums.AgentStatus.COMPLETED or Status == enums.AgentStatus.CANCELLED then
                ao.send({ Target = ao.id, Action = "Finalize-Agent" })
            end
        end

        -- Update agent version
        if utils.isValidAgentVersion(msg.Tags["Agent-Version"]) then
            AgentVersion = msg.Tags["Agent-Version"]
        end

        msg.reply({
            Action = "Update-Success",
            Data = "Agent configuration updated successfully"
        })
    end
)

-- Execute strategy
Handlers.add("Execute-Strategy", "Execute-Strategy",
    function(msg)
        assertions.checkWalletForPermission(msg, "Wallet does not have permission to execute strategy")
        assertions.isAgentActive()

        if SwapInProgress or LPFlowActive then
            -- Queue next run
            LPFlowPending = true
            msg.reply({ Action = "Strategy-Queued", Data = "Staged flow in progress; next run queued" })
            return
        end

        local now = os.time()
        if not utils.isWithinActiveWindow(now) then
            -- Return any held tokens to owner and inform caller
            token.transferRemainingBalanceToSelf()
            msg.reply({
                Action = "Strategy-Skipped-Time-Window",
                Data = "Strategy not executed: outside active time window",
                ["Start-Date"] = tostring(StartDate),
                ["End-Date"] = tostring(EndDate),
                ["Run-Indefinitely"] = tostring(RunIndefinitely),
                ["Current-Time"] = tostring(now)
            })
            return
        end

        -- Trigger staged flow
        SwapInProgress = true
        local tokenOutId = msg.Tags["Token-Out"] or TokenOut
        initiateStagedFlow(msg, tokenOutId)
    end
)

-- Credit notice handler - triggers strategy execution and handles LP tokens
Handlers.add("Credit-Notice", "Credit-Notice",
    function(msg)
        local tokenId = msg.From or msg.Tags["From-Process"]
        local quantity = msg.Tags.Quantity
        -- Base token credit: trigger swap only and stage LP
        local base = strategy.getBaseTokenId()
        if tokenId == base and not utils.isZero(quantity) then
            -- Detect refunds from DEX/pools to avoid auto-restarting the flow
            local sender = msg.Tags.Sender
            local knownPerma = constants.PERMASWAP_POOL_IDS[TokenOut]
            local knownBote = constants.BOTEGA_POOL_IDS[TokenOut]
            local isRefund = (msg.Tags["X-FFP-For"] == "Refund")
                or (msg.Tags["X-Refunded-Order"] ~= nil)
                or (sender and (sender == (LPFlowPoolId or "") or sender == (knownPerma or "") or sender == (knownBote or "")))

            if isRefund then
                -- Stop current flow to prevent retry loops
                SwapInProgress = false
                LPFlowActive = false
                LPFlowState = nil
                LPFlowPending = false
                ao.send({
                    Target = Owner,
                    Action = "Refund-Detected",
                    Data = "Refund received; halting auto-restart",
                    Tags = {
                        Sender = tostring(sender),
                        Quantity = tostring(quantity),
                        ["X-FFP-For"] = tostring(msg.Tags["X-FFP-For"]),
                        ["X-Refunded-Order"] = tostring(msg.Tags["X-Refunded-Order"])
                    }
                })
                return
            end
            -- If outside active window, immediately return credited amount and notify
            local now = os.time()
            if not utils.isWithinActiveWindow(now) then
                token.transferToSelf(base, quantity)
                ao.send({
                    Target = Owner,
                    Action = "Strategy-Skipped-Time-Window",
                    Data = "Base token credit received but outside active time window; returned funds to owner",
                    Tags = {
                        ["Start-Date"] = tostring(StartDate),
                        ["End-Date"] = tostring(EndDate),
                        ["Run-Indefinitely"] = tostring(RunIndefinitely),
                        ["Current-Time"] = tostring(now),
                        ["Returned-Token"] = tokenId,
                        ["Returned-Quantity"] = tostring(quantity)
                    }
                })
                return
            end

            if SwapInProgress or LPFlowActive then
                -- Record pending so we auto-run after finishing current flow
                if not LPFlowPending then LPFlowPending = true end
                print("Staged flow in progress; marked pending for next run")
                return
            end

            SwapInProgress = true
            initiateStagedFlow(msg, TokenOut)
            return
        end

        -- TokenOut credit: when swap delivers TokenOut, push it to pool (persist amount; fallback to current balance if Quantity missing)
        if LPFlowActive and LPFlowState == enums.LPFlowState.AWAIT_TOKEN_OUT_CREDIT and tokenId == LPFlowTokenOutId then
            local resolvedQty = quantity
            if (not resolvedQty or utils.isZero(resolvedQty)) and LPFlowTokenOutId then
                local bal = token.getBalance(LPFlowTokenOutId)
                if not utils.isZero(bal) then
                    resolvedQty = bal
                end
            end

            if not resolvedQty or utils.isZero(resolvedQty) then
                -- Nothing to do yet; keep waiting
                return
            end

            ao.send({ Target = Owner, Action = "Swap-Completed", Data = "Swap completed: tokenOut=" .. tostring(LPFlowTokenOutId) .. ", qty=" .. tostring(resolvedQty) })
            LPFlowTokenOutAmount = resolvedQty
            print("lpSendTokenToPool: " .. tostring(LPFlowTokenOutId) .. " " .. tostring(resolvedQty) .. " " .. tostring(LPFlowAoAmount) .. " " .. tostring(resolvedQty))
            strategy.lpSendTokenToPool(LPFlowDex, LPFlowPoolId, LPFlowTokenOutId, resolvedQty, LPFlowAoAmount, resolvedQty)
            LPFlowState = enums.LPFlowState.TOKEN_OUT_SENT
            return
        end

        -- Any other credits: sweep to owner for accounting (ignore TokenOut which we may await)
        if tokenId ~= TokenOut then
            print("transferToSelf (non-flow credit): " .. tostring(tokenId) .. " " .. tostring(quantity))
            token.transferToSelf(tokenId, quantity)
            return
        end
    end
)

Handlers.add("Debit-Notice", "Debit-Notice",
    function(msg)
        local tokenId = msg.From or msg.Tags["From-Process"]
        local quantity = msg.Tags.Quantity

        -- When our TokenOut transfer is debited, resolve amounts and send Base; for permaswap then AddLiquidity
        if LPFlowActive and LPFlowState == enums.LPFlowState.TOKEN_OUT_SENT and tokenId == LPFlowTokenOutId then
            -- Ensure TokenOut amount is available (fallback to current balance)
            local tokenOutAmt = LPFlowTokenOutAmount
            if (not tokenOutAmt or utils.isZero(tokenOutAmt)) and LPFlowTokenOutId then
                local bal = token.getBalance(LPFlowTokenOutId)
                if not utils.isZero(bal) then
                    tokenOutAmt = bal
                    LPFlowTokenOutAmount = tokenOutAmt
                end
            end

            local base = strategy.getBaseTokenId()
            local amountA = LPFlowAoAmount
            local amountB = tokenOutAmt

            if LPFlowDex == enums.DexType.BOTEGA then
                strategy.lpSendTokenToPool(LPFlowDex, LPFlowPoolId, base, amountA, amountA, amountB)
            elseif LPFlowDex == enums.DexType.PERMASWAP then
                strategy.lpSendTokenToPool(LPFlowDex, LPFlowPoolId, base, amountA, amountA, amountB)
                strategy.lpAddLiquidityPermaswap(LPFlowPoolId, amountA, amountB)
            end

            LPFlowState = enums.LPFlowState.COMPLETED
            LPFlowActive = false
            SwapInProgress = false

            -- If a run is pending, and we're within window, immediately start a new staged flow
            if LPFlowPending then
                local now = os.time()
                if utils.isWithinActiveWindow(now) then
                    LPFlowPending = false
                    -- Only restart if base balance available
                    if not utils.isZero(token.getBaseBalance()) then
                        SwapInProgress = true
                        initiateStagedFlow(nil, TokenOut)
                    end
                end
            end
        end
    end
)

-- Force-continue staged LP flow
Handlers.add("Force-Continue", "Force-Continue",
    function(msg)
        assertions.checkWalletForPermission(msg, "Wallet does not have permission to force-continue")

        -- If there is no active flow, try to start a new one if pending or balances available
        if not LPFlowActive then
            SwapInProgress = false
            msg.reply({ Action = "Force-Continue-Started-New", Data = "No active flow and no available balance/window" })
            return
        end

        -- There is an active flow: advance by current state
        if LPFlowState == enums.LPFlowState.AWAIT_TOKEN_OUT_CREDIT then
            -- If TokenOut was already credited (but notice missed), push it to the pool now
            if not LPFlowTokenOutId then
                msg.reply({ Action = "Force-Continue-Error", Error = "TokenOutId missing for active flow" })
                return
            end
            local outBal = token.getBalance(LPFlowTokenOutId)
            if utils.isZero(outBal) and (not LPFlowTokenOutAmount or utils.isZero(LPFlowTokenOutAmount)) then
                msg.reply({ Action = "Force-Continue-Wait", Data = "TokenOut not credited yet" })
                return
            end

            local qty = (LPFlowTokenOutAmount and not utils.isZero(LPFlowTokenOutAmount)) and LPFlowTokenOutAmount or outBal
            LPFlowTokenOutAmount = qty
            strategy.lpSendTokenToPool(LPFlowDex, LPFlowPoolId, LPFlowTokenOutId, qty, LPFlowAoAmount, qty)
            LPFlowState = enums.LPFlowState.TOKEN_OUT_SENT
            msg.reply({ Action = "Force-Continue-Advanced", State = tostring(LPFlowState) })
            return
        end
        if LPFlowState == enums.LPFlowState.TOKEN_OUT_SENT then
            -- Send Base token now and finalize per dex rules
            local base = strategy.getBaseTokenId()
            strategy.lpSendTokenToPool(LPFlowDex, LPFlowPoolId, base, LPFlowAoAmount, LPFlowAoAmount, LPFlowTokenOutAmount)

            if LPFlowDex == enums.DexType.PERMASWAP then
                strategy.lpAddLiquidityPermaswap(LPFlowPoolId, LPFlowAoAmount, LPFlowTokenOutAmount)
            end

            LPFlowState = enums.LPFlowState.COMPLETED
            LPFlowActive = false
            SwapInProgress = false

            -- Auto-start pending if requested and within window
            if LPFlowPending and utils.isWithinActiveWindow(os.time()) then
                LPFlowPending = false
                if not utils.isZero(token.getBaseBalance()) then
                    SwapInProgress = true
                    initiateStagedFlow(nil, TokenOut)
                end
            end

            msg.reply({ Action = "Force-Continue-Advanced", State = tostring(LPFlowState) })
            return
        end
        if LPFlowState == enums.LPFlowState.COMPLETED then
            -- Completed but still marked active? Clean up and optionally start pending
            LPFlowActive = false
            SwapInProgress = false
            if LPFlowPending and utils.isWithinActiveWindow(os.time()) then
                LPFlowPending = false
                SwapInProgress = true
                msg.reply({ Action = "Force-Continue-Restarted", State = tostring(LPFlowState) })
            else
                msg.reply({ Action = "Force-Continue-No-Op", Data = "Flow already completed" })
            end
            return
        end
        msg.reply({ Action = "Force-Continue-Error", Error = "Unknown LP flow state" })
    end
)

-- Withdraw tokens
Handlers.add("Withdraw", "Withdraw",
    function(msg)
        assertions.checkWalletForPermission(msg, "Wallet does not have permission to withdraw")

        local tokenId = msg.Tags["Token-Id"]
        local quantity = msg.Tags["Quantity"]
        local all = msg.Tags["Transfer-All"]

        assertions.isAddress("Token-Id", tokenId)

        if all then
            local balance = token.getBalance(tokenId)
            token.transferToSelf(tokenId, balance)
        else
            assertions.isTokenQuantity("Quantity", quantity)
            token.transferToSelf(tokenId, quantity)
        end

        msg.reply({
            Action = "Withdraw-Success",
            Data = "Withdrawal completed successfully"
        })
    end
)

-- Finalize agent
Handlers.add("Finalize-Agent", "Finalize-Agent",
    function(msg)
        assertions.checkWalletForPermission(msg, "Wallet does not have permission to finalize the agent")

        -- Transfer remaining balances
        token.transferRemainingBalanceToSelf()

        -- End agent execution
        EndDate = os.time()
        RunIndefinitely = false
        Status = enums.AgentStatus.COMPLETED

        msg.reply({
            Action = "Finalize-Success",
            Data = "Agent finalized successfully"
        })
    end
)

-- Get strategy statistics
Handlers.add("Get-Stats", "Get-Stats",
    function(msg)
        local strategyStats = strategy.getStrategyStats()

        msg.reply({
            Action = "Stats-Response",
            Tags = {
                ["Total-Transactions"] = tostring(strategyStats.totalTransactions),
                ["Total-AO-Sold"] = tostring(strategyStats.totalAOSold),
                ["Total-Swaps"] = tostring(strategyStats.totalSwaps),
                ["Total-Swap-Value"] = tostring(strategyStats.totalSwapValue),
                ["Total-LPs"] = tostring(strategyStats.totalLPs),
                ["Total-LP-Value"] = tostring(strategyStats.totalLPValue),
                ["Total-LP-Transactions"] = tostring(TotalLPTransactions),
                ["Total-LP-Tokens"] = tostring(TotalLPTokens),
                ["Total-Bought"] = json.encode(strategyStats.totalBought)
            }
        })
    end
)

-- LiquidityAdded-Notice handler - handles permaswap LP completion
Handlers.add("LiquidityAdded-Notice", "LiquidityAdded-Notice",
    function(msg)
        local amountLp = msg.Tags.AmountLp or msg.Tags.BalanceLp
        local user = msg.Tags.User
        local poolId = msg.Tags.PoolId

        print("Permaswap LP completed successfully:")
        print("  User: " .. tostring(user))
        print("  Pool: " .. tostring(poolId))
        print("  LP Tokens Minted: " .. tostring(amountLp))

        -- Update LP statistics
        TotalLPTransactions = TotalLPTransactions + 1
        if amountLp then
            TotalLPTokens = utils.add(TotalLPTokens or "0", amountLp)
        end

        msg.reply({
            Action = "LP-Addition-Confirmed",
            User = user,
            PoolId = poolId,
            ["LP-Tokens"] = amountLp
        })
    end
)

-- Provide-Confirmation handler - handles LP completion notifications (Botega)
Handlers.add("Provide-Confirmation", "Provide-Confirmation",
    function(msg)
        local poolTokens = msg.Tags["Received-Pool-Tokens"]
        local provideId = msg.Tags["Provide-Id"]

        print("Botega LP completed successfully:")
        print("  Pool Tokens Received: " .. tostring(poolTokens))
        print("  Provide ID: " .. tostring(provideId))

        -- Update LP statistics
        TotalLPTransactions = TotalLPTransactions + 1
        if poolTokens then
            TotalLPTokens = utils.add(TotalLPTokens or "0", poolTokens)
        end

        msg.reply({
            Action = "LP-Notification-Received",
            ["Provide-Id"] = provideId,
            ["Pool-Tokens"] = poolTokens
        })
    end
)

-- Provider error handler - handles LP provider errors (Botega/Permaswap)
Handlers.add("Provide-Error", "Provide-Error",
    function(msg)
        -- Stop current staged LP flow to prevent loops after provider failures
        LPFlowActive = false
        SwapInProgress = false
        LPFlowPending = false
        LPFlowState = nil

        msg.reply({
            Action = "Provide-Error-Ack",
            Error = tostring(msg.Tags and (msg.Tags.Error or msg.Data) or "Unknown provider error"),
            PoolId = tostring((msg.Tags and msg.Tags.PoolId) or LPFlowPoolId or "")
        })
    end
)

-- Health check
Handlers.add("Health", "Health",
    function(msg)
        msg.reply({
            Action = "Health-Response",
            -- Status = "Healthy",
            ["Agent-Version"] = AgentVersion,
            ["Current-Time"] = tostring(os.time()),
            ["Status"] = Status
        })
    end
)

print("Yield LP Agent initialized with " .. StrategyType .. " strategy")
print("Agent Version: " .. AgentVersion)
print("Status: " .. Status)
print("Token Out: " .. TokenOut)
print("Base Token: " .. (BaseToken or constants.AO_PROCESS_ID))
print("DEX: " .. Dex)
print("Pool Id Override: " .. tostring(PoolIdOverride))
print("owner: " .. Owner)
print("Process ID: " .. ao.id)
