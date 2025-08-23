local constants = {
    -- AO Ecosystem Token IDs
    AO_PROCESS_ID = "0syT13r0s0tgPmIed95bJnuSqaD29HQNN8D3ElLSrsc",
    WAR_PROCESS_ID = "xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10",
    WUSDC_PROCESS_ID = "7zH9dlMNoxprab9loshv3Y7WG45DOny_Vrq9KrXObdQ",
    GAME_PROCESS_ID = "s6jcB3ctSbiDNwR-paJgy5iOAhahXahLul8exSLHbGE",

    -- DEX Pool IDs
    PERMASWAP_AO_WAR_POOL_ID = "FRF1k0BSv0gRzNA2n-95_Fpz9gADq9BGi5PyXKFp6r8",
    PERMASWAP_AO_WUSDC_POOL_ID = "gjnaCsEd749ZXeG2H8akvf8wzbl7CQ4Ox-KYEBAdONk",
    PERMASWAP_AO_GAME_POOL_ID = "hbRwutwINSXCNxXxVNoNRT2YQk-OIX3Objqu85zJrLo",
    BOTEGA_AO_WAR_POOL_ID = "B6qAwHi2OjZmyFCEU8hV6FZDSHbAOz8r0yy-fBbuTus",
    BOTEGA_AO_WUSDC_POOL_ID = "TYqlQ2vqkF0H6nC0mCgGe6G12pqq9DsSXpvtHYc6_xY",
    BOTEGA_AO_GAME_POOL_ID = "rG-b4gQwhfjnbmYhrnvCMDPuXguqmAmYwHZf4y24WYs",

    -- DEX Factory IDs
    BOTEGA_AMM_FACTORY_ID = "3XBGLrygs11K63F_7mldWz4veNx6Llg6hI2yZs8LKHo",

    -- Fee Process ID
    FEE_PROCESS_ID = "rkAezEIgacJZ_dVuZHOKJR8WKpSDqLGfgPJrs_Es7CA",

    -- Strategy Configuration
    SWAP_PERCENTAGE = 50,  -- 50% for swapping
    LP_PERCENTAGE = 50,    -- 50% for liquidity provision

    -- Default Configuration
    DEFAULT_SLIPPAGE = 0.5,
    DEFAULT_LP_SLIPPAGE = 1.0,  -- Higher slippage tolerance for LP
    AGENT_VERSION = "1.0.0"
}

-- Pool ID mappings
constants.PERMASWAP_POOL_IDS = {
    [constants.WAR_PROCESS_ID] = constants.PERMASWAP_AO_WAR_POOL_ID,
    [constants.WUSDC_PROCESS_ID] = constants.PERMASWAP_AO_WUSDC_POOL_ID,
    [constants.GAME_PROCESS_ID] = constants.PERMASWAP_AO_GAME_POOL_ID
}

constants.BOTEGA_POOL_IDS = {
    [constants.WAR_PROCESS_ID] = constants.BOTEGA_AO_WAR_POOL_ID,
    [constants.WUSDC_PROCESS_ID] = constants.BOTEGA_AO_WUSDC_POOL_ID,
    [constants.GAME_PROCESS_ID] = constants.BOTEGA_AO_GAME_POOL_ID
}

return constants
