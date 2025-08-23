do
local _ENV = _ENV
package.preload[ "libs.assertions" ] = function( ... ) local arg = _G.arg;
local utils = require('src.utils.utils')
local enums = require('src.libs.enums')

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
package.preload[ "libs.bint" ] = function( ... ) local arg = _G.arg;
-- Fallback bint implementation for AO processes
-- This is a simplified version for basic arithmetic operations

local bint = {}

-- Create a new bint instance
function bint.new(value)
    local self = {
        value = tostring(value or 0)
    }

    -- Basic arithmetic operations
    function self:add(other)
        return bint.new(tostring(tonumber(self.value) + tonumber(other.value or other)))
    end

    function self:sub(other)
        return bint.new(tostring(tonumber(self.value) - tonumber(other.value or other)))
    end

    function self:mul(other)
        return bint.new(tostring(tonumber(self.value) * tonumber(other.value or other)))
    end

    function self:div(other)
        return bint.new(tostring(math.floor(tonumber(self.value) / tonumber(other.value or other))))
    end

    function self:udiv(other)
        return self:div(other)  -- Same as div for positive numbers
    end

    -- Comparison operations
    function self:lt(other)
        return tonumber(self.value) < tonumber(other.value or other)
    end

    function self:lte(other)
        return tonumber(self.value) <= tonumber(other.value or other)
    end

    function self:gt(other)
        return tonumber(self.value) > tonumber(other.value or other)
    end

    function self:gte(other)
        return tonumber(self.value) >= tonumber(other.value or other)
    end

    function self:eq(other)
        return tonumber(self.value) == tonumber(other.value or other)
    end

    function self:zero()
        return bint.new(0)
    end

    function self:isbint(val)
        return type(val) == "table" and val.value ~= nil
    end

    -- Convert to string
    function self:__tostring()
        return self.value
    end

    return self
end

-- Module functions
function bint.__add(a, b)
    return a:add(b)
end

function bint.__sub(a, b)
    return a:sub(b)
end

function bint.__mul(a, b)
    return a:mul(b)
end

function bint.udiv(a, b)
    return a:udiv(b)
end

function bint.__lt(a, b)
    return a:lt(b)
end

function bint.__le(a, b)
    return a:lte(b)
end

function bint.__gt(a, b)
    return a:gt(b)
end

function bint.__ge(a, b)
    return a:gte(b)
end

function bint.__eq(a, b)
    return a:eq(b)
end

function bint.zero()
    return bint.new(0)
end

function bint.isbint(val)
    return type(val) == "table" and val.value ~= nil
end

-- Create bint instance with specified bits
setmetatable(bint, {
    __call = function(_, bits)
        return bint.new
    end
})

return bint
end
end

do
local _ENV = _ENV
package.preload[ "libs.botega" ] = function( ... ) local arg = _G.arg;
local utils = require('src.utils.utils')
local constants = require('src.libs.constants')

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
    local adjustedSlippage = math.floor(slippage * 100)
    local expectedMinOutput = utils.div(
        utils.mul(amountOut, utils.subtract(10000, adjustedSlippage)),
        10000
    )

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

