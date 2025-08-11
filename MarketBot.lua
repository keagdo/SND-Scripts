--[=====[
[[SND Metadata]]
author: plottingCreeper & Allison
version: 2.0.0
description: >-
  MarketBotty! Fuck it, I'm going there again. 
  Thanks to the base from Creeper, updated and working on SND v13.2
  Market automation tool
  YOU NEED TO ADD YOUR CHARACTER NAMES AND RETAINERS MANUALLY
plugin_dependencies:
- AutoRetainer
configs:
  Undercut amount:
    default: 1
    description: Always undercut by 1 gil.
    type: int
  Don't undercut my retainers?:
    default: true
    type: boolean
  Price sanity checking?:
    default: true
    description: Ignores market results below half the trimmed mean of historical prices.
    type: boolean
  Use blacklist?:
    default: true
    type: boolean
  History trim amount:
    default: 5
    type: int
  History multiplier:
    default: round
    type: string
  Use overrides?:
    default: true
    type: boolean
  Check for HQ items?:
    default: false
    description: Not working yet.
    type: boolean
  Override report?:
    default: true
    type: boolean
  Postrun 1 gil report?:
    default: true
    type: boolean
  Postrun sanity report?:
    default: true
    type: boolean
  Verbose mode?:
    default: false
    type: boolean
  Debug mode?:
    default: false
    type: boolean
  Name rechecks:
    default: 10
    type: int
  Multimode enabled?:
    default: false
    type: boolean
  Start wait?:
    default: false
    type: boolean
  After multi:
    default: false
    type: any
  Autoretainer while waiting?:
    default: false
    type: boolean
  Multimode ending command:
    default: /ays multi e
    type: string
  Use AR to enter house?:
    default: true
    type: boolean
  Autoretainer compatibility?:
    default: false
    type: boolean

[[End Metadata]]
--]=====]

my_characters = { --Characters to switch to in multimode
  "FirstName LastName@HomeWorld",
  "FirstName LastName@HomeWorld",
}
my_retainers = { --Retainers to avoid undercutting
  "Name1",
  "Name2",
}
blacklist_retainers = { --Do not run script on these retainers
}
item_overrides = { --Item names with no spaces or symbols
  StuffedAlpha = { maximum = 450 },
  StuffedBomBoko = { minimum = 450 },
  Coke = { minimum = 450, maximum = 5000 },
  RamieTabard = { default = 25000 },
}

undercut = Config.Get("Undercut amount")
is_dont_undercut_my_retainers = Config.Get("Don't undercut my retainers?")
is_price_sanity_checking = Config.Get("Price sanity checking?")
is_using_blacklist = Config.Get("Use blacklist?")
history_trim_amount = Config.Get("History trim amount")
history_multiplier = Config.Get("History multiplier")
is_using_overrides = Config.Get("Use overrides?")
is_check_for_hq = Config.Get("Check for HQ items?")

is_override_report = Config.Get("Override report?")
is_postrun_one_gil_report = Config.Get("Postrun 1 gil report?")
is_postrun_sanity_report = Config.Get("Postrun sanity report?")

is_verbose = Config.Get("Verbose mode?")
is_debug = Config.Get("Debug mode?")
name_rechecks = Config.Get("Name rechecks")

--[=====[
Not implemented

Future Configs:

Read from files?:
    default: true
    type: boolean
  Write to files?:
    default: true
    type: boolean
  Echo during read?:
    default: false
    type: boolean
  Config folder (inside of APPDATA):
    default: "\\XIVLauncher\\pluginConfigs\\SomethingNeedDoing\\"
    type: string
  Characters file:
    default: "my_characters.txt"
    type: string
  Retainers file:
    default: "my_retainers.txt"
    type: string
  Blacklist file:
    default: "blacklist_retainers.txt"
    type: string
  Overrides file:
    default: "item_overrides.lua"
    type: string
config_folder = Config.Get("Config folder (inside of APPDATA)")
characters_file = Config.Get("Characters file")
retainers_file = Config.Get("Retainers file")
blacklist_file = Config.Get("Blacklist file")
overrides_file = Config.Get("Overrides file")
--]=====]
is_read_from_files = false
is_write_to_files = false
is_echo_during_read = false

is_multimode = Config.Get("Multimode enabled?")
start_wait = Config.Get("Start wait?")
after_multi = Config.Get("After multi")
is_autoretainer_while_waiting = Config.Get("Autoretainer while waiting?")
multimode_ending_command = Config.Get("Multimode ending command")
is_use_ar_to_enter_house = Config.Get("Use AR to enter house?")
is_autoretainer_compatibility = Config.Get("Autoretainer compatibility?")

