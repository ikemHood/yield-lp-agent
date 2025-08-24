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
