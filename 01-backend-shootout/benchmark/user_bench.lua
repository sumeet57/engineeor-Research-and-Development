-- Randomize user ID per request (1–1000)
math.randomseed(os.time())

request = function()
    local id = math.random(1, 1000)
    return wrk.format("GET", "/user/" .. id)
end
