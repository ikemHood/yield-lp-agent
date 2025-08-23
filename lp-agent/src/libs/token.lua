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
    local aoBalance = mod.getAOBalance()
    if not utils.isZero(aoBalance) then
        mod.transferToSelf(constants.AO_PROCESS_ID, aoBalance)
    end

    local warBalance = mod.getBalance(constants.WAR_PROCESS_ID)
    if not utils.isZero(warBalance) then
        mod.transferToSelf(constants.WAR_PROCESS_ID, warBalance)
    end

    local wusdcBalance = mod.getBalance(constants.WUSDC_PROCESS_ID)
    if not utils.isZero(wusdcBalance) then
        mod.transferToSelf(constants.WUSDC_PROCESS_ID, wusdcBalance)
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