-- Provide liquidity with both tokens
-- Sends both tokens simultaneously with X-Action = "Provide"
-- Botega's AMM factory will handle the LP since both carry the Provide action
function mod.provideLiquidity(poolId, tokenA, amountA, tokenB, amountB)
    -- Send first token with Provide action
    ao.send({
        Target = tokenA,
        Action = "Transfer",
        Recipient = poolId,
        Quantity = tostring(amountA),
        ["X-Action"] = "Provide"
    }).receive()

    -- Send second token with Provide action
    ao.send({
        Target = tokenB,
        Action = "Transfer",
        Recipient = poolId,
        Quantity = tostring(amountB),
        ["X-Action"] = "Provide"
    })
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
    WAR_PROCESS_ID = "xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10",
    WUSDC_PROCESS_ID = "7zH9dlMNoxprab9loshv3Y7WG45DOny_Vrq9KrXObdQ",
    GAME_PROCESS_ID = "s6jcB3ctSbiDNwR-paJgy5iOAhahXahLul8exSLHbGE",

    -- DEX Pool IDs
    PERMASWAP_AO_WAR_POOL_ID = "FRF1k0BSv0gRzNA2n-95_Fpz9gADq9BGi5PyXKFp6r8",
    PERMASWAP_AO_WUSDC_POOL_ID = "gjnaCsEd749ZXeG2H8akvf8wzbl7CQ4Ox-KYEBAdONk",
    PERMASWAP_AO_GAME_POOL_ID = "hbRwutwINSXCNxXxVNoNRT2YQk-OIX3Objqu85zJrLo",
    BOTEGA_AO_WAR_POOL_ID = "B6qAwHi2OjZmyFCEU8hV6FZDSHbAOz8r0yy-fBbuTus",
    BOTEGA_AO_WUSDC_POOL_ID = "TYqlQ2vqkF0H6nC0mCgGe6G12pqq9DsSXpvtHYc6_xY",
    BOTEGA_AO_GAME_POOL_ID = "rG-b4gQwhfjnbmYhrnvCMDPuXguqmAmYwHZf4y24WYs",

    -- DEX Factory IDs
    BOTEGA_AMM_FACTORY_ID = "3XBGLrygs11K63F_7mldWz4veNx6Llg6hI2yZs8LKHo",

    -- Fee Process ID
    FEE_PROCESS_ID = "rkAezEIgacJZ_dVuZHOKJR8WKpSDqLGfgPJrs_Es7CA",

    -- Strategy Configuration
    SWAP_PERCENTAGE = 50,  -- 50% for swapping
    LP_PERCENTAGE = 50,    -- 50% for liquidity provision

    -- Default Configuration
    DEFAULT_SLIPPAGE = 0.5,
    DEFAULT_LP_SLIPPAGE = 1.0,  -- Higher slippage tolerance for LP
    AGENT_VERSION = "1.0.0"
}

-- Pool ID mappings
constants.PERMASWAP_POOL_IDS = {
    [constants.WAR_PROCESS_ID] = constants.PERMASWAP_AO_WAR_POOL_ID,
    [constants.WUSDC_PROCESS_ID] = constants.PERMASWAP_AO_WUSDC_POOL_ID,
    [constants.GAME_PROCESS_ID] = constants.PERMASWAP_AO_GAME_POOL_ID
}

constants.BOTEGA_POOL_IDS = {
    [constants.WAR_PROCESS_ID] = constants.BOTEGA_AO_WAR_POOL_ID,
    [constants.WUSDC_PROCESS_ID] = constants.BOTEGA_AO_WUSDC_POOL_ID,
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
    }
}

return enums
end
end

do
local _ENV = _ENV
package.preload[ "libs.permaswap" ] = function( ... ) local arg = _G.arg;
local utils = require('src.utils.utils')
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
    local adjustedSlippage = math.floor(slippage * 100)
    local expectedMinOutput = utils.div(
        utils.mul(amountOut, utils.subtract(10000, adjustedSlippage)),
        10000
    )

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

-- Provide liquidity to permaswap pool (following permaswap-amm pattern)
-- This simulates the deposit + AddLiquidity flow from permaswap-amm
function mod.provideLiquidity(poolId, tokenA, amountA, tokenB, amountB)
    local constants = require('src.libs.constants')

    -- Step 1: Deposit tokens to permaswap pool (like permaswap-amm deposit handler)
    -- This sends tokens with proper permaswap tags to trigger deposit into BalancesX/BalancesY
    ao.send({
        Target = tokenA,
        Action = "Transfer",
        Recipient = poolId,
        Quantity = amountA,
        ["X-PS-For"] = "LP",  -- Indicate this is for LP, not swap
        ["X-Amount-A"] = amountA,
        ["X-Amount-B"] = amountB
    }).receive()

    ao.send({
        Target = tokenB,
        Action = "Transfer",
        Recipient = poolId,
        Quantity = amountB,
        ["X-PS-For"] = "LP",  -- Indicate this is for LP, not swap
        ["X-Amount-A"] = amountA,
        ["X-Amount-B"] = amountB
    }).receive()

    -- Step 2: Call AddLiquidity action (like permaswap-amm AddLiquidity handler)
    -- This is equivalent to calling AddLiquidity with MinLiquidity
    local minLiquidity = "0"  -- Minimum LP tokens to mint (can be 0 for simplicity)
    ao.send({
        Target = poolId,
        Action = "AddLiquidity",
        MinLiquidity = minLiquidity,
        ["X-Amount-A"] = amountA,
        ["X-Amount-B"] = amountB
    }).receive()
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
local constants = require('src.libs.constants')
local utils = require('src.utils.utils')
local enums = require('src.libs.enums')
local token = require('src.libs.token')
local permaswap = require('src.libs.permaswap')
local botega = require('src.libs.botega')

