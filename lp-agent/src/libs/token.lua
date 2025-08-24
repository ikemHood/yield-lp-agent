local constants = require('libs.constants')
local utils = require('utils.utils')

local mod = {}

-- Get balance for a token
function mod.getBalance(tokenId)
    local result = ao.send({ Target = tokenId, Action = "Balance" }).receive()
    return result.Tags.Balance or "0"
end

-- Get AO token balance
function mod.getAOBalance()
    return mod.getBalance(constants.AO_PROCESS_ID)
end

-- Transfer tokens to a recipient
function mod.transferToRecipient(tokenId, quantity, recipient)
    ao.send({
        Target = tokenId,
        Action = "Transfer",
        Recipient = recipient,
        Quantity = quantity
    })
end

-- Transfer tokens back to owner
function mod.transferToSelf(tokenId, quantity)
    mod.transferToRecipient(tokenId, quantity, Owner)
end

-- Transfer all remaining balances to owner
function mod.transferRemainingBalanceToSelf()
    -- Build a unique list of token IDs to return balances for
    local toCheck = {}
    local seen = {}

    local function addToken(id)
        if id and not seen[id] then
            table.insert(toCheck, id)
            seen[id] = true
        end
    end

    -- Always include AO
    addToken(constants.AO_PROCESS_ID)
    -- Include configured TokenOut when set and not AO
    if TokenOut and TokenOut ~= constants.AO_PROCESS_ID then
        addToken(TokenOut)
    end
    -- Optionally include well-known tokens if defined in constants
    if constants.WAR_PROCESS_ID then addToken(constants.WAR_PROCESS_ID) end
    if constants.WUSDC_PROCESS_ID then addToken(constants.WUSDC_PROCESS_ID) end

    -- Transfer any non-zero balances back to owner
    for _, tokenId in ipairs(toCheck) do
        local balance = mod.getBalance(tokenId)
        if not utils.isZero(balance) then
            mod.transferToSelf(tokenId, balance)
        end
    end
end

-- Get balances for multiple tokens
function mod.getMultipleBalances(tokenIds)
    local balances = {}
    for _, tokenId in ipairs(tokenIds) do
        balances[tokenId] = mod.getBalance(tokenId)
    end
    return balances
end

return mod
