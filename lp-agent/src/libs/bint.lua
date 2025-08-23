-- Fallback bint implementation for AO processes
-- This is a simplified version for basic arithmetic operations

local bint = {}

-- Create a new bint instance
function bint.new(value)
    local self = {
        value = tostring(value or 0)
    }

    -- Basic arithmetic operations
    function self:add(other)
        return bint.new(tostring(tonumber(self.value) + tonumber(other.value or other)))
    end

    function self:sub(other)
        return bint.new(tostring(tonumber(self.value) - tonumber(other.value or other)))
    end

    function self:mul(other)
        return bint.new(tostring(tonumber(self.value) * tonumber(other.value or other)))
    end

    function self:div(other)
        return bint.new(tostring(math.floor(tonumber(self.value) / tonumber(other.value or other))))
    end

    function self:udiv(other)
        return self:div(other)  -- Same as div for positive numbers
    end

    -- Comparison operations
    function self:lt(other)
        return tonumber(self.value) < tonumber(other.value or other)
    end

    function self:lte(other)
        return tonumber(self.value) <= tonumber(other.value or other)
    end

    function self:gt(other)
        return tonumber(self.value) > tonumber(other.value or other)
    end

    function self:gte(other)
        return tonumber(self.value) >= tonumber(other.value or other)
    end

    function self:eq(other)
        return tonumber(self.value) == tonumber(other.value or other)
    end

    function self:zero()
        return bint.new(0)
    end

    function self:isbint(val)
        return type(val) == "table" and val.value ~= nil
    end

    -- Convert to string
    function self:__tostring()
        return self.value
    end

    return self
end

-- Module functions
function bint.__add(a, b)
    return a:add(b)
end

function bint.__sub(a, b)
    return a:sub(b)
end

function bint.__mul(a, b)
    return a:mul(b)
end

function bint.udiv(a, b)
    return a:udiv(b)
end

function bint.__lt(a, b)
    return a:lt(b)
end

function bint.__le(a, b)
    return a:lte(b)
end

function bint.__gt(a, b)
    return a:gt(b)
end

function bint.__ge(a, b)
    return a:gte(b)
end

function bint.__eq(a, b)
    return a:eq(b)
end

function bint.zero()
    return bint.new(0)
end

function bint.isbint(val)
    return type(val) == "table" and val.value ~= nil
end

-- Create bint instance with specified bits
setmetatable(bint, {
    __call = function(_, bits)
        return bint.new
    end
})

return bint
