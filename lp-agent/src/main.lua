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
