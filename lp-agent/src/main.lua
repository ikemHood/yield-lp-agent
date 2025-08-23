-- Yield LP Agent
-- A modular agent that implements a 50% swap + 50% liquidity provision strategy

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
        elseif tokenId ~= TokenOut then
            -- Transfer LP tokens to owner so we can track them
            token.transferToSelf(tokenId, quantity)
        end
    end
)

-- Handlers.add("Debit-Notice", "Debit-Notice",
--     function(msg)
--         local tokenId = msg.From or msg.Tags["From-Process"]
--         local quantity = msg.Tags.Quantity

--         -- Handle strategy execution for AO tokens
--         if tokenId == TokenOut and not utils.isZero(quantity) then
--             if SwapInProgress then
--                 print("Strategy execution already in progress, queuing request")
--                 return
--             end

--             SwapInProgress = true
--             ProcessedUpToDate = tonumber(msg.Tags["X-Swap-Date-To"]) or os.time()
--             strategy.executeSwapAndLP(msg, msg.Tags["Pushed-For"])
--         elseif tokenId ~= TokenOut then
--             -- Transfer LP tokens to owner so we can track them
--             token.transferToSelf(tokenId, quantity)
--         end
--     end
-- )

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
print("Process ID: " .. ao.id)