local mod = {}

-- Execute 50% swap + 50% LP strategy
function mod.executeSwapAndLP(msg, pushedFor)
    local tokenIn = constants.AO_PROCESS_ID
    local tokenOut = msg.Tags["Token-Out"] or TokenOut
    local totalAmount = token.getAOBalance()

    -- Validate amount
    if utils.isZero(totalAmount) then
        mod.replyWithStrategyError(msg, "No AO tokens available for strategy execution")
        return
    end

    -- Split amount: 50% for swap (to get paired token), 50% to keep for LP
    local swapAmount, aoForLP = utils.splitQuantity(totalAmount, constants.SWAP_PERCENTAGE)

    -- Execute swap first to get paired token
    local swapSuccess = false
    local swapResult = nil
    if not utils.isZero(swapAmount) then
        swapSuccess, swapResult = mod.executeSwapForLP(msg, tokenIn, tokenOut, swapAmount, pushedFor)
    end

    -- Execute liquidity provision with both tokens
    local lpSuccess = false
    local lpResult = nil
    if swapSuccess and not utils.isZero(aoForLP) then
        -- We now have both AO and the swapped token for LP
        -- Send both AO tokens and swapped tokens to Botega for LP
        lpSuccess, lpResult = mod.executeLPWithBothTokens(
            msg,
            tokenIn,          -- AO token
            aoForLP,          -- AO amount to LP
            swapResult.tokenOut,  -- Swapped token (WAR)
            swapResult.amountOut, -- Swapped amount
            pushedFor
        )
    end

    -- Update state
    if swapSuccess or lpSuccess then
        ProcessedUpToDate = tonumber(msg.Tags["X-Swap-Date-To"]) or os.time()
        mod.strategySuccess(msg, {
            totalAmount = totalAmount,
            swapAmount = swapAmount,
            aoForLP = aoForLP,
            swapSuccess = swapSuccess,
            lpSuccess = lpSuccess,
            swapResult = swapResult,
            lpResult = lpResult,
            pushedFor = pushedFor
        })
    else
        mod.replyWithStrategyError(msg, "Both swap and LP operations failed")
    end
end

-- Execute swap operation
function mod.executeSwap(msg, tokenIn, tokenOut, amount, pushedFor, keepTokens)
    local dex = (utils.isValidDex(msg.Tags["X-Dex"]) and msg.Tags["X-Dex"]) or Dex

    if dex == enums.DexType.PERMASWAP then
        return mod.swapWithPermaswap(msg, tokenIn, tokenOut, amount, pushedFor, keepTokens)
    elseif dex == enums.DexType.BOTEGA then
        return mod.swapWithBotega(msg, tokenIn, tokenOut, amount, pushedFor, keepTokens)
    else
        -- Auto mode: try both and use better rate
        return mod.swapAuto(msg, tokenIn, tokenOut, amount, pushedFor, keepTokens)
    end
end

-- Execute swap for LP (keeps tokens for LP instead of transferring back)
function mod.executeSwapForLP(msg, tokenIn, tokenOut, amount, pushedFor)
    return mod.executeSwap(msg, tokenIn, tokenOut, amount, pushedFor, true)
end

-- Execute LP operation with both tokens (old function - keeping for compatibility)
function mod.executeLP(msg, tokenIn, amount)
    local poolId = constants.BOTEGA_POOL_IDS[TokenOut]  -- Use Botega for LP

    if not poolId then
        return false, "No pool available for LP with token " .. TokenOut
    end

    -- Initiate liquidity provision by sending first token with X-Action = "Provide"
    -- Botega's AMM factory will handle the LP logic from there
    local success = pcall(function()
        botega.provideLiquidity(poolId, tokenIn, amount)
    end)

    return success, success and "LP initiated" or "LP failed"
