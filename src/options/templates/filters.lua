local _, LFGAnnouncements = ...
local L = LFGAnnouncements.Localize
local PUtils = LFGAnnouncements.PUtils
local GameUtils = PUtils.Game

-- Lua APIs
local stringformat = string.format
local strjoin = strjoin
local unpack = unpack

local function formatName(id, isLocked)
	local module = LFGAnnouncements.Instances
	local levelRange = module:GetLevelRange(id)
	local name = module:GetInstanceName(id)
	local lockIcon = " |TInterface\\LFGFRAME\\UI-LFG-ICON-LOCK:16|t"

	return stringformat("%s (%d - %d)%s", name, levelRange[1], levelRange[2], isLocked and lockIcon or "")
end

local function UpdateData(object, funcName, ...)
	object[funcName](object, ...)
	LFGAnnouncements.Core:UpdateInvalidEntries()
end

local function createEntry(id, order)
	local instancesModule = LFGAnnouncements.Instances
	local isLocked = instancesModule:IsLocked(id)

	return {
		type = "toggle",
		width = "full",
		order = order,
		disabled = isLocked,
		name = formatName(id, isLocked),
		get = function(info)
			if isLocked then
				return false
			end

			return LFGAnnouncements.DB:GetCharacterData("dungeons", "activated", id)
		end,
		set = function(info, newValue)
			if isLocked then
				return
			end

			local funcName = newValue and "ActivateInstance" or "DeactivateInstance"
			UpdateData(LFGAnnouncements.Instances, funcName, id)
		end,
	}
end

local function createGroup(args, instances)
	local num = #instances

	args["enable_all"] = {
		type = "execute",
		name = L("options_filters_enable_all_btn"),
		width = "normal",
		order = 1,
		func = function()
			local instancesModules = LFGAnnouncements.Instances
			for i = 1, num do
				local id = instances[i]
				if not instancesModules:IsLocked(id) then
					instancesModules:ActivateInstance(id)
				end
			end
		end,
	}
	args["disable_all"] = {
		type = "execute",
		name = L("options_filters_disable_all_btn"),
		width = "normal",
		order = 2,
		func = function()
			local instancesModules = LFGAnnouncements.Instances
			for i = 1, num do
				local id = instances[i]
				if not instancesModules:IsLocked(id) then
					instancesModules:DeactivateInstance(id)
				end
			end
		end,
	}

	for i = 1, num do
		local id = instances[i]
		args["instance_filter_" .. id] = createEntry(id, i + 2)
	end
end