function FileExists(name)
  local f=io.open(name,"r")
  if f~=nil then io.close(f) return true else return false end
end

function GetNodeText(addonName, ...)
  local node = Addons.GetAddon(addonName):GetNode(...)
  return tostring(node.Text)
end

-- WARNING!!! GetNodeText is no longer the same as it was in v1, any uses of GetNodeText without adjusting the node ID's to be the correct values will return the wrong text! GetNodeText used to return based on the ID's in the node list, but it has shifted to using the actual Node ID, similar to how GetNodeVisible was.
--  I am providing it as a function for ease of use, but just a heads up that every old GetNodeText call WILL RETURN NIL!


import("System.Numerics")

function Echo(text)
    yield("/echo " .. tostring(text))
end

function echo(text)
    Echo(text)
end

function IsNodeVisible(addonName, ...)
  if (Addons.GetAddon(addonName).Ready) then
    local node = Addons.GetAddon(addonName):GetNode(...)
    return node.IsVisible
  else
    return false
  end
end

function GetCharacterCondition(i, bool)
    return Svc.Condition[i] == bool
end

function IsInZone(i)
    return Svc.ClientState.TerritoryType == i
end

function GetTargetName()
  if (Entity.Target) then
    return Entity.Target.Name
  else
    return ""
  end
end

function GetDistanceToTarget()
  return Vector3.Distance(Svc.ClientState.LocalPlayer.Position, Svc.Targets.Target.Position)
end

ListItemRendererNodeIds = {4}
for n = 41001, 41021 do
    table.insert(ListItemRendererNodeIds, n)
end

function CountRetainers()
  if not Addons.GetAddon("RetainerList").Exists then SomethingBroke("RetainerList", "CountRetainers()") end
  while string.gsub(GetNodeText("RetainerList", 1, 27, 4, 2, 3),"%d","")=="" do
    yield("/wait 0.1")
  end
  yield("/wait 0.1")
  total_retainers = 0
  retainers_to_run = {}
  yield("/wait 0.1")
  for i = 1, 10 do
    nodeID = ListItemRendererNodeIds[i]
    yield("/wait 0.01")
    include_retainer = true
    retainer_name = GetNodeText("RetainerList", 1, 27, nodeID, 2, 3)
    if retainer_name~="" and retainer_name~=13 then
      if GetNodeText("RetainerList", 1, 27, nodeID, 2, 5)~="None" then
        if is_using_blacklist then
          for _, blacklist_test in pairs(blacklist_retainers) do
            if retainer_name==blacklist_test then
              include_retainer = false
              break
            end
          end
        end
      else
        include_retainer = false
      end
      if include_retainer then
        total_retainers = total_retainers + 1
        retainers_to_run[total_retainers] = i
      end
      if is_write_to_files and type(file_retainers)=="userdata" then
        is_add_to_file = true
        for _, known_retainer in pairs(my_retainers) do
          if retainer_name==known_retainer then
            is_add_to_file = false
            break
          end
        end
        if is_add_to_file then
          file_retainers = io.open(config_folder..retainers_file,"a")
          file_retainers:write("\n"..retainer_name)
          io.close(file_retainers)
        end
      end
    end
  end
  debugFunc("Retainers to run on this character: " .. total_retainers)
  return total_retainers
end

function OpenRetainer(r)
  r = r - 1
  if not Addons.GetAddon("RetainerList").Exists then SomethingBroke("RetainerList", "OpenRetainer("..r..")") end
  yield("/wait 0.3")
  --yield("/click RetainerList Retainers["..r.."].Select")
  SafeCallback("RetainerList", true, 2, r)
  yield("/wait 0.5")
  while Addons.GetAddon("SelectString").Exists==false do
    if Addons.GetAddon("Talk").Exists and Addons.GetAddon("Talk").Ready then 
      --yield("/click Talk Click")
      SafeCallback("Talk", true)
    end
    yield("/wait 0.1")
  end
  if not Addons.GetAddon("SelectString").Exists then SomethingBroke("SelectString", "OpenRetainer("..r..")") end
  yield("/wait 0.3")
  --yield("/click SelectString Entries[3].Select")
  SafeCallback("SelectString", true, 3)
  if not Addons.GetAddon("RetainerSellList").Exists then SomethingBroke("RetainerSellList", "OpenRetainer("..r..")") end
end

function CloseRetainer()
  while not Addons.GetAddon("RetainerList").Exists do
    SafeCallback("RetainerSellList", true, -1)
    SafeCallback("SelectString", true, -1)
    if Addons.GetAddon("Talk").Exists and Addons.GetAddon("Talk").Ready then
      --yield("/click Talk Click")
      SafeCallback("Talk", true)
    end
    yield("/wait 0.1")
  end
