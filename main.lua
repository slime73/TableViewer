TableViewer = {}
TableViewer.treetable = {}
TableViewer.ui = {}
TableViewer.searchmatches = {}
TableViewer.searchtext = ""
TableViewer.currenttable = ""


local function tostring2(x, s)
	local y = tostring(x)
	if type(x) == "userdata" then
		local subtype = string.sub(y, 1, 6)
		if subtype == "gvecto" then
			return string.format("Vector (%0.0f, %0.0f, %0.0f)", x:x(), x:y(), x:z())
		elseif subtype == "quater" then
			return string.format("Quat (%0.3f, %0.3f, %0.3f,%0.3f)", x:w(), x:x(), x:y(), x:z())
		end
	elseif type(x) == "string" then
		return s and string.format("%s", x) or string.format("%q", x)
	end
	return y
end

function TableViewer.ConvertTable(tbl_string)
	TableViewer.currenttable = tbl_string or ""
	local tbl = assert(loadstring("return "..tbl_string)())
	if not type(tbl) or type(tbl) ~= "table" then return end
	TableViewer.treetable = {}
	TableViewer.searchmatches = {}
	
	local function recurse(intable, insert_table)
		local keys = {}
		for k in pairs(intable) do table.insert(keys, k) end
		table.sort(keys, function(a,b) return gkmisc.strnatcasecmp(a,b) < 0 end)
		for _,v in ipairs(keys) do
			if type(intable[v]) == "table" then
				table.insert(insert_table, {branchname="(table) "..tostring(v)})
				recurse(intable[v], insert_table[#insert_table])
			else
				local val = intable[v]
				local str = tostring2(v, true)..": "..tostring2(val)
				table.insert(insert_table, str)
			end
		end
	end
	recurse(tbl, TableViewer.treetable)
	TableViewer.treetable.branchname = tbl_string
end

local function recursive_expand(i)
	if i < 1 then return end
	local parent = TableViewer.ui.tree["parent"..i]
	if not parent or tonumber(parent) < 1 then return end
	TableViewer.ui.tree["state"..parent] = "EXPANDED"
	recursive_expand(tonumber(parent))
end
function TableViewer.SelectItem(i)
	TableViewer.ui.tree.value = i
	recursive_expand(i)
end

function TableViewer.SearchTable(search)
	if not search or search == "" then return end
	TableViewer.searchtext = search
	TableViewer.searchmatches = {}
	local currentvalue = tonumber(TableViewer.ui.tree.value)
	local match = false
	for i=1, math.huge do
		local v = TableViewer.ui.tree["name"..i]
		if not v then break end
		local goodname = tostring(v):lower()
		goodname = goodname:gsub("^%(table%) ", "")
		goodname = goodname:gsub("userdata: (%w+)$", "")
		goodname = goodname:gsub("function: (%w+)$", "")
		goodname = goodname:gsub("table: (%w+)$", "")
		if goodname:match(search:lower()) then
			table.insert(TableViewer.searchmatches, i)
			match = v == search and i
		end
	end
	if #TableViewer.searchmatches < 1 then return "No match found" end
	table.sort(TableViewer.searchmatches, function(a,b) return gkmisc.strnatcasecmp(a,b) < 0 end)
	if match then
		TableViewer.SelectItem(match)
	else
		local foundgreater = false
		for i,v in ipairs(TableViewer.searchmatches) do
			if v == currentvalue then
				break
			elseif v > currentvalue then
				TableViewer.SelectItem(v)
				foundgreater = true
				break
			end
		end
		if not foundgreater then TableViewer.ui.tree.value = TableViewer.searchmatches[1] end
	end
end

function TableViewer.FindNext()
	local currentvalue = tonumber(TableViewer.ui.tree.value)
	if (not TableViewer.searchmatches[1]) or TableViewer.ui.searchtext.value ~= TableViewer.searchtext then
		TableViewer.SearchTable(TableViewer.ui.searchtext.value)
		return
	end
	local foundgreater = false
	for i,v in ipairs(TableViewer.searchmatches) do
		if v > currentvalue then
			TableViewer.SelectItem(v)
			foundgreater = true
			break
		end
	end
	if not foundgreater then TableViewer.ui.tree.value = TableViewer.searchmatches[1] end
end

function TableViewer.FindPrev()
	local currentvalue = tonumber(TableViewer.ui.tree.value)
	if not TableViewer.searchmatches[1]  or TableViewer.ui.searchtext.value ~= TableViewer.searchtext then
		TableViewer.SearchTable(TableViewer.ui.searchtext.value)
		return
	end
	local foundlesser = false
	for i = #TableViewer.searchmatches, 1, -1 do
		local v = TableViewer.searchmatches[i]
		if v < currentvalue then
			TableViewer.SelectItem(v)
			foundlesser = true
			break
		end
	end
	if not foundlesser then TableViewer.ui.tree.value = TableViewer.searchmatches[#TableViewer.searchmatches] end
end

TableViewer.ui.searchtext = iup.text{font=Font.H5, expand="HORIZONTAL", action=function(self, k, v)
	if k == 13 and v ~= "" then TableViewer.ui.searchtable:action() end
end}
TableViewer.ui.searchtable = iup.stationbutton{title="Go", size=80, font=Font.H5, action=function(self)
	TableViewer.SearchTable(TableViewer.ui.searchtext.value)
end}
TableViewer.ui.findnext = iup.stationbutton{title="Find Next", font=Font.H5, action=TableViewer.FindNext}
TableViewer.ui.findprev = iup.stationbutton{title="Find Prev", font=Font.H5, action=TableViewer.FindPrev}
TableViewer.ui.close = iup.stationbutton{title="Close", expand="HORIZONTAL"}
TableViewer.ui.textbox = iup.text{expand="HORIZONTAL", action=function(self, k, v)
	if k == 13 and v ~= "" then TableViewer.ui.search:action() end
end}
TableViewer.ui.search = iup.stationbutton{title="Go", size=120, action=function(self)
	local tbl = TableViewer.ui.textbox.value
	if tbl == "" then return end
	TableViewer.ui.tree.value = "ROOT"
	TableViewer.ui.tree.delnode = "CHILDREN"
	TableViewer.ConvertTable(tbl)
	iup.TreeSetValue(TableViewer.ui.tree, TableViewer.treetable)
	TableViewer.ui.tree.redraw = "YES"
	TableViewer.ui.textbox.value = ""
end}

TableViewer.ui.tree = iup.stationsubsubtree{expand="YES", addexpanded="NO", renamenode_cb=function(self, id, name)
    if self['KIND'..id] == "BRANCH" then
    	local state = self['STATE'..id]
    	if state == "EXPANDED" then
			self:setstate(id, "COLLAPSED")
    	else
    		self:setstate(id, "EXPANDED")
    	end
    end
end}


TableViewer.ui.main = iup.pdarootframe{
	iup.pdarootframebg{
		iup.vbox{
			iup.hbox{
				iup.label{title="Enter A Table:"},
				TableViewer.ui.textbox,
				TableViewer.ui.search,
				gap=5, alignment="ACENTER",
			},
			iup.hbox{
				iup.label{title="Search In Table:", font=Font.H5},
				TableViewer.ui.searchtext,
				TableViewer.ui.searchtable,
				TableViewer.ui.findprev,
				TableViewer.ui.findnext,
				gap=5, alignment="ACENTER",
			},
			TableViewer.ui.tree,
			TableViewer.ui.close,
			gap=5,
		},
	},
	size="TWOTHIRDxTWOTHIRD", expand="NO",
}

TableViewer.ui.dlg = iup.dialog{
	iup.vbox{
		iup.fill{},
		iup.hbox{
			iup.fill{},
			TableViewer.ui.main,
			iup.fill{},
		},
		iup.fill{},
	},
	defaultesc=TableViewer.ui.close,
	bgcolor="0 0 0 128 *",
	fullscreen="YES",
	border="NO",
	resize="NO",
    menubox="NO",
    topmost="YES",
}
TableViewer.ui.dlg:map()


function TableViewer.ui.Open()
	ShowDialog(TableViewer.ui.dlg)
	if TableViewer.currenttable ~= "" then
		TableViewer.ui.tree.value = "ROOT"
		TableViewer.ui.tree.delnode = "CHILDREN"
		TableViewer.ConvertTable(TableViewer.currenttable)
		iup.TreeSetValue(TableViewer.ui.tree, TableViewer.treetable)
		TableViewer.ui.tree.redraw = "YES"
		TableViewer.ui.textbox.value = ""
	end
end
function TableViewer.ui.Close()
	HideDialog(TableViewer.ui.dlg)
end
TableViewer.ui.close.action = TableViewer.ui.Close

function TableViewer.cmd(_, data)
	if not data then TableViewer.ui.Open() return end
	local tbl = assert(loadstring("return "..data[1])())
	if not type(tbl) or type(tbl) ~= "table" then
		purchaseprint("TableViewer error: not a valid table!")
		return
	end
	TableViewer.currenttable = data[1] or ""
	TableViewer.ui.Open()
end


RegisterUserCommand("table", TableViewer.cmd)