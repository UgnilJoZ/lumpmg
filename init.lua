local densenoise_offset = 1 - 2 * (minetest.setting_get("lumpmg_air_ratio") or 0.75)

local np_density = {
	offset = densenoise_offset,
	scale = 1,
	spread = {x=32, y=24, z=32},
	octaves = 3,
	seeddiff = 42,
	persist = 0.6,
	flags = "eased"
}

-- read content ids
local c_air      = minetest.get_content_id("air")
local c_ignore   = minetest.get_content_id("ignore")
local c_stone    = minetest.get_content_id("default:stone")
local c_obsidian = minetest.get_content_id("default:obsidian")
local c_dirt     = minetest.get_content_id("default:dirt")
local c_dirt_wg  = minetest.get_content_id("default:dirt_with_grass")
local c_grass    = {}
local blacklist_air = {[c_stone]=true, [c_dirt]=true, [c_dirt_wg]=true}
for i = 1, 5 do
	c_grass[i] = minetest.get_content_id("default:grass_"..i)
	blacklist_air[c_grass[i]]=true
end

local noisemap

minetest.register_on_generated(function(minp, maxp, seed)
	local pr = PseudoRandom(seed)

	-- read chunk data
	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local data = vm:get_data()

	local side_length = maxp.x - minp.x + 1
	local biglen = side_length+32

	local chulens = {x=side_length, y=side_length, z=side_length}

	-- generate noise data
	if not noisemap then
		noisemap = minetest.get_perlin_map(np_density, chulens)
	end
	local density_map = noisemap:get3dMap_flat(minp)

	-- initialize perlin map and data index
	local nixyz = 1
	local dixyz = 1

	-- iterate through data and fill with materials
	dixyz = dixyz+16*biglen*biglen
	for z = minp.z,maxp.z do
		dixyz = dixyz+16*biglen
		for y = minp.y,maxp.y do
			dixyz = dixyz+16
			for x = minp.x,maxp.x do
				local density = density_map[nixyz]
				-- which material?
				if density < 0 then
					if not blacklist_air[data[dixyz]] then
						data[dixyz] = c_air
					end
				elseif density > 0.15 then
					data[dixyz] = c_stone
				elseif y < maxp.y -- density map is just calculated from minp to maxp
				and density_map[nixyz+side_length] < 0 then -- data[x,y+1,z] == air?
					-- top border between lump and air
					data[dixyz] = c_dirt_wg
					-- generate plants?
					local random_number = pr:next() -- 0..32767
					if random_number < 8192 then
						-- grass
						local grass_number = random_number % 5 + 1
						data[dixyz + biglen] = c_grass[grass_number] -- data[x,y+1,z] = grass
					end
				elseif y > minp.y
				and density_map[nixyz-side_length] < 0 then
					data[dixyz] = c_obsidian
				else
					data[dixyz] = c_dirt
				end-- if density

				-- next index
				nixyz = nixyz + 1
				dixyz = dixyz + 1
			end-- for x
			dixyz = dixyz+16
		end-- for y
		dixyz = dixyz+16*biglen
	end-- for z
	--dixyz = dixyz+16*biglen*biglen

	-- write back the chunk
	vm:set_data(data)
	vm:set_lighting({day=0, night=0})
	vm:calc_lighting()
	vm:write_to_map(data)
end)

minetest.register_on_mapgen_init(function(mgparams)
	minetest.set_mapgen_params({mgname="singlenode"})
end)
