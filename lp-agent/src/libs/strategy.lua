---@diagnostic disable: undefined-global
local constants = require('libs.constants')
local utils = require('utils.utils')
local enums = require('libs.enums')
local token = require('libs.token')
local permaswap = require('libs.permaswap')
local botega = require('libs.botega')
local json = require('json')

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
        -- Auto mode: prefer Botega if a mapped pool exists; otherwise fall back to Permaswap
        local botePool = constants.BOTEGA_POOL_IDS[TokenOut or constants.GAME_PROCESS_ID]
        if botePool then
            local success = pcall(function()
                botega.provideLiquidity(botePool, tokenA, amountA, tokenB, amountB)
            end)
            if success then
                print("Botega LP initiated (AUTO): " .. tostring(amountA) .. " " .. tokenA ..
                      " + " .. tostring(amountB) .. " " .. tokenB)
                return true, "Botega LP initiated (AUTO)"
            else
                return false, "Failed to send tokens for Botega LP (AUTO)"
            end
        end

        local permaPool = constants.PERMASWAP_POOL_IDS[TokenOut or constants.GAME_PROCESS_ID]
        if permaPool then
            local success = pcall(function()
                permaswap.provideLiquidity(permaPool, tokenA, amountA, tokenB, amountB)
            end)
            if success then
                print("Permaswap LP initiated (AUTO): " .. tostring(amountA) .. " " .. tokenA ..
                      " + " .. tostring(amountB) .. " " .. tokenB)
                return true, "Permaswap LP initiated (AUTO)"
            else
                return false, "Failed to send tokens for Permaswap LP (AUTO)"
            end
        end

        return false, "No pool available for LP in AUTO mode"
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

    return chosenDex, poolId
end

-- Fire-and-forget swap trigger; rely on later Credit-Notice for TokenOut
function mod.triggerSwapFireAndForget(dex, poolId, tokenOutId, swapAmount)
    if utils.isZero(swapAmount) then return end
    local base = mod.getBaseTokenId()
    if dex == enums.DexType.PERMASWAP then
        if not poolId then return end
        local out = permaswap.getExpectedOutput(poolId, base, swapAmount)
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
    elseif dex == enums.DexType.BOTEGA then
        if not poolId then return end
        local out = botega.getExpectedOutput(poolId, base, swapAmount)
        ao.send({
            Target = base,
            Action = "Transfer",
            Recipient = poolId,
            Quantity = tostring(swapAmount),
            ["X-Expected-Min-Output"] = tostring(out.expectedMinOutput),
            ["X-Swap-Nonce"] = botega.getSwapNonce(),
            ["X-Action"] = "Swap"
        })
    end
end

-- Send a token to pool appropriately for LP depending on dex
function mod.lpSendTokenToPool(dex, poolId, tokenId, quantity, amountA, amountB)
    if not poolId or not tokenId or utils.isZero(quantity) then return end
    if dex == enums.DexType.BOTEGA then
        ao.send({
            Target = tokenId,
            Action = "Transfer",
            Recipient = poolId,
            Quantity = tostring(quantity),
            ["X-Action"] = "Provide"
        })
    elseif dex == enums.DexType.PERMASWAP then
        ao.send({
            Target = tokenId,
            Action = "Transfer",
            Recipient = poolId,
            Quantity = tostring(quantity),
            ["X-PS-For"] = "LP",
            ["X-Amount-A"] = tostring(amountA or "0"),
            ["X-Amount-B"] = tostring(amountB or "0")
        })
    end
end

-- Add liquidity call for permaswap after deposits
function mod.lpAddLiquidityPermaswap(poolId, amountA, amountB)
    if not poolId then return end
    ao.send({
        Target = poolId,
        Action = "AddLiquidity",
        MinLiquidity = "0",
        ["X-Amount-A"] = tostring(amountA or "0"),
        ["X-Amount-B"] = tostring(amountB or "0")
    })
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
