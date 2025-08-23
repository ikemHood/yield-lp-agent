local constants = require('libs.constants')
local utils = require('utils.utils')
local enums = require('libs.enums')
local token = require('libs.token')
local permaswap = require('libs.permaswap')
local botega = require('libs.botega')

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