end

function CountItems()
  while Addons.GetAddon("RetainerSellList").Ready==false do yield("/wait 0.1") end
  while string.gsub(GetNodeText("RetainerSellList", 1, 14, 19),"%d","")=="" do
    yield("/wait 0.1")
  end
  count_wait_tick = 0
  while GetNodeText("RetainerSellList", 1, 14, 19)==raw_item_count and count_wait_tick < 5 do
    count_wait_tick = count_wait_tick + 1
    yield("/wait 0.1")
  end
  yield("/wait 0.1")
  raw_item_count = GetNodeText("RetainerSellList", 1, 14, 19)
  item_count_trimmed = string.sub(raw_item_count,1,2)
  item_count = string.gsub(item_count_trimmed,"%D","")
  debugFunc("Items for sale on this retainer: "..item_count)
  return tonumber(item_count)
end

function ClickItem(item)
  CloseSales()
  while Addons.GetAddon("RetainerSell").Exists==false do
    if Addons.GetAddon("ContextMenu").Ready then
      SafeCallback("ContextMenu", true, 0, 0)
      yield("/wait 0.2")
    elseif Addons.GetAddon("RetainerSellList").Exists then
      SafeCallback("RetainerSellList", true, 0, item - 1, 1)
    else
      SomethingBroke("RetainerSellList", "ClickItem()")
    end
    yield("/wait 0.05")
  end
end

function ReadOpenItem()
  last_item = open_item
  open_item = ""
  item_name_checks = 0
  while item_name_checks < name_rechecks and ( open_item == last_item or open_item == "" ) do
    item_name_checks = item_name_checks + 1
    yield("/wait 0.1")
    open_item = string.sub(string.gsub(GetNodeText("RetainerSell", 1, 5, 7), "%W", ""), 3, -3)
  end
  debugFunc("Last item: "..last_item)
  debugFunc("Open item: "..open_item)
end

function SearchResults()
  if Addons.GetAddon("ItemSearchResult").Exists==false then
    yield("/wait 0.1")
    if Addons.GetAddon("ItemSearchResult").Exists==false then
      SafeCallback("RetainerSell", true, 4)
    end
  end
  yield("/waitaddon ItemSearchResult")
  if Addons.GetAddon("ItemHistory").Exists==false then
    yield("/wait 0.1")
    if Addons.GetAddon("ItemHistory").Exists==false then
      SafeCallback("ItemSearchResult", true, 0)
    end
  end
  yield("/wait 0.1")
  ready = false
  search_hits = ""
  search_wait_tick = 10
  while ready==false do
    search_hits = GetNodeText("ItemSearchResult", 1, 29)
    first_price = string.gsub(GetNodeText("ItemSearchResult", 1, 26, 4, 5),"%D","")
    if search_wait_tick > 20 and string.find(GetNodeText("ItemSearchResult", 1, 5), "No items found.") then
      ready = true
      debugFunc("No items found.")
    end
    if (string.find(search_hits, "hit") and first_price~="") and (old_first_price~=first_price or search_wait_tick>20) then
      ready = true
      debugFunc("Ready!")
    else
      search_wait_tick = search_wait_tick + 1
      if (search_wait_tick > 50) or (string.find(GetNodeText("ItemSearchResult", 1, 5), "Please wait") and search_wait_tick > 10) then
        SafeCallback("RetainerSell", true, 4)
        yield("/wait 0.1")
        if Addons.GetAddon("ItemHistory").Exists==false then
          SafeCallback("ItemSearchResult", true, 0)
        end
        yield("/wait 0.1")
        search_wait_tick = 0
      end
    end
    yield("/wait 0.1")
  end
  old_first_price = first_price
  search_results = string.gsub(GetNodeText("ItemSearchResult", 1, 29),"%D","")
  debugFunc("Search results: "..search_results)
  return search_results
end

function SearchPrices()
  yield("/waitaddon ItemSearchResult")
  prices_list = {}
  prices_list_length = 0
  for i= 1, 10 do
    nodeID = ListItemRendererNodeIds[i]
    raw_price = GetNodeText("ItemSearchResult", 1, 26, nodeID, 5)
    if raw_price~="" and raw_price~=10 then
      trimmed_price = string.gsub(raw_price,"%D","")
      prices_list[i] = tonumber(trimmed_price)
    end
  end
  debugFunc(open_item.." Prices")
  for price_number, _ in pairs(prices_list) do
    debugFunc(prices_list[price_number])
    prices_list_length = prices_list_length + 1
  end
end