end

-- Execute LP with both tokens
-- Uses the appropriate DEX for LP based on configuration
function mod.executeLPWithBothTokens(msg, tokenA, amountA, tokenB, amountB, pushedFor)
    local dex = Dex or enums.DexType.AUTO

    if dex == enums.DexType.PERMASWAP then
        -- Use permaswap LP with deposit + AddLiquidity flow
        local poolId = constants.PERMASWAP_POOL_IDS[TokenOut or constants.GAME_PROCESS_ID]
        if not poolId then
            return false, "No Permaswap pool available for LP"
        end

        local success = pcall(function()
            permaswap.provideLiquidity(poolId, tokenA, amountA, tokenB, amountB)
        end)

        if success then
            print("Permaswap LP initiated: " .. tostring(amountA) .. " " .. tokenA ..
                  " + " .. tostring(amountB) .. " " .. tokenB)
            return true, "Permaswap LP initiated"
        else
            return false, "Failed to send tokens for Permaswap LP"
        end

    elseif dex == enums.DexType.BOTEGA then
        -- Use botega LP with X-Action = "Provide" flow
        local poolId = constants.BOTEGA_POOL_IDS[TokenOut or constants.GAME_PROCESS_ID]
        if not poolId then
            return false, "No Botega pool available for LP"
        end

        local success = pcall(function()
            botega.provideLiquidity(poolId, tokenA, amountA, tokenB, amountB)
        end)

        if success then
            print("Botega LP initiated: " .. tostring(amountA) .. " " .. tokenA ..
                  " + " .. tostring(amountB) .. " " .. tokenB)
            return true, "Botega LP initiated"
        else
            return false, "Failed to send tokens for Botega LP"
        end

    else
        -- Auto mode - try both, prefer the one with better rates
        -- For now, default to Botega since it's simpler
        return mod.executeLPWithBothTokens(msg, tokenA, amountA, tokenB, amountB, pushedFor)
    end
end

-- Swap with Permaswap
function mod.swapWithPermaswap(msg, tokenIn, tokenOut, amount, pushedFor, keepTokens)
    local poolId = constants.PERMASWAP_POOL_IDS[tokenOut]
    if not poolId then
        return false, "No Permaswap pool for " .. tokenOut
    end

    local output = permaswap.getExpectedOutput(poolId, tokenIn, amount)
    local requestOrder = permaswap.requestOrder(poolId, tokenIn, tokenOut, amount, output.expectedMinOutput)

    if not requestOrder.NoteID or not requestOrder.NoteSettle then
        return false, "Failed to get order details"
    end

    local swapData = {
        noteId = requestOrder.NoteID,
        noteSettle = requestOrder.NoteSettle,
        tokenIn = tokenIn,
        tokenOut = tokenOut,
        amountIn = amount,
        amountOut = output.amountOut,
        poolId = poolId,
        expectedMinOutput = output.expectedMinOutput
    }

    local success, swapResult = permaswap.swap(swapData)

    if success then
        -- Only transfer tokens back to owner if keepTokens is false
        if not keepTokens then
            token.transferToSelf(tokenOut, swapResult.Tags.Quantity)
        end

        return true, {
            tokenOut = tokenOut,
            amountIn = amount,
            amountOut = swapResult.Tags.Quantity,
            dex = enums.DexType.PERMASWAP,
            tokensKept = keepTokens
        }
    else
        return false, swapResult
    end
end

-- Swap with Botega
function mod.swapWithBotega(msg, tokenIn, tokenOut, amount, pushedFor, keepTokens)
    local poolId = constants.BOTEGA_POOL_IDS[tokenOut]
    if not poolId then
        return false, "No Botega pool for " .. tokenOut
    end

    local output = botega.getExpectedOutput(poolId, tokenIn, amount)

    local swapData = {
        tokenIn = tokenIn,
        tokenOut = tokenOut,
        amountIn = amount,
        amountOut = output.amountOut,
        expectedMinOutput = output.expectedMinOutput,
        poolId = poolId
    }

    local success, swapResult = botega.swap(swapData)

    if success then
        -- Only transfer tokens back to owner if keepTokens is false
        if not keepTokens then
            token.transferToSelf(tokenOut, swapResult.Tags.Quantity)
        end

        return true, {
            tokenOut = tokenOut,
            amountIn = amount,
            amountOut = swapResult.Tags["To-Quantity"],
            dex = enums.DexType.BOTEGA,
            tokensKept = keepTokens
        }
    else
        return false, swapResult
    end
