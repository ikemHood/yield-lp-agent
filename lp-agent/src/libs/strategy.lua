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