function SearchRetainers()
  search_retainers = {}
  for i= 1, 10 do
    nodeID = ListItemRendererNodeIds[i]
    market_search_retainer = GetNodeText("ItemSearchResult", 1, 26, nodeID, 10)
    if market_search_retainer~="" and market_search_retainer~=5 then
      search_retainers[i] = market_search_retainer
    end
  end
  if is_debug then
    debugFunc(open_item.." Retainers")
    for i = 1,10 do
      if search_retainers[i] then
        debugFunc(search_retainers[i])
      end
    end
  end
end

function HistoryAverage()
  print("Inside of History")
  while Addons.GetAddon("ItemHistory").Exists==false do
    SafeCallback("ItemSearchResult", true, 0)
    yield("/wait 0.3")
  end
  yield("/waitaddon ItemHistory")
  history_tm_count = 0
  history_tm_running = 0
  history_list = {}
  first_history = string.gsub(GetNodeText("ItemHistory", 1, 10, 4, 4),"%d","")
  print(first_history)
  while first_history=="" do
    yield("/wait 0.1")
    first_history = string.gsub(GetNodeText("ItemHistory", 1, 10, 4, 4),"%d","")
  end
  yield("/wait 0.1")
  for i= 2, 21 do
    nodeID = ListItemRendererNodeIds[i]
    raw_history_price = GetNodeText("ItemHistory", 1, 10, nodeID, 4)
    if raw_history_price ~= 6 and raw_history_price ~= "" then
      trimmed_history_price = string.gsub(raw_history_price,"%D","")
      history_list[i-1] = tonumber(trimmed_history_price)
      history_tm_count = history_tm_count + 1
    end
  end
  debugFunc("History items: "..history_tm_count)
  table.sort(history_list)
  for i=1, history_trim_amount do
    if history_tm_count > 2 then
      table.remove(history_list, history_tm_count)
      table.remove(history_list, 1)
      history_tm_count = history_tm_count - 2
    else
      break
    end
  end
  for history_tm_count, history_tm_price in pairs(history_list) do
    history_tm_running = history_tm_running + history_tm_price
  end
  history_trimmed_mean = history_tm_running // history_tm_count
  debugFunc("History trimmed mean:" .. history_trimmed_mean)
  return history_trimmed_mean
end

function ItemOverride(mode)
  if is_using_overrides then
    itemor = nil
    is_price_overridden = false
    for item_test, _ in pairs(item_overrides) do
      if open_item == string.gsub(item_test,"%W","") then
        itemor = item_overrides[item_test]
        break
      end
    end
    if not itemor then return false end
    if itemor.default and mode == "default" then
      price = tonumber(itemor.default)
      is_price_overridden = true
      debugFunc(open_item.." default price: "..itemor.default.." applied!")
    end
    if itemor.minimum then
      if price < itemor.minimum then
        price = tonumber(itemor.minimum)
        is_price_overridden = true
        debugFunc(open_item.." minimum price: "..itemor.minimum.." applied!")
      end
    end
    if itemor.maximum then
      if price > itemor.maximum then
        price = tonumber(itemor.maximum)
        is_price_overridden = true
        debugFunc(open_item.." maximum price: "..itemor.maximum.." applied!")
      end
    end
  end
end

function SetPrice(price)
  debugFunc("Setting price to: "..price)
  CloseSearch()
  SafeCallback("RetainerSell", true, 2, price)
  SafeCallback("RetainerSell", true, 0)
  CloseSales()
end

function CloseSearch()
  while Addons.GetAddon("ItemSearchResult").Exists or Addons.GetAddon("ItemHistory").Exists do
    yield("/wait 0.1")
    if Addons.GetAddon("ItemSearchResult").Exists then SafeCallback("ItemSearchResult", true, -1) end
    if Addons.GetAddon("ItemHistory").Exists then SafeCallback("ItemHistory", true, -1) end
  end
end

function CloseSales()
  CloseSearch()
  while Addons.GetAddon("RetainerSell").Exists do
    yield("/wait 0.1")
    if Addons.GetAddon("RetainerSell").Exists then SafeCallback("RetainerSell", true, -1) end
  end
end

function SomethingBroke(what_should_be_visible, extra_info)
  for broken_rechecks=1, 20 do
    if Addons.GetAddon(what_should_be_visible).Exists then
      still_broken = false
      break
    else
      yield("/wait 0.1")
    end
  end
  if still_broken then
    yield("/echo It looks like something has gone wrong.")
    if what_should_be_visible then yield("/echo "..what_should_be_visible.." should be visible, but it isn't.") end
    yield("/echo Attempting to fix this, please wait.")
    if extra_info then yield("/echo "..extra_info) end
    --yield("")
    yield("/echo On second thought, I haven't finished this yet.")
    yield("/echo Oops!")
    yield("/pcraft stop")
  end
