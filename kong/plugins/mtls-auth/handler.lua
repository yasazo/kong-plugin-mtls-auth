-- Import required modules
local set_header = kong.service.request.set_header

-- Utility functions
local function is_empty(s)
    return s == nil or s == ''
end

-- Extract 'relative distinguished name' (which is a KEY=VALUE pair) from a distinguished name string, as given by start and end position
local function extract_and_add_rdn (t, dn, startPos, endPos)
    local delimiterPos, _ = string.find(dn, "=", startPos)
	if (delimiterPos)
	then
        local k = string.sub(dn, startPos, delimiterPos-1)
        local v = string.sub(dn, delimiterPos+1, endPos)
        t[k] = v
    end
end

-- Parse a distinguished name string in rfc2253 format into a map of 'relative distinguished names'
-- (i.e., KEY=VALUE pairs), allowing VALUEs to contain '\'-escaped comma characters
local function parse_dn (dn)
    local t={}
    local nextRdn = 1
	while(nextRdn <= #dn)
    do
        local endOfRdnPos, _ = string.find(dn, "[^\\],", nextRdn)
		if (endOfRdnPos == nil) then
            endOfRdnPos = #dn
        end
        extract_and_add_rdn (t, dn, nextRdn, endOfRdnPos)
        nextRdn = endOfRdnPos+2
    end
    return t
end

-- Define the handler
local MtlsAuth = {
    VERSION = "1.0.0",
    PRIORITY = 975
}

-- Define the access phase
function MtlsAuth:access(config)
-- Validate the client certificate
    if ngx.var.ssl_client_verify ~= "SUCCESS" then
        kong.response.exit(config.error_response_code, [[{"error":"invalid_request", "error_description": "mTLS client not provided or invalid"}]], {
            ["Content-Type"] = "application/json"
        })
    end

-- Extract and set headers based on the client certificate
    local cert_dn = parse_dn(ngx.var.ssl_client_s_dn)

    if not is_empty(config.upstream_cert_header) then
        set_header(config.upstream_cert_header, ngx.var.ssl_client_escaped_cert)
    end

    if not is_empty(config.upstream_cert_fingerprint_header) then
        set_header(config.upstream_cert_fingerprint_header, ngx.var.ssl_client_fingerprint)
    end

    if not is_empty(config.upstream_cert_serial_header) then
        set_header(config.upstream_cert_serial_header, ngx.var.ssl_client_serial)
    end

    if not is_empty(config.upstream_cert_i_dn_header) then
        set_header(config.upstream_cert_i_dn_header, ngx.var.ssl_client_i_dn)
    end

    if not is_empty(config.upstream_cert_s_dn_header) then
        set_header(config.upstream_cert_s_dn_header, ngx.var.ssl_client_s_dn)
    end

    if not is_empty(config.upstream_cert_cn_header) then
        set_header(config.upstream_cert_cn_header, cert_dn["CN"])
    end

    if not is_empty(config.upstream_cert_org_header) then
        set_header(config.upstream_cert_org_header, cert_dn["O"])
    end
end

return MtlsAuth