end

-- Auto swap mode
function mod.swapAuto(msg, tokenIn, tokenOut, amount, pushedFor, keepTokens)
    local permaswapOutput = permaswap.getExpectedOutput(
        constants.PERMASWAP_POOL_IDS[tokenOut],
        tokenIn,
        amount
    )

    local botegaOutput = botega.getExpectedOutput(
        constants.BOTEGA_POOL_IDS[tokenOut],
        tokenIn,
        amount
    )

    if utils.isZero(permaswapOutput.amountOut) and utils.isZero(botegaOutput.amountOut) then
        return false, "No output from both DEXes"
    end

    if utils.gt(permaswapOutput.amountOut, botegaOutput.amountOut) then
        return mod.swapWithPermaswap(msg, tokenIn, tokenOut, amount, pushedFor, keepTokens)
    else
        return mod.swapWithBotega(msg, tokenIn, tokenOut, amount, pushedFor, keepTokens)
    end
end

-- Auto swap mode for LP (keeps tokens for LP)
function mod.swapAutoForLP(msg, tokenIn, tokenOut, amount, pushedFor)
    return mod.swapAuto(msg, tokenIn, tokenOut, amount, pushedFor, true)
end

-- Strategy success handler
function mod.strategySuccess(msg, strategyInfo)
    -- Update global state
    TotalTransactions = TotalTransactions + 1
    TotalAOSold = utils.add(TotalAOSold, strategyInfo.totalAmount)

    if strategyInfo.swapSuccess then
        TotalSwaps = (TotalSwaps or 0) + 1
        TotalSwapValue = utils.add(TotalSwapValue or "0", strategyInfo.swapAmount)
        TotalBought[strategyInfo.swapResult.tokenOut] = utils.add(
            TotalBought[strategyInfo.swapResult.tokenOut] or "0",
            strategyInfo.swapResult.amountOut
        )
    end

    if strategyInfo.lpSuccess then
        TotalLPs = (TotalLPs or 0) + 1
        -- LP uses both swap amount and aoForLP amount
        local totalLPValue = utils.add(strategyInfo.swapAmount or "0", strategyInfo.aoForLP or "0")
        TotalLPValue = utils.add(TotalLPValue or "0", totalLPValue)
    end

    SwapInProgress = false

    -- Check if end date reached
    if utils.hasReachedEndDate() then
        Status = enums.AgentStatus.COMPLETED
        ao.send({ Target = ao.id, Action = "Finalize-Agent" })
    end

    -- Reply with success
    mod.replyWithStrategySuccess(strategyInfo)
end

-- Reply with strategy success
function mod.replyWithStrategySuccess(strategyResult)
    local tags = {
        ["Total-Amount"] = strategyResult.totalAmount,
        ["Swap-Amount"] = strategyResult.swapAmount,
        ["AO-For-LP"] = strategyResult.aoForLP,
        ["Swap-Success"] = tostring(strategyResult.swapSuccess),
        ["LP-Success"] = tostring(strategyResult.lpSuccess),
        ["Strategy-Type"] = enums.StrategyType.SWAP_50_LP_50,
        ["Agent-Version"] = AgentVersion,
        ["Parent-Tx-Id"] = strategyResult.pushedFor
    }

    if strategyResult.swapSuccess then
        tags["Swap-Token-Out"] = strategyResult.swapResult.tokenOut
        tags["Swap-Amount-Out"] = strategyResult.swapResult.amountOut
        tags["Swap-Dex"] = strategyResult.swapResult.dex
    end

    ao.send({
        Target = Owner,
        Data = "Strategy executed successfully",
        Action = "Strategy-Success",
        Tags = tags
    })