end

function NextCharacter()
  current_character = Player.Entity.Name.."@"..Excel.GetRow("World", Player.Entity.HomeWorld).Name
  next_character = nil
  debugFunc("Current character: "..current_character)
  for character_number, character_name in pairs(my_characters) do
    if character_name == current_character then
      next_character = my_characters[character_number+1]
      break
    end
  end
  return next_character
end

function Relog(relog_character)
  echo(relog_character)
  yield("/ays relog " .. relog_character)
  while GetCharacterCondition(1, true) do
    yield("/wait 1.01")
  end
  while GetCharacterCondition(1, false) do
    yield("/wait 1.02")
  end
  while GetCharacterCondition(45, true) or GetCharacterCondition(35, true) do
    yield("/wait 1.03")
  end
  yield("/wait 0.5")
  while GetCharacterCondition(35, true) do
    yield("/wait 1.04")
  end
  yield("/wait 2")
end

function EnterHouse()
  if IsInZone(339) or IsInZone(340) or IsInZone(341) or IsInZone(641) or IsInZone(979) or IsInZone(136) then
    debugFunc("Entering house")
    if is_use_ar_to_enter_house then
      yield("/ays het")
    else
      yield("/target Entrance")
      yield("/target Apartment Building Entrance")
    end
    yield("/wait 1")
    if string.find(string.lower(GetTargetName()), "entrance") then
      while IsInZone(339) or IsInZone(340) or IsInZone(341) or IsInZone(641) or IsInZone(979) or IsInZone(136) do
        if not is_use_ar_to_enter_house then
          yield("/lockon on")
          yield("/automove on")
        end
        yield("/wait 1.2")
      end
      het_tick = 0
      while het_tick < 3 do
        if IsPlayerOccupied() then het_tick = 0
        elseif IsMoving() then het_tick = 0
        else het_tick = het_tick + 0.2
        end
        yield("/wait 0.200")
      end
    else
      debugFunc("Not entering house?")
    end
  end
end

function OpenBell()
  EnterHouse()
  target_tick = 1
  while GetCharacterCondition(50, false) do
    if target_tick > 99 then
      break
    elseif string.lower(GetTargetName())~="summoning bell" then
      debugFunc("Finding summoning bell...")
      yield("/target Summoning Bell")
      target_tick = target_tick + 1
    elseif GetDistanceToTarget()<20 then
      yield("/lockon on")
      yield("/automove on")
      yield("/pinteract")
    else
      yield("/automove off")
      yield("/pinteract")
    end
    yield("/lockon on")
    yield("/wait 0.511")
  end
  if GetCharacterCondition(50, true) then
    yield("/lockon off")
    while not Addons.GetAddon("RetainerList").Exists do yield("/wait 0.100") end
    yield("/wait 0.4")
    return true
  else
    return false
  end
end

function WaitARFinish(ar_time)
  title_wait = 0
  if not ar_time then ar_time = 10 end
  while Addons.GetAddon("_TitleMenu").Exists==false do
    yield("/wait 5.01")
  end
  while true do
    if Addons.GetAddon("_TitleMenu").Exists and Addons.GetAddon("NowLoading").Exists==false then
      title_wait = title_wait + 1
    else
      title_wait = 0
    end
    if title_wait > ar_time then
      break
    end
    yield("/wait 1.0"..ar_time - title_wait)
  end
end

function echo(input)
  if is_verbose then
    yield("/echo [MarketBotty] "..input)
  else
    yield("/wait 0.01")
  end
end

function debugFunc(debug_input)
  if is_debug then
    yield("/echo [MarketBotty][DEBUG] "..debug_input)
  else
    yield("/wait 0.01")
  end
end

function SafeCallback(...)  -- Could be safer, but this is a good start, right?
  local callback_table = table.pack(...)
  local addon = nil
  local update = nil
  if type(callback_table[1])=="string" then
    addon = callback_table[1]
    table.remove(callback_table, 1)
  end
  if type(callback_table[1])=="boolean" then
    update = tostring(callback_table[1])
    table.remove(callback_table, 1)
  elseif type(callback_table[1])=="string" then
    if string.find(callback_table[1], "t") then
      update = "true"
    elseif string.find(callback_table[1], "f") then
      update = "false"
    end
    table.remove(callback_table, 1)
  end

  local call_command = "/pcall " .. addon .. " " .. update
  for _, value in pairs(callback_table) do
    if type(value)=="number" then
      call_command = call_command .. " " .. tostring(value)
    end
  end
  if Addons.GetAddon(addon).Ready and Addons.GetAddon(addon).Exists then
    yield(call_command)
  end
