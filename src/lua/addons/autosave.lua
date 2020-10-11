-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local Stat = wg.stat

local function announce()
	local settings = DocumentSet.addons.autosave

	if settings.enabled then
		NonmodalMessage("Autosave is enabled. Next save in "..settings.period..
			" minute"..Pluralise(settings.period, "", "s")..
			".")
	else
		NonmodalMessage("Autosave is disabled.")
	end	
end

local function makefilename(dirname, pattern)
	local leafname = Leafname(DocumentSet.name)
	dirname = dirname or Dirname(DocumentSet.name)
	leafname = leafname:gsub("%.wg$", "")
	leafname = leafname:gsub("%%", "%%%%")
	
	local timestamp = os.date("%Y-%m-%d.%H%M")
	timestamp = timestamp:gsub("%%", "%%%%")
	
	pattern = pattern:gsub("%%[fF]", leafname)
	pattern = pattern:gsub("%%[tT]", timestamp)
	pattern = pattern:gsub("%%%%", "%%")
	return dirname.."/"..pattern
end

-----------------------------------------------------------------------------
-- Idle handler. This actually does the work of autosaving.

do
	local function cb()
		local settings = DocumentSet.addons.autosave
		if not settings.enabled or not DocumentSet.changed then
			return
		end
		
		if not settings.lastsaved then
			settings.lastsaved = os.time()
		end
		
		if ((os.time() - settings.lastsaved) > (settings.period * 60)) then
			ImmediateMessage("Autosaving...")
			
			local filename = makefilename(settings.directory, settings.pattern)
			local r, e = SaveDocumentSetRaw(filename)
			
			if not r then
				ModalMessage("Autosave failed", "The document could not be autosaved: "..e)
			else
				NonmodalMessage("Autosaved as "..filename) 
				QueueRedraw()
			end
			
			settings.lastsaved = os.time()
		end
	end
	
	AddEventListener(Event.Idle, cb)
end

-----------------------------------------------------------------------------
-- Load document. Nukes the 'last autosave' field 

do
	local function cb()
		DocumentSet.addons.autosave = DocumentSet.addons.autosave or {}
		DocumentSet.addons.autosave.lastsaved = nil
		announce()
	end
	
	AddEventListener(Event.DocumentLoaded, cb)
end

-----------------------------------------------------------------------------
-- Addon registration. Create the default settings in the DocumentSet.

do
	local function cb()
		DocumentSet.addons.autosave = DocumentSet.addons.autosave or {
			enabled = false,
			period = 10,
			pattern = "%F.autosave.%T.wg",
			directory = nil,
		}
	end
	
	AddEventListener(Event.RegisterAddons, cb)
end

-----------------------------------------------------------------------------
-- Configuration user interface.

function Cmd.ConfigureAutosave()
	local settings = DocumentSet.addons.autosave

	if not DocumentSet.name then
		ModalMessage("Autosave not available", "You cannot use autosave "..
			"until you have manually saved your document at least once, "..
			"so that Autosave knows what base filename to use.")
		return false
	end
		
	local enabled_checkbox =
		Form.Checkbox {
			x1 = 1, y1 = 1,
			x2 = 33, y2 = 1,
			label = "Enable autosaving",
			value = settings.enabled
		}

	local period_textfield =
		Form.TextField {
			x1 = 33, y1 = 3,
			x2 = 43, y2 = 3,
			value = tostring(settings.period)
		}
		
	local example_label =
		Form.Label {
			x1 = 1, y1 = 10,
			x2 = -1, y2 = 10,
			value = ""
		}
		
	local pattern_textfield
	local directory_textfield
	local function update_example()
		local d = directory_textfield.value
		if (d == "") then
			d = nil
		end
		local f = makefilename(d, pattern_textfield.value)
		if (#f > example_label.realwidth) then
			example_label.value = "..."..f:sub(-(example_label.realwidth-3))
		else
			example_label.value = f
		end
		example_label:draw()
	end

	pattern_textfield =
		Form.TextField {
			x1 = 33, y1 = 5,
			x2 = -1, y2 = 5,
			value = settings.pattern,
			
			draw = function(self)
				self.class.draw(self)
				update_example()
			end
		}
	
	directory_textfield =
		Form.TextField {
			x1 = 33, y1 = 7,
			x2 = -1, y2 = 7,
			value = settings.directory or "",
			
			draw = function(self)
				self.class.draw(self)
				update_example()
			end
		}

	local dialogue =
	{
		title = "Configure Autosave",
		width = Form.Large,
		height = 12,
		stretchy = false,

		["KEY_^C"] = "cancel",
		["KEY_RETURN"] = "confirm",
		["KEY_ENTER"] = "confirm",
		
		enabled_checkbox,
		
		Form.Label {
			x1 = 1, y1 = 3,
			x2 = 32, y2 = 3,
			align = Form.Left,
			value = "Period between saves (minutes):"
		},
		period_textfield,
		
		Form.Label {
			x1 = 1, y1 = 5,
			x2 = 32, y2 = 5,
			align = Form.Left,
			value = "Autosave filename pattern:"
		},
		pattern_textfield,
		
		Form.Label {
			x1 = 1, y1 = 7,
			x2 = 32, y2 = 7,
			align = Form.Left,
			value = "Autosave directory:"
		},
		Form.Label {
			x1 = 1, y1 = 8,
			x2 = 32, y2 = 8,
			align = Form.Left,
			value = "(Leave empty for default)"
		},
		directory_textfield,

		example_label,
	}
	
	while true do
		local result = Form.Run(dialogue, RedrawScreen,
			"SPACE to toggle, RETURN to confirm, CTRL+C to cancel")
		if not result then
			return false
		end
		
		local enabled = enabled_checkbox.value
		local period = tonumber(period_textfield.value)
		local pattern = pattern_textfield.value
		local directory = directory_textfield.value
		
		local dstat = nil
		if directory == "" then
			directory = nil
		end
		if directory then
			dstat = Stat(directory)
		end

		if not period then
			ModalMessage("Parameter error", "The period field must be a valid number.")
		elseif (pattern:len() == 0) then
			ModalMessage("Parameter error", "The filename pattern cannot be empty.")
		elseif pattern:find("%%[^%%ftFT]") then
			ModalMessage("Parameter error", "The filename pattern can only contain "..
				"%%, %F or %T fields.")
		elseif directory and (not dstat or (dstat.mode ~= "directory")) then
			ModalMessage("Parameter error", "The autosave directory is not accessible.")
		else
			settings.enabled = enabled
			settings.period = period
			settings.pattern = pattern
			settings.lastsaved = nil
			settings.directory = directory
			DocumentSet:touch()

			announce()			
			return true
		end
	end
		
	return false
end
