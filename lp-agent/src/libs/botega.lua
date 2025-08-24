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
