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
