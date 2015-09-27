local crypto = require "crypto"
local json = require "json"

local reqType = ngx.var.request_method
if reqType == ngx.HTTP_POST 
    OR reqType == ngx.HTTP_DELETE 
    OR reqType == ngx.HTTP_PUT 
then
    res = ngx.location.capture("/write_instance")
else
    res = ngx.location.capture("/read_instance")
end
ngx.say(res.body)


local data = ngx.req.read_body()
local args = ngx.req.get_post_args()

for key, val in pairs(args) do
    if key == "access_token" then
        local digest = crypto.hmac.digest("sha256", val, APPSECRETID, false)
        args["appsecret_proof"] = digest
    end
end

local newdata = json.encode(args)
ngx.req.set_body_data(newdata)
        
    lua_package_path    "$prefix/?.lua;;";
    lua_shared_dict     log_dict    1M;

    local aes = require "resty.aes"
    local str = require "resty.string"
    local aes_256_cbc_sha256x5 = aes:new("AKeyForAES-256-CBC", "MySalt!", aes.cipher(256,"cbc"), aes.hash.sha512, 5)
        -- AES 256 CBC with 5 rounds of SHA-512 for the key
        -- and a salt of "MySalt!"
    local encrypted = aes_256_cbc_sha512x5:encrypt("Really secret message!")
    ngx.say("AES 256 CBC (SHA-512, salted) Encrypted HEX: ", str.to_hex(encrypted))
    ngx.say("AES 256 CBC (SHA-512, salted) Decrypted: ",
        aes_256_cbc_sha512x5:decrypt(encrypted))