local newName = ""
local function createCustomFilters(args, customEntries)
	for id, name in pairs(customEntries.Names) do
		local group = {
			type = "group",
			name = name,
			order = 1,
			inline = true,
			args = {
				tags = {
					type = "input",
					name = L("options_filters_custom_tag_tags_name"),
					desc = L("options_filters_custom_tag_desc"),
					width = "double",
					order = 2,
					get = function()
						return strjoin(" ", unpack(customEntries.Tags[id]))
					end,
					set = function(info, newValue)
						local tags = {}
						for tag in string.gmatch(strlower(newValue), "[^ ]+") do
							tags[#tags+1] = tag
						end
						UpdateData(LFGAnnouncements.Instances, 'SetCustomTags', id, tags)
					end,
				},
				remove = {
					type = "execute",
					name = L("options_filters_custom_tag_remove_btn"),
					width = "half",
					order = 3,
					func = function()
						UpdateData(LFGAnnouncements.Instances, 'RemoveCustomInstance', id)
					end
				}
			}
		}

		args[id] = group
	end

	args.new = {
		type = "group",
		name = L("options_filters_custom_tag_new_header"),
		order = 2,
		inline = true,
		args = {
			name = {
				type = "input",
				name = L("options_filters_custom_tag_name_name"),
				width = "double",
				order = 1,
				get = function()
					return newName
				end,
				set = function(info, value)
					newName = value
				end,
			},
			button = {
				type = "execute",
				name = L("options_filters_custom_tag_add_btn"),
				width = "half",
				order = 2,
				func = function(info)
					if not newName or newName == "" then
						return
					end

					UpdateData(LFGAnnouncements.Instances, 'AddCustomInstance', newName)
					newName = nil
				end
			},
		}
	}
end

local function optionsTemplate()
	local instancesModule = LFGAnnouncements.Instances
	local db = LFGAnnouncements.DB
	local core = LFGAnnouncements.Core
	local vanilla_dungeons = {
		type = "group",
		name = L("options_filters_vanilla_dungeons_name"),
		order = 5,
		inline = false,
		args = {}
	}
	local instances = instancesModule:GetDungeons(GameUtils.GameVersionLookup.CLASSIC)
	createGroup(vanilla_dungeons.args, instances)

	local args = {
		header = {
			order = 1,
			type = "header",
			width = "full",
			name = L("options_filters_header"),
		},
		difficulty_filter = {
			type = "select",
			width = "full",
			order = 2,
			name = L("options_filters_difficulty_filter_name"),
			desc = L("options_filters_difficulty_filter_desc"),
			values = db.dungeonDifficulties,
			get = function(info)
				return db:GetCharacterData("filters", "difficulty")
			end,
			set = function(info, newValue)
				UpdateData(core, "SetDifficultyFilter", newValue)
			end,
		},
		boost_filter = {
			type = "toggle",
			width = "full",
			order = 3,
			name = L("options_filters_boost_filter_name"),
			desc = L("options_filters_boost_filter_desc"),
			get = function(info)
				return db:GetCharacterData("filters", "boost")
			end,
			set = function(info, newValue)
				UpdateData(core, "SetBoostFilter", newValue)
			end,
		},
		gdkp_filter = {
			type = "toggle",
			width = "full",
			order = 3,
			name = L("options_filters_gdkp_filter_name"),
			desc = L("options_filters_gdkp_filter_desc"),
			get = function(info)
				return db:GetCharacterData("filters", "gdkp")
			end,
			set = function(info, newValue)
				UpdateData(core, "SetGdkpFilter", newValue)
			end,
		},
		lfg_filter = {
			type = "toggle",
			width = "full",
			order = 3,
			name = L("options_filters_lfg_filter_name"),
			desc = L("options_filters_lfg_filter_desc"),
			get = function(info)
				return db:GetCharacterData("filters", "lfg")
			end,
			set = function(info, newValue)
				UpdateData(core, "SetLFGFilter", newValue)
			end,
		},
		lfm_filter = {
			type = "toggle",
			width = "full",
			order = 3,
			name = L("options_filters_lfm_filter_name"),
			desc = L("options_filters_lfm_filter_desc"),
			get = function(info)
				return db:GetCharacterData("filters", "lfm")
			end,
			set = function(info, newValue)
				UpdateData(core, "SetLFMFilter", newValue)
			end,
		},
		fake_filter_amount = {
			type = "range",
			width = "full",
			order = 4,
			name = L("options_filters_fake_filter_amount_name", db:GetCharacterData("filters", "fake_amount")),
			desc = L("options_filters_fake_filter_amount_desc"),
			min = 0,
			max = 50,
			step = 1,
			get = function(info)
				return db:GetCharacterData("filters", "fake_amount")
			end,
			set = function(info, newValue)
				UpdateData(core, "SetFakeFilter", newValue)
			end
		},
		vanilla_dungeons = vanilla_dungeons,
		custom_instances = custom_instances,
	}

	local order = 5
	instances = instancesModule:GetRaids(GameUtils.GameVersionLookup.CLASSIC)
	if instances and next(instances) ~= nil then
		local vanilla_raids = {
			type = "group",
			name = L("options_filters_vanilla_raids_name"),
			order = order,
			inline = false,
			args = {}
		}

		createGroup(vanilla_raids.args, instances)
		args.vanilla_raids = vanilla_raids
	end

	if GameUtils.CompareGameVersion(GameUtils.GameVersionLookup.TBC) then
		instances = instancesModule:GetDungeons(GameUtils.GameVersionLookup.TBC)
		if instances and next(instances) ~= nil then
			order = order + 1
			local tbc_dungeons = {
				type = "group",
				name = L("options_filters_tbc_vanilla_dungeons_name"),
				order = order,
				inline = false,
				args = {}
			}

			createGroup(tbc_dungeons.args, instances)
			args.tbc_dungeons = tbc_dungeons
		end

		instances = instancesModule:GetRaids(GameUtils.GameVersionLookup.TBC)
		if instances and next(instances) ~= nil then
			order = order + 1
			local tbc_raids = {
				type = "group",
				name = L("options_filters_tbc_raids_name"),
				order = order,
				inline = false,
				args = {}
			}

			createGroup(tbc_raids.args, instances)
			args.tbc_raids = tbc_raids
		end
	end

	if GameUtils.CompareGameVersion(GameUtils.GameVersionLookup.WOTLK) then
		instances = instancesModule:GetDungeons(GameUtils.GameVersionLookup.WOTLK)
		if instances and next(instances) ~= nil then
			order = order + 1
			local wotlk_dungeons = {
				type = "group",
				name = L("options_filters_wotlk_dungeons_name"),
				order = order,
				inline = false,
				args = {}
			}

			createGroup(wotlk_dungeons.args, instances)
			args.wotlk_dungeons = wotlk_dungeons
		end

		instances = instancesModule:GetRaids(GameUtils.GameVersionLookup.WOTLK)
		if instances and next(instances) ~= nil then
			order = order + 1
			local wotlk_raids = {
				type = "group",
				name = L("options_filters_wotlk_raids_name"),
				order = order,
				inline = false,
				args = {}
			}

			createGroup(wotlk_raids.args, instances)
			args.wotlk_raids = wotlk_raids
		end
	end

	if GameUtils.CompareGameVersion(GameUtils.GameVersionLookup.CATACLYSM) then
		instances = instancesModule:GetDungeons(GameUtils.GameVersionLookup.CATACLYSM)
		if instances and next(instances) ~= nil then
			order = order + 1
			local cataclysm_dungeons = {
				type = "group",
				name = L("options_filters_cataclysm_dungeons_name"),
				order = order,
				inline = false,
				args = {}
			}

			createGroup(cataclysm_dungeons.args, instances)
			args.cataclysm_dungeons = cataclysm_dungeons
		end

		instances = instancesModule:GetRaids(GameUtils.GameVersionLookup.CATACLYSM)
		if instances and next(instances) ~= nil then
			order = order + 1
			local cataclysm_raids = {
				type = "group",
				name = L("options_filters_cataclysm_raids_name"),
				order = order,
				inline = false,
				args = {}
			}

			createGroup(cataclysm_raids.args, instances)
			args.cataclysm_raids = cataclysm_raids
		end
	end

	order = order + 1
	local custom_instances = {
		type = "group",
		name = L("options_filters_custom_name"),
		order = order,
		inline = false,
		args = {},
	}

	createCustomFilters(custom_instances.args, instancesModule:GetCustomInstances())
	args.custom_instances = custom_instances

	return {
		type = "group",
		name = L("options_filters_header"),
		order = 2,
		args = args
	}
end

LFGAnnouncements.Options.AddOptionTemplate("filters", optionsTemplate)
