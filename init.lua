local densenoise_offset = 1 - 2 * (minetest.setting_get("lumpmg_air_ratio") or 0.75)

local YMIN = -31000
local YMAX = 31000

local np_density = {
	offset = densenoise_offset,
	scale = 1,
	spread = {x=32, y=24, z=32},
	octaves = 3,
	seeddiff = 42,
	persist = 0.6,
	flags = "eased"
}

local yspread = np_density.spread.y
local max_density
if np_density.persist == 1 then
	max_density = np_density.octaves
else
	max_density = (1-np_density.persist^(np_density.octaves)) / (1-np_density.persist) * np_density.scale + np_density.offset
end

local density_decrease = max_density / yspread -- Density gradiant when getting close to the borders

local YMIN2 = YMIN + yspread-1 -- Minimal Y at which lump density is maximal (decreases smoothly between YMIN and YMIN2)
local YMAX2 = YMAX - yspread+1 -- Maximal Y at which lump density is maximal

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
	if minp.y > YMAX or maxp.y < YMIN then
		return
	end

	minp.y = math.max(minp.y, YMIN)
	maxp.y = math.min(maxp.y, YMAX)

	local pr = PseudoRandom(seed)

	-- read chunk data
	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local data = vm:get_data()

	local side_length = maxp.x - minp.x + 1
	local y_length = maxp.y - minp.y + 1
	local biglen = emax.x - emin.x + 1

	local chulens = {x=side_length, y=y_length+2, z=side_length}
	local a = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
	local ystride = a.ystride

	-- generate noise data
	local density_map = minetest.get_perlin_map(np_density, chulens):get3dMap_flat({x=minp.x, y=minp.y-1, z=minp.z})

	if minp.y-1 < YMIN2 then -- If we are too close from the bottom border, decrease gradually the noise
		local ndens = 1 -- Initialize perlin map index for setting noise to new value
		local ymax_iter = math.min(maxp.y+1, math.ceil(YMIN2)-1)
		local incrY = (y_length + minp.y - ymax_iter) * side_length
		print(minp.y-1, ymax_iter)
		for z = minp.z, maxp.z do
			for y=minp.y-1, ymax_iter do
				local offset = (YMIN2-y) * density_decrease
				for x = minp.x, maxp.x do
					density_map[ndens] = density_map[ndens] - offset
					ndens = ndens + 1
				end
			end
			ndens = ndens + incrY
		end
	end

	if maxp.y + 1 > YMAX2 then -- If we are too close from the top border, decrease gradually the noise
		local ndens = 1 -- Initialize perlin map index for setting noise to new value
		local ymin_iter = math.max(minp.y-1, math.floor(YMAX2)+1)
		local incrY = (y_length + ymin_iter - maxp.y) * side_length
		print(ymin_iter, maxp.y+1)
		for z = minp.z, maxp.z do
			ndens = ndens + incrY
			for y=ymin_iter, maxp.y+1 do
				local offset = (y-YMAX2) * density_decrease
				for x = minp.x, maxp.x do
					density_map[ndens] = density_map[ndens] - offset
					ndens = ndens + 1
				end
			end
		end
	end

	-- initialize perlin map and data index
	local nixyz = 1
	local dixyz = 1

	local decrX = side_length^2*(y_length+2)-1 -- Decrement index every X line
	--print(decrX)
	--print(#density_map)

	-- iterate through data and fill with materials
	for x = minp.x, maxp.x do
		for z = minp.z, maxp.z do
			--print(x-minp.x, z-minp.z, nixyz)
			dixyz = a:index(x, minp.y-1, z)
			local density_below = density_map[nixyz] -- Node below
			nixyz = nixyz + side_length
			local density = density_map[nixyz]
			for y = minp.y, maxp.y do
				nixyz = nixyz + side_length
				local density_above = density_map[nixyz] -- Node above
				if density > 0.15 then
					data[dixyz] = c_stone
				elseif density > 0 then
					if density_above < 0 then
						data[dixyz] = c_dirt_wg
					elseif density_below < 0 then
						data[dixyz] = c_obsidian
					else
						data[dixyz] = c_dirt
					end
				elseif density_below > 0 then
					-- top border between lump and air (air side)
					-- generate plants?
					local random_number = pr:next() -- 0..32767
					if random_number < 8192 then
						-- grass
						local grass_number = random_number % 5 + 1
						data[dixyz] = c_grass[grass_number] -- data[x,y+1,z] = grass
					end
				end
				density_below, density = density, density_above -- Offset density variables for next node
				dixyz = dixyz + ystride
			end
			nixyz = nixyz + side_length
		end
		nixyz = nixyz - decrX
	end

	-- write back the chunk
	vm:set_data(data)
	minetest.generate_ores(vm, minp, maxp)
	vm:set_lighting({day=0, night=0})
	vm:calc_lighting()
	vm:write_to_map(data)
end)

minetest.register_on_mapgen_init(function(mgparams)
	minetest.set_mapgen_params({mgname="singlenode"})
end)
