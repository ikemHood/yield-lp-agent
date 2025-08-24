---@diagnostic disable: undefined-global
local utils = require('utils.utils')
local enums = require('libs.enums')

local mod = {}

-- Validate token quantity
function mod.isTokenQuantity(name, quantity)
    local numQuantity = tonumber(quantity)
    assert(utils.isTokenQuantity(numQuantity),
        "Invalid quantity `" .. name .. "`. Must be a valid token quantity.")
end

-- Validate address
function mod.isAddress(name, value)
    assert(utils.isAddress(value),
        "Invalid address `" .. name .. "`. Must be a valid Arweave address.")
end

-- Validate percentage
function mod.isPercentage(name, value)
    assert(utils.isPercentage(value),
        "Invalid percentage `" .. name .. "`. Must be a valid percentage.")
end

-- Validate slippage
function mod.isValidSlippage(name, value)
    assert(utils.isValidSlippage(value),
        "Invalid slippage `" .. name .. "`. Must be a valid slippage percentage.")
end

-- Validate DEX type
function mod.isValidDex(name, value)
    assert(utils.isValidDex(value),
        "Invalid dex `" .. name .. "`. Must be a valid dex type.")
end

-- Validate running time
function mod.isValidRunningTime(name1, name2, startDate, endDate)
    assert(utils.isValidRunningTime(startDate, endDate),
        "Invalid running time `" .. name1 .. "` and `" .. name2 .. "`. Must be a valid running time.")
end

-- Validate strategy type
function mod.isValidStrategy(name, value)
    assert(utils.isValidStrategy(value),
        "Invalid strategy `" .. name .. "`. Must be a valid strategy type.")
end

-- Validate agent version
function mod.isValidAgentVersion(name, value)
    assert(utils.isValidAgentVersion(value),
        "Invalid agent version `" .. name .. "`. Must be a valid version format.")
end

-- Validate boolean
function mod.isValidBoolean(name, value)
    assert(utils.isValidBoolean(value),
        "Invalid boolean `" .. name .. "`. Must be 'true' or 'false'.")
end

-- Validate status
function mod.isValidStatus(name, value)
    assert(utils.isValidStatus(value),
        "Invalid status `" .. name .. "`. Must be a valid agent status.")
end

-- Check wallet permission
function mod.checkWalletForPermission(msg, errorMessage)
    assert(ao.id == msg.From or Owner == msg.From,
        errorMessage or "Wallet does not have permission to perform this action.")
end

-- Check if agent is active
function mod.isAgentActive()
    assert(Status == enums.AgentStatus.ACTIVE,
        "Agent is not active and cannot perform operations.")
end

-- Check if operation is valid
function mod.isValidOperation(name, value)
    assert(value == enums.OperationType.SWAP or
           value == enums.OperationType.LIQUIDITY_PROVISION or
           value == enums.OperationType.WITHDRAWAL,
        "Invalid operation type `" .. name .. "`. Must be a valid operation.")
end

return mod