end

function Clear()
  next_retainer = 0
  prices_list = {}
  item_list = {}
  item_count = 0
  search_retainers = {}
  last_item = ""
  open_item = ""
  is_single_retainer_mode = false
  undercut = 1
  target_sale_slot = 1
end

------------------------------------------------------------------------------------------------------

-- Tried to do this as functions, but it was too hard. Oh well.
if is_read_from_files then
  config_folder = os.getenv("APPDATA") .. config_folder
  -- Characters file
  local file_characters_path = config_folder..characters_file
  if FileExists(file_characters_path) and is_multimode then
    my_characters = {}
    local file_characters_handle = io.open(file_characters_path, "r")
    if file_characters_handle then
      local next_line = file_characters_handle:read("l")
      local i = 0
      while next_line do
        i = i + 1
        my_characters[i] = next_line
        if is_echo_during_read then debugFunc("Character "..i.." from file: "..next_line) end
        next_line = file_characters_handle:read("l")
      end
      file_characters_handle:close()
      echo("Characters loaded from file: "..i)
      if i <= 1 then
        is_multimode = false
      end
    else
      echo(file_characters_path.." could not be opened!")
    end
  else
    echo(file_characters_path.." not found!")
  end

  -- Retainers file
  local file_retainers_path = config_folder..retainers_file
  if FileExists(file_retainers_path) and is_dont_undercut_my_retainers then
    my_retainers = {}
    local file_retainers_handle = io.open(file_retainers_path, "r")
    if file_retainers_handle then
      local next_line = file_retainers_handle:read("l")
      local i = 0
      while next_line do
        i = i + 1
        my_retainers[i] = next_line
        if is_echo_during_read then debugFunc("Retainer "..i.." from file: "..next_line) end
        next_line = file_retainers_handle:read("l")
      end
      file_retainers_handle:close()
      echo("Retainers loaded from file: "..i)
    else
      echo(file_retainers_path.." could not be opened!")
    end
  else
    echo(file_retainers_path.." not found!")
  end

  -- Blacklist file
  local file_blacklist_path = config_folder..blacklist_file
  if FileExists(file_blacklist_path) and is_using_blacklist then
    blacklist_retainers = {}
    local file_blacklist_handle = io.open(file_blacklist_path, "r")
    if file_blacklist_handle then
      local next_line = file_blacklist_handle:read("l")
      local i = 0
      while next_line do
        i = i + 1
        blacklist_retainers[i] = next_line
        if is_echo_during_read then debugFunc("Blacklist "..i.." from file: "..next_line) end
        next_line = file_blacklist_handle:read("l")
      end
      file_blacklist_handle:close()
      echo("Blacklist loaded from file: "..i)
    else
      echo(file_blacklist_path.." could not be opened!")
    end
  else
    echo(file_blacklist_path.." not found!")
  end

  -- Overrides file
  local file_overrides_path = config_folder..overrides_file
  if FileExists(file_overrides_path) and is_using_overrides then
    item_overrides = {}
    local chunk = loadfile(file_overrides_path)
    if chunk then
      chunk()
      local or_count = 0
      for _, i in pairs(item_overrides) do or_count = or_count + 1 end
      echo("Overrides loaded from file: "..or_count)
    else
      echo(file_overrides_path.." could not be loaded!")
    end
  else
    echo(file_overrides_path.." not found!")
  end
end


uc=1
au=1
if is_override_report then
  override_items_count = 0
  override_report = {}
end
if is_postrun_one_gil_report then
  one_gil_items_count = 0
  one_gil_report = {}
end
if is_postrun_sanity_report then
  sanity_items_count = 0
  sanity_report = {}
end

if Addons.GetAddon("RetainerList").Exists then is_multimode = false end

::MultiWait::
if start_wait and is_autoretainer_while_waiting then
    WaitARFinish()
    yield("/ays multi d")
end
after_multi = tostring(after_multi)
if string.find(after_multi, "wait logout") then
elseif string.find(after_multi, "wait") then
  multi_wait = string.gsub(after_multi,"%D","") * 60
  wait_until = os.time() + multi_wait
end

if is_write_to_files then
  is_add_to_file = true
  current_character = Player.Entity.Name.."@"..Excel.GetRow("World", Player.Entity.HomeWorld).Name
  for _, character_name in pairs(my_characters) do
    if character_name == current_character then
      is_add_to_file = false
      break
    end
  end
  if is_add_to_file and current_character~="null" then
    file_characters = io.open(config_folder..characters_file,"a")
    file_characters:write("\n"..current_character)
    io.close(file_characters)
  end
end

