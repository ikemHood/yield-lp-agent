local constants = {
    -- AO Ecosystem Token IDs
    AO_PROCESS_ID = "0syT13r0s0tgPmIed95bJnuSqaD29HQNN8D3ElLSrsc",
    GAME_PROCESS_ID = "s6jcB3ctSbiDNwR-paJgy5iOAhahXahLul8exSLHbGE",

    -- DEX Pool IDs
    PERMASWAP_AO_GAME_POOL_ID = "hbRwutwINSXCNxXxVNoNRT2YQk-OIX3Objqu85zJrLo",
    BOTEGA_AO_GAME_POOL_ID = "rG-b4gQwhfjnbmYhrnvCMDPuXguqmAmYwHZf4y24WYs",

    -- DEX Factory IDs
    BOTEGA_AMM_FACTORY_ID = "3XBGLrygs11K63F_7mldWz4veNx6Llg6hI2yZs8LKHo",

    -- Fee Process ID
    FEE_PROCESS_ID = "oOx8YhMyPkeV78LqGw2_BZSKSb4LzwdKEPo0_xwCdLk",

    -- Strategy Configuration
    SWAP_PERCENTAGE = 50,  -- 50% for swapping
    LP_PERCENTAGE = 50,    -- 50% for liquidity provision

    -- Default Configuration
    DEFAULT_SLIPPAGE = 1.0,
    DEFAULT_LP_SLIPPAGE = 1.0,  -- Higher slippage tolerance for LP
    AGENT_VERSION = "0.1.3"
}

-- Pool ID mappings
constants.PERMASWAP_POOL_IDS = {
    [constants.GAME_PROCESS_ID] = constants.PERMASWAP_AO_GAME_POOL_ID
}

constants.BOTEGA_POOL_IDS = {
    [constants.GAME_PROCESS_ID] = constants.BOTEGA_AO_GAME_POOL_ID
}

return constants
