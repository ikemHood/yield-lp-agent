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
local botega = require('libs.botega')
local permaswap = require('libs.permaswap')
local json = require('json')

-- Agent State
Status = Status or enums.AgentStatus.ACTIVE
Dex = Dex or ao.env.Process.Tags["Dex"] or enums.DexType.PERMASWAP
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
    local totalAmount = token.getAOBalance()
    if utils.isZero(totalAmount) then
        SwapInProgress = false
        return false
    end

    local swapAmount, aoForLP = utils.splitQuantity(totalAmount, constants.SWAP_PERCENTAGE)
    local chosenDex, poolId = strategy.chooseDexAndPool(tokenOutId, swapAmount)

    -- Fire-and-forget swap; rely on TokenOut credit notice later
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

        -- AO credit: trigger swap only and stage LP
        if tokenId == constants.AO_PROCESS_ID and not utils.isZero(quantity) then
            -- If outside active window, immediately return credited amount and notify
            local now = os.time()
            if not utils.isWithinActiveWindow(now) then
                token.transferToSelf(constants.AO_PROCESS_ID, quantity)
                ao.send({
                    Target = Owner,
                    Action = "Strategy-Skipped-Time-Window",
                    Data = "AO credit received but outside active time window; returned funds to owner",
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
            local tokenOutId = msg.Tags["Token-Out"] or TokenOut
            initiateStagedFlow(msg, tokenOutId)

            -- TokenOut credit: send TokenOut to pool first
        elseif LPFlowActive and LPFlowState == enums.LPFlowState.AWAIT_TOKEN_OUT_CREDIT and tokenId == LPFlowTokenOutId and not utils.isZero(quantity) then
            LPFlowTokenOutAmount = quantity
            strategy.lpSendTokenToPool(LPFlowDex, LPFlowPoolId, LPFlowTokenOutId, quantity, LPFlowAoAmount, quantity)
            LPFlowState = enums.LPFlowState.TOKEN_OUT_SENT
        else
            -- For other credits, transfer to self so we can track them
            if tokenId ~= TokenOut then
                token.transferToSelf(tokenId, quantity)
            end
        end
    end
)

Handlers.add("Debit-Notice", "Debit-Notice",
    function(msg)
        local tokenId = msg.From or msg.Tags["From-Process"]
        -- local quantity = msg.Tags.Quantity -- not used for decision

        -- When our TokenOut transfer is debited, send AO and (for permaswap) call AddLiquidity
        if LPFlowActive and LPFlowState == enums.LPFlowState.TOKEN_OUT_SENT and tokenId == LPFlowTokenOutId then
            if LPFlowDex == enums.DexType.BOTEGA then
                strategy.lpSendTokenToPool(LPFlowDex, LPFlowPoolId, constants.AO_PROCESS_ID, LPFlowAoAmount)
            elseif LPFlowDex == enums.DexType.PERMASWAP then
                strategy.lpSendTokenToPool(LPFlowDex, LPFlowPoolId, constants.AO_PROCESS_ID, LPFlowAoAmount,
                    LPFlowAoAmount, LPFlowTokenOutAmount)
                strategy.lpAddLiquidityPermaswap(LPFlowPoolId, LPFlowAoAmount, LPFlowTokenOutAmount)
            end

            LPFlowState = enums.LPFlowState.COMPLETED
            LPFlowActive = false
            SwapInProgress = false

            -- If a run is pending, and we're within window, immediately start a new staged flow
            if LPFlowPending then
                local now = os.time()
                if utils.isWithinActiveWindow(now) then
                    LPFlowPending = false
                    SwapInProgress = true
                    initiateStagedFlow(nil, TokenOut)
                end
            end
        end
    end
)

-- Withdraw tokens
Handlers.add("Withdraw", "Withdraw",
    function(msg)
        assertions.checkWalletForPermission(msg, "Wallet does not have permission to withdraw")

        local tokenId = msg.Tags["Token-Id"]
        local quantity = msg.Tags["Quantity"]
        local all = msg.Tags["ALL"]

        assertions.isAddress("Token-Id", tokenId)
        assertions.isTokenQuantity("Quantity", quantity)

        if all == "true" then
            local balance = token.getBalance(tokenId)
            token.transferToSelf(tokenId, balance)
        else
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
print("DEX: " .. Dex)
print("owner: " .. Owner)
print("Process ID: " .. ao.id)
