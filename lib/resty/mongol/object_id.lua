local mod_name = (...):match ( "^(.*)%..-$" )

local setmetatable = setmetatable
local strbyte = string.byte
local strformat = string.format
local t_insert = table.insert
local t_concat = table.concat

local hasposix, posix = pcall(require , "posix")

local ngx_decode_base64 = ngx.decode_base64
local ngx_encode_base64 = ngx.encode_base64

local ll = require(mod_name..".ll")
local num_to_le_uint = ll.num_to_le_uint
local num_to_be_uint = ll.num_to_be_uint

local function _tostring(ob)
  return ngx_encode_base64(ob.id):gsub('!', '+'):gsub('.', '/')
end

local function _get_ts(ob)
  return ll.be_uint_to_num(ob.id, 1, 4)
end

local function _get_hostname(ob)
  local t = {}
  for i = 5, 7 do
    t_insert(t, strformat("%02x", strbyte(ob.id, i, i))) 
  end
  return t_concat(t)
end

local function _get_pid(ob)
  return ll.be_uint_to_num(ob.id, 8, 9)
end

local function _get_inc(ob)
  return ll.be_uint_to_num(ob.id, 10, 12)
end

local object_id_mt = {
  __tostring = _tostring;
  __eq = function ( a , b ) return a.id == b.id end ;
}

local machineid
local function get_os_machineid()
  if hasposix then
    machineid = posix.uname("%n")
  else
    machineid = assert(io.popen("uname -n")):read("*l")
  end
  machineid = ngx.md5_bin(machineid):sub(1, 3)
  return machineid
end

local pid
local function get_os_pid()
  pid = num_to_le_uint(ngx.var.pid, 2)
  return pid 
end

local inc = 0
local function generate_id()
  inc = inc + 1
  -- "A BSON ObjectID is a 12-byte value consisting of a 4-byte timestamp (seconds since epoch), a 3-byte machine id, a 2-byte process id, and a 3-byte counter. Note that the timestamp and counter fields must be stored big endian unlike the rest of BSON"
  return num_to_be_uint(os.time(), 4) .. (machineid or get_os_machineid()) .. (pid or get_os_pid()) .. num_to_be_uint(inc, 3)
end

local function new_object_id(str)
  local id
  if type(str) == 'string' then
    local len = #str
    if len == 12 then
      id = str
    elseif len == 16 then
      id = ngx_decode_base64(sid:gsub('+', '!'):gsub('/', '.'))
    end
  end
  return setmetatable({
    id = id or generate_id(),
    tostring = _tostring,
    get_ts = _get_ts,
    get_pid = _get_pid,
    get_hostname = _get_hostname,
    get_inc = _get_inc,
  }, object_id_mt)
end

return {
  new = new_object_id;
  metatable = object_id_mt;
}