end

-- Reply with strategy error
function mod.replyWithStrategyError(msg, error)
    SwapInProgress = false

    msg.reply({
        Data = "Failed to execute strategy: " .. (error or "Unknown error occurred"),
        Action = "Strategy-Error",
        Tags = {
            Error = "StrategyExecutionFailed",
            Status = "Failed",
            ["Agent-Version"] = AgentVersion
        }
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
local constants = require('src.libs.constants')
local utils = require('src.utils.utils')

local mod = {}

-- Get balance for a token
function mod.getBalance(tokenId)
    local result = ao.send({ Target = tokenId, Action = "Balance" }).receive()
    return result.Tags.Balance or "0"
end

-- Get AO token balance
function mod.getAOBalance()
    return mod.getBalance(constants.AO_PROCESS_ID)
end

-- Transfer tokens to a recipient
function mod.transferToRecipient(tokenId, quantity, recipient)
    ao.send({
        Target = tokenId,
        Action = "Transfer",
        Recipient = recipient,
        Quantity = quantity
    })
end

-- Transfer tokens back to owner
function mod.transferToSelf(tokenId, quantity)
    mod.transferToRecipient(tokenId, quantity, Owner)
end

-- Transfer all remaining balances to owner
function mod.transferRemainingBalanceToSelf()
    local aoBalance = mod.getAOBalance()
    if not utils.isZero(aoBalance) then
        mod.transferToSelf(constants.AO_PROCESS_ID, aoBalance)
    end

    local warBalance = mod.getBalance(constants.WAR_PROCESS_ID)
    if not utils.isZero(warBalance) then
        mod.transferToSelf(constants.WAR_PROCESS_ID, warBalance)
    end

    local wusdcBalance = mod.getBalance(constants.WUSDC_PROCESS_ID)
    if not utils.isZero(wusdcBalance) then
        mod.transferToSelf(constants.WUSDC_PROCESS_ID, wusdcBalance)
    end
end

-- Get balances for multiple tokens
function mod.getMultipleBalances(tokenIds)
    local balances = {}
    for _, tokenId in ipairs(tokenIds) do
        balances[tokenId] = mod.getBalance(tokenId)
    end
    return balances
end

return mod
end
end

do
local _ENV = _ENV
package.preload[ "utils.utils" ] = function( ... ) local arg = _G.arg;
local enums = require('src.libs.enums')
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

-- Yield LP Agent
-- A modular agent that implements a 50% swap + 50% liquidity provision strategy

-- Load modules
local constants = require('src.libs.constants')
local utils = require('src.utils.utils')
local enums = require('src.libs.enums')
local token = require('src.libs.token')
local strategy = require('src.libs.strategy')
local assertions = require('src.libs.assertions')
local botega = require('src.libs.botega')
local permaswap = require('src.libs.permaswap')
local json = require('json')

-- Agent State
Status = Status or enums.AgentStatus.ACTIVE
Dex = Dex or ao.env.Process.Tags["Dex"] or enums.DexType.AUTO
TokenOut = TokenOut or ao.env.Process.Tags["Token-Out"] or constants.GAME_PROCESS_ID
Slippage = Slippage or tonumber(ao.env.Process.Tags["Slippage"]) or constants.DEFAULT_SLIPPAGE
StartDate = StartDate or tonumber(ao.env.Process.Tags["Start-Date"]) or os.time()
EndDate = EndDate or tonumber(ao.env.Process.Tags["End-Date"]) or math.huge
RunIndefinitely = RunIndefinitely or ao.env.Process.Tags["Run-Indefinitely"] == "true"
ConversionPercentage = ConversionPercentage or tonumber(ao.env.Process.Tags["Conversion-Percentage"]) or 50
StrategyType = StrategyType or ao.env.Process.Tags["Strategy-Type"] or enums.StrategyType.SWAP_50_LP_50

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
            ["Swapped-Up-To-Date"] = tostring(SwappedUpToDate)
        })
    end
)