::Startup::
Clear()
if GetCharacterCondition(1, false) then
  echo("Not logged in?")
  yield("/wait 1")
  Relog(my_characters[1])
  goto Startup
elseif GetCharacterCondition(50, false) then
  echo("Not at a summoning bell.")
  OpenBell()
  goto Startup
elseif Addons.GetAddon("RecommendList").Exists then
  helper_mode = true
  while Addons.GetAddon("RecommendList").Exists do
    SafeCallback("RecommendList", true, -1)
    yield("/wait 0.1")
  end
  echo("Starting in helper mode!")
  goto Helper
elseif Addons.GetAddon("RetainerList").Exists then
  CountRetainers()
  goto NextRetainer
elseif Addons.GetAddon("RetainerSell").Exists then
  echo("Starting in single item mode!")
  is_single_item_mode = true
  goto RepeatItem
elseif Addons.GetAddon("SelectString").Exists then
  echo("Starting in single retainer mode!")
  --yield("/click SelectString Entries[2].Select")
  SafeCallback("SelectString", true, 2)
  yield("/waitaddon RetainerSellList")
  is_single_retainer_mode = true
  goto Sales
elseif Addons.GetAddon("RetainerSellList").Exists then
  echo("Starting in single retainer mode!")
  is_single_retainer_mode = true
  goto Sales
else
  echo("Unexpected starting conditions!")
  echo("You broke it. It's your fault.")
  echo("Do not message me asking for help.")
  yield("/pcraft stop")
end

------------------------------------------------------------------------------------------------------

::NextRetainer::
if next_retainer < total_retainers then
  next_retainer = next_retainer + 1
else
  goto MultiMode
end
yield("/wait 0.1")
target_sale_slot = 1
OpenRetainer(retainers_to_run[next_retainer])

::Sales::
if CountItems() == 0 then goto Loop end

::NextItem::
ClickItem(target_sale_slot)

::Helper::
au = uc
while Addons.GetAddon("RetainerSell").Exists==false do
  yield("/wait 0.5")
  if GetCharacterCondition(50, false) or Addons.GetAddon("RecommendList").Exists then
    goto EndOfScript
  end
end

::RepeatItem::
ReadOpenItem()
if last_item~="" then
  if open_item == last_item then
    debugFunc("Repeat: "..open_item.." set to "..price)
    goto Apply
  end
end

