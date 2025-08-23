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
