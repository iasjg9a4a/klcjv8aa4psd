local httpService = game:GetService('HttpService')

local SaveManager = {} do
	SaveManager.Folder = 'HorizonSettings'
	SaveManager.Ignore = {}
	SaveManager.Parser = {
		Toggle = {
			Save = function(idx, object) 
				return { type = 'Toggle', idx = idx, value = object.Value } 
			end,
			Load = function(idx, data)
				if Toggles[idx] then
					if data.value == false and not Toggles[idx].Value then return end
					Toggles[idx]:SetValue(data.value)
				end
			end,
		},
		Slider = {
			Save = function(idx, object)
				return { type = 'Slider', idx = idx, value = tostring(object.Value) }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValue(data.value)
				end
			end,
		},
		Dropdown = {
			Save = function(idx, object)
				return { type = 'Dropdown', idx = idx, value = object.Value, mutli = object.Multi }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValue(data.value)
				end
			end,
		},
		ColorPicker = {
			Save = function(idx, object)
				return { type = 'ColorPicker', idx = idx, value = object.Value:ToHex(), transparency = object.Transparency }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency)
				end
			end,
		},
		KeyPicker = {
			Save = function(idx, object)
				return { type = 'KeyPicker', idx = idx, mode = object.Mode, key = object.Value }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValue({ data.key, data.mode })
				end
			end,
		},

		Input = {
			Save = function(idx, object)
				return { type = 'Input', idx = idx, text = object.Value }
			end,
			Load = function(idx, data)
				if Options[idx] and type(data.text) == 'string' then
					Options[idx]:SetValue(data.text)
				end
			end,
		},
	}

	function SaveManager:SetIgnoreIndexes(list)
		for _, key in next, list do
			self.Ignore[key] = true
		end
	end

	function SaveManager:SetFolder(folder)
		self.Folder = folder;
		self:BuildFolderTree()
	end

	function SaveManager:Save(name)
		if (not name) then
			return false, 'no config file is selected'
		end

		local fullPath = self.Folder .. '/settings/' .. name .. '.json'

		local data = {
			objects = {}
		}

		for idx, toggle in next, Toggles do
			if self.Ignore[idx] then continue end

			table.insert(data.objects, self.Parser[toggle.Type].Save(idx, toggle))
		end

		for idx, option in next, Options do
			if not self.Parser[option.Type] then continue end
			if self.Ignore[idx] then continue end

			table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
		end	

		local success, encoded = pcall(httpService.JSONEncode, httpService, data)
		if not success then
			return false, 'failed to encode data'
		end

		writefile(fullPath, encoded)
		return true
	end

	function SaveManager:Load(name)
		if (not name) then
			return false, 'no config file is selected'
		end
		
		local file = self.Folder .. '/settings/' .. name .. '.json'
		if not isfile(file) then return false, 'invalid file' end

		local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(file))
		if not success then return false, 'decode error' end

		for _, option in next, decoded.objects do
			if self.Parser[option.type] then
				self.Parser[option.type].Load(option.idx, option)
			end
		end

		return true
	end

	function SaveManager:GetAccountName()
	    local player = game:GetService("Players").LocalPlayer
	    return player and player.Name or "Unknown"
	end
	
	function SaveManager:GetAccountAutoloadPath()
	    return self.Folder .. "/settings/autoload_accounts.json"
	end
	
	function SaveManager:ReadAccountAutoloads()
	    local path = self:GetAccountAutoloadPath()
	
	    if not isfile(path) then
	        return { accounts = {} }
	    end
	
	    local success, data = pcall(httpService.JSONDecode, httpService, readfile(path))
	    if not success or type(data) ~= "table" then
	        return { accounts = {} }
	    end
	
	    data.accounts = data.accounts or {}
	    return data
	end
	
	function SaveManager:WriteAccountAutoloads(data)
	    writefile(
	        self:GetAccountAutoloadPath(),
	        httpService:JSONEncode(data)
	    )
	end

	function SaveManager:IgnoreThemeSettings()
		self:SetIgnoreIndexes({ 
			"BackgroundColor", "MainColor", "AccentColor", "OutlineColor", "FontColor", -- themes
			"ThemeManager_ThemeList", 'ThemeManager_CustomThemeList', 'ThemeManager_CustomThemeName', -- themes
		})
	end

	function SaveManager:BuildFolderTree()
		local paths = {
			self.Folder,
			self.Folder .. '/themes',
			self.Folder .. '/settings'
		}

		for i = 1, #paths do
			local str = paths[i]
			if not isfolder(str) then
				makefolder(str)
			end
		end
	end

	function SaveManager:RefreshConfigList()
		local list = listfiles(self.Folder .. '/settings')

		local out = {}
		for i = 1, #list do
			local file = list[i]
			if file:sub(-5) == '.json' and not file:find('autoload_accounts.json', 1, true) then
				-- i hate this but it has to be done ...

				local pos = file:find('.json', 1, true)
				local start = pos

				local char = file:sub(pos, pos)
				while char ~= '/' and char ~= '\\' and char ~= '' do
					pos = pos - 1
					char = file:sub(pos, pos)
				end

				if char == '/' or char == '\\' then
					table.insert(out, file:sub(pos + 1, start - 1))
				end
			end
		end
		
		return out
	end

	function SaveManager:SetLibrary(library)
		self.Library = library
	end

	function SaveManager:LoadAutoloadConfig()
	    local account = self:GetAccountName()
	

	    local accountPath = self:GetAccountAutoloadPath()
	    if isfile(accountPath) then
	        local data = self:ReadAccountAutoloads()
	        local cfg = data.accounts[account]
	
	        if cfg then
	            local success, err = self:Load(cfg)
	            if success then
	                return self.Library:Notify(
	                    string.format('Auto loaded account config %q', cfg)
	                )
	            else
	                return self.Library:Notify(
	                    'Failed to load account autoload config: ' .. err
	                )
	            end
	        end
	    end
	

	    local globalPath = self.Folder .. '/settings/autoload.txt'
	    if isfile(globalPath) then
	        local name = readfile(globalPath)
	        local success, err = self:Load(name)
	        if success then
	            self.Library:Notify(string.format('Auto loaded config %q', name))
	        else
	            self.Library:Notify('Failed to load autoload config: ' .. err)
	        end
	    end
	end



	function SaveManager:BuildConfigSection(tab)
		assert(self.Library, 'Must set SaveManager.Library')

		local section = tab:AddRightGroupbox('Configuration')

		section:AddDropdown('SaveManager_ConfigList', { Text = 'Config list', Values = self:RefreshConfigList(), AllowNull = true })
		section:AddInput('SaveManager_ConfigName',    { Text = 'Config name' })

		section:AddDivider()

		section:AddButton('Create config', function()
			local name = Options.SaveManager_ConfigName.Value

			if name:gsub(' ', '') == '' then 
				return self.Library:Notify('Invalid config name (empty)', 2)
			end

			local success, err = self:Save(name)
			if not success then
				return self.Library:Notify('Failed to save config: ' .. err)
			end

			self.Library:Notify(string.format('Created config %q', name))

			Options.SaveManager_ConfigList.Values = self:RefreshConfigList()
			Options.SaveManager_ConfigList:SetValues()
			Options.SaveManager_ConfigList:SetValue(nil)
		end):AddButton('Load config', function()
			local name = Options.SaveManager_ConfigList.Value

			local success, err = self:Load(name)
			if not success then
				return self.Library:Notify('Failed to load config: ' .. err)
			end

			self.Library:Notify(string.format('Loaded config %q', name))
		end)

		section:AddButton('Overwrite config', function()
			local name = Options.SaveManager_ConfigList.Value

			local success, err = self:Save(name)
			if not success then
				return self.Library:Notify('Failed to overwrite config: ' .. err)
			end

			self.Library:Notify(string.format('Overwrote config %q', name))
		end)
		
		section:AddButton('Autoload config', function()
			local name = Options.SaveManager_ConfigList.Value
			writefile(self.Folder .. '/settings/autoload.txt', name)
			SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
			self.Library:Notify(string.format('Set %q to auto load', name))
		end):AddButton('Autoload for this account', function()
		    local name = Options.SaveManager_ConfigList.Value
		    if not name then
		        return self.Library:Notify('No config selected', 2)
		    end
		
		    local data = self:ReadAccountAutoloads()
		    local account = self:GetAccountName()
		
		    data.accounts[account] = name
		    self:WriteAccountAutoloads(data)
			SaveManager.AccountAutoloadLabel:SetText('Current autoload config on this account: ' .. name)
		    self.Library:Notify(
		        string.format('Set %q to auto load for account %q', name, account)
		    )
		end)

		section:AddButton('Refresh config list', function()
			Options.SaveManager_ConfigList.Values = self:RefreshConfigList()
			Options.SaveManager_ConfigList:SetValues()
			Options.SaveManager_ConfigList:SetValue(nil)
		end)

		section:AddButton('Clear global autoload', function()
		    local path = self.Folder .. '/settings/autoload.txt'
		
		    if isfile(path) then
		        delfile(path)
		    end
		
		    SaveManager.AutoloadLabel:SetText('Current autoload config: none')
		    self.Library:Notify('Global autoload cleared')
		end):AddButton('Clear account autoload', function()
		    local data = self:ReadAccountAutoloads()
		    local account = self:GetAccountName()
		
		    if data.accounts[account] then
		        data.accounts[account] = nil
		        self:WriteAccountAutoloads(data)
		    end
		
		    SaveManager.AccountAutoloadLabel:SetText(
		        'Current autoload config on this account: none'
		    )
		
		    self.Library:Notify(
		        string.format('Account autoload cleared for %q', account)
		    )
		end)


		SaveManager.AutoloadLabel = section:AddLabel('Current autoload config: none', true)
		SaveManager.AccountAutoloadLabel = section:AddLabel('Current autoload config on this account: none', true)

		if isfile(self.Folder .. '/settings/autoload.txt') then
			local name = readfile(self.Folder .. '/settings/autoload.txt')
			SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
		end

		do
		    local data = self:ReadAccountAutoloads()
		    local account = self:GetAccountName()
		    local cfg = data.accounts[account]
		
		    if cfg then
		        SaveManager.AccountAutoloadLabel:SetText('Current autoload config on this account: ' .. cfg)
		    end
		end

		SaveManager:SetIgnoreIndexes({ 'SaveManager_ConfigList', 'SaveManager_ConfigName' })
	end

	SaveManager:BuildFolderTree()
end

return SaveManager