-- Update agent configuration
Handlers.add("Update-Agent", "Update-Agent",
    function(msg)
        assertions.checkWalletForPermission(msg)
        assertions.isAgentActive()

        -- Update DEX preference
        if utils.isValidDex(msg.Tags.Dex) then
            Dex = msg.Tags.Dex
        end

        -- Update slippage
        if utils.isValidSlippage(tonumber(msg.Tags.Slippage)) then
            Slippage = tonumber(msg.Tags.Slippage)
        end

        -- Update running time
        if utils.isValidRunningTime(tonumber(msg.Tags["Start-Date"]), tonumber(msg.Tags["End-Date"])) then
            StartDate = tonumber(msg.Tags["Start-Date"])
            EndDate = tonumber(msg.Tags["End-Date"])
        end

        -- Update token out
        if utils.isAddress(msg.Tags["Token-Out"]) then
            TokenOut = msg.Tags["Token-Out"]
        end

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

        if SwapInProgress then
            msg.reply({
                Action = "Strategy-Busy",
                Data = "Strategy execution already in progress"
            })
            return
        end

        SwapInProgress = true
        strategy.executeSwapAndLP(msg, msg.Id)
    end
)

-- Credit notice handler - triggers strategy execution and handles LP tokens
Handlers.add("Credit-Notice", "Credit-Notice",
    function(msg)
        local tokenId = msg.From or msg.Tags["From-Process"]
        local quantity = msg.Tags.Quantity

        -- Handle strategy execution for AO tokens
        if tokenId == constants.AO_PROCESS_ID and not utils.isZero(quantity) then
            if SwapInProgress then
                print("Strategy execution already in progress, queuing request")
                return
            end

            SwapInProgress = true
            ProcessedUpToDate = tonumber(msg.Tags["X-Swap-Date-To"]) or os.time()
            strategy.executeSwapAndLP(msg, msg.Tags["Pushed-For"])
        elseif tokenId ~= constants.GAME_PROCESS_ID then
            -- Handle LP tokens from Botega pools
            -- LP tokens are sent as Credit-Notice from the pool
            print("Received LP tokens: " .. tostring(quantity) .. " from " .. tokenId)
            -- Transfer LP tokens to owner so we can track them
            token.transferToSelf(tokenId, quantity)
        end
    end
)

-- Withdraw tokens
Handlers.add("Withdraw", "Withdraw",
    function(msg)
        assertions.checkWalletForPermission(msg, "Wallet does not have permission to withdraw")

        local tokenId = msg.Tags["Token-Id"]
        local quantity = msg.Tags["Quantity"]

        assertions.isAddress("Token-Id", tokenId)
        assertions.isTokenQuantity("Quantity", quantity)

        token.transferToSelf(tokenId, quantity)

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

        SwapInProgress = true

        -- Execute final strategy with remaining balance
        local aoBalance = token.getAOBalance()
        if not utils.isZero(aoBalance) then
            strategy.executeSwapAndLP(msg, msg.Id)
        end

        -- Transfer remaining balances
        token.transferRemainingBalanceToSelf()

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

-- AddLiquidity handler - permaswap equivalent
Handlers.add("AddLiquidity", "AddLiquidity",
    function(msg)
        -- Check which DEX to use
        local dex = Dex or enums.DexType.AUTO
        if dex == enums.DexType.PERMASWAP then
            permaswap.addLiquidityDirect(
                constants.PERMASWAP_POOL_IDS[TokenOut or constants.GAME_PROCESS_ID],
                msg.Tags.AmountA or "0",
                msg.Tags.AmountB or "0",
                msg.Tags.MinLiquidity or "0"
            )
        elseif dex == enums.DexType.BOTEGA then
            botega.provideLiquidity(
                constants.BOTEGA_POOL_IDS[TokenOut or constants.GAME_PROCESS_ID],
                constants.AO_PROCESS_ID,
                msg.Tags.AmountA or "0",
                constants.WAR_PROCESS_ID,
                msg.Tags.AmountB or "0"
            )
        end

        msg.reply({
            Action = "AddLiquidity-Received",
            Data = "AddLiquidity request processed"
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

-- Health check
Handlers.add("Health", "Health",
    function(msg)
        msg.reply({
            Action = "Health-Response",
            Status = "Healthy",
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
print("DEX: " .. Dex)
print("Process ID: " .. ao.id)

