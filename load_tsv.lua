local csv = require "csv-copy"
-- musíme escapovat uvozovky a zalomení řádků v buňkách
local function fix_tsv(text)
  text = text:gsub('""([^%s])',"'%1") -- uvozovka na zacatku
  text = text:gsub('(^%s])""', "%1'") -- uvozovka na konci
  text = text:gsub('(%b"")', function(a) return a:gsub("\n", "|") end) -- zalomeni radku
  return text
end

-- původní funkce, nebude používat
local function load_tsv(filename, skip_first)
  local skip_first = skip_first
  local t = {}
  local labels = {}
  local first = true
  local broken_line = false
  local continue = {}
  for line in io.lines( filename) do
    local i = 1
    local l = continue or {} 
    local cells = string.explode(line,"\t")
    if broken_line then
      -- poslední buňka předešlého řádku a první buňka současného patří k sobě
      l[#l] = l[#l] .. "\n" .. (cells[1] or "")
      for i =2, #cells do
        table.insert(l, cells[i])
      end
    else
      for i,m in ipairs(cells) do -- "([^%\t]*)"
        l[labels[i] or i] = m
        l[i] = m
        if first then
          labels[i] = m
        end
        -- i = i + 1
      end
      first = false
    end
    if not skip_first then
      -- detekce zalomení řádku v buňce
      if #l < #labels then
        broken_line = true
        continue = l
      else
        t[#t+1] = l
        continue = {}
        broken_line = false
      end
    else
      -- labels = l
    end
    skip_first = false
  end
  return t
end

local function is_multiline(record)
  -- detekce je primitivní, první položka záznamu je ID, které není nikdy rozdělené na víc řádků
  -- když chybí, můžeme předpokládat, že současný řádek patří k předešlému záznamu
  if record[1] == "" then
    return true
  end
  return false
end


local function join_lines(data, record)
  -- spojit buňky, které patří k jednomu záznamu a jsou na jednom řádku
  -- získat poslední záznam a přidávat k němu data z řádku
  local last_record = data[#data]
  for i, x in ipairs(record) do
    -- přidat jen neprázdné řetězce
    if x~="" then
      -- oddělit řádky pomocí znaku |, aby šly později zase rozdělit
      last_record[i] = last_record[i] .. "|" .. x
    end
  end
  return data
end

local function load_tsv2(filename)
  local data = {}
  local f = io.open(filename, "r")
  if not f then return nil, "Cannot open ".. filename end
  local text = f:read("*all")
  local fixed = fix_tsv(text)
  local records = csv.openstring(fixed,{separator="\t"})
  local first = true -- ignore the first line with a header
  local i = 1
  for record in records:lines() do
    if not first then 
      -- detekuj řádek, který je vyprodukovaný z rozdělených buňek
      if is_multiline(record) then
        join_lines(data, record)
      else
        data[#data + 1] = record 
      end
    end
    first = false
    i = i + 1
  end
  -- for k,v in ipairs(data[1]) do print(k,v) end
  return data
end

return load_tsv2