::ReadPrices::
SearchResults()
current_price = string.gsub(GetNodeText("RetainerSell", 1, 17, 19),"%D","")
if (string.find(GetNodeText("ItemSearchResult", 1, 5), "No items found.")) then
  if type(history_multiplier)=="number" then
    price = HistoryAverage() * history_multiplier
    price_length = string.len(tostring(price))
    if price_length >= 5 then
      exp = 10 ^ math.ceil(price_length * 0.6)
      price = math.tointeger(math.floor(price // exp) * exp)
    end
  else
    price_length = string.len(tostring(HistoryAverage()))
    price = math.tointeger(10 ^ price_length)
  end
  CloseSearch()
  ItemOverride("default")
  goto Apply
end
target_price = 1
SearchPrices()
SearchRetainers()
HistoryAverage()
CloseSearch()


if is_check_for_hq then
  hq = GetNodeText("RetainerSell",1, 5, 7)
  hq = string.gsub(hq,"%g","")
  hq = string.gsub(hq,"%s","")
  if string.len(hq)==3 then
    is_hq = true
    debugFunc("High quality!")
  else
    is_hq = false
    debugFunc("Normal quality.")
  end
end

::PricingLogic::
if is_price_sanity_checking and target_price < prices_list_length then
  if prices_list[target_price] == 1 then
    target_price = target_price + 1
    goto PricingLogic
  end
  if prices_list[target_price] <= (history_trimmed_mean // 2) then
    target_price = target_price + 1
    goto PricingLogic
  end
  debugFunc("Price sanity checking results:")
  debugFunc("target_price "..target_price)
  debugFunc("prices_list[target_price] "..prices_list[target_price])
end
if is_check_for_hq and is_hq and target_price < prices_list_length then
  debugFunc("Checking listing "..target_price.." for HQ...")
  if target_price==1 then
    node_hq = 4
  else
    node_hq = target_price + 40999
  end
  --if not IsNodeVisible("ItemSearchResult", 5, target_price, 13) then
  if not IsNodeVisible("ItemSearchResult", 1, 26, node_hq, 2, 3) then
    debugFunc(target_price.." not HQ")
    target_price = target_price + 1
    goto PricingLogic
  end
end
if is_dont_undercut_my_retainers then
  for _, retainer_test in pairs(my_retainers) do
    if retainer_test == search_retainers[target_price] then
      au = 0
      debugFunc("Matching price with own retainer: "..retainer_test)
      break
    end
  end
end
price = prices_list[target_price] - au
ItemOverride()
if is_override_report and is_price_overridden then
  override_items_count = override_items_count + 1
  if is_multimode then
    override_report[override_items_count] = open_item.." on "..Player.Entity.Name.." set: "..price..". Low: "..prices_list[1]
  else
    override_report[override_items_count] = open_item.." set: "..price..". Low: "..prices_list[1]
  end
elseif price <= 1 then
  echo("Should probably vendor this crap instead of setting it to 1. Since this script isn't *that* good yet, I'm just going to set it to...69. That's a nice number. You can deal with it yourself.")
  price = 69
  if is_postrun_one_gil_report then
    one_gil_items_count = one_gil_items_count + 1
    if is_multimode then
      one_gil_report[one_gil_items_count] = open_item.." on "..Player.Entity.Name
    else
      one_gil_report[one_gil_items_count] = open_item
    end
  end
elseif is_postrun_sanity_report and target_price ~= 1 then
  sanity_items_count = sanity_items_count + 1
  if is_multimode then
    sanity_report[sanity_items_count] = open_item.." on "..Player.Entity.Name.." set: "..price..". Low: "..prices_list[1]
  else
    sanity_report[sanity_items_count] = open_item.." set: "..price..". Low: "..prices_list[1]
  end
end

::Apply::
if price ~= tonumber(string.gsub(GetNodeText("RetainerSell", 1, 17, 19),"%D","")) then
  SetPrice(price)
end
CloseSales()

::Loop::
if helper_mode then
  yield("/wait 1")
  goto Helper
elseif is_single_item_mode then
  yield("/pcraft stop")
elseif not (tonumber(item_count) <= target_sale_slot) then
  target_sale_slot = target_sale_slot + 1
  goto NextItem
elseif is_single_retainer_mode then
  goto EndOfScript
elseif is_single_retainer_mode==false then
  CloseRetainer()
  goto NextRetainer
end

::MultiMode::
if is_multimode then
  while Addons.GetAddon("RetainerList").Exists do
    SafeCallback("RetainerList", true, -1)
    yield("/wait 1")
  end
  NextCharacter()
  if not next_character then goto AfterMulti end
  Relog(next_character)
  if OpenBell()==false then goto MultiMode end
  goto Startup
else
  goto EndOfScript
end

::AfterMulti::
yield("/wait 3")
if string.find(after_multi, "logout") then
  yield("/logout")
  yield("/waitaddon SelectYesno")
  yield("/wait 0.5")
  SafeCallback("SelectYesno", true, 0)
  while GetCharacterCondition(1, true) do
    yield("/wait 1.1")
  end
elseif wait_until then
  if is_autoretainer_while_waiting then
    yield("/ays multi e")
    while GetCharacterCondition(1, false) do
      yield("/wait 10.1")
    end
  end
  while os.time() < wait_until do
    yield("/wait 12")
  end
  if is_autoretainer_while_waiting then
    WaitARFinish()
    yield("/ays multi d")
  end
  goto MultiWait
elseif type(after_multi) == "number" then
  Relog(my_characters[after_multi])
end

if string.find(after_multi, "wait logout") then
  if is_autoretainer_while_waiting then
    yield("/ays multi e")
    while GetCharacterCondition(1, false) do
      yield("/wait 10.2")
    end
  end
  WaitARFinish()
  if is_autoretainer_while_waiting then yield("/ays multi d") end
  goto MultiWait
end

if GetCharacterCondition(50, false) and multimode_ending_command then
  yield("/wait 3")
  yield(multimode_ending_command)
end

::EndOfScript::
while Addons.GetAddon("RecommendList").Exists do
  SafeCallback("RecommendList", true, -1)
  yield("/wait 0.1")
end
echo("---------------------")
echo("MarketBotty finished!")
echo("---------------------")
if is_override_report and override_items_count ~= 0 then
  echo("Items that triggered override: "..override_items_count)
  for i = 1, override_items_count do
    echo(override_report[i])
  end
  echo("---------------------")
end
if is_postrun_one_gil_report and one_gil_items_count ~= 0 then
  echo("Items that triggered 1 gil check: "..one_gil_items_count)
  for i = 1, one_gil_items_count do
    echo(one_gil_report[i])
  end
  echo("---------------------")
end
if is_postrun_sanity_report and sanity_items_count ~= 0 then
  echo("Items that triggered sanity check: "..sanity_items_count)
  for i = 1, sanity_items_count do
    echo(sanity_report[i])
  end
  echo("---------------------")
end
