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

minetest.register_on_generated(function (minp,maxp, seed)
	local pr = PseudoRandom(seed)

	-- read content ids
	local c_air     = minetest.get_content_id("air")
	local c_ignore  = minetest.get_content_id("ignore")
	local c_stone   = minetest.get_content_id("stone")
	local c_dirt    = minetest.get_content_id("dirt")
	local c_dirt_wg = minetest.get_content_id("dirt_with_grass")
	local c_grass   = {}
	local blacklist_air = {[c_stone]=true, [c_dirt]=true, [c_dirt_wg]=true}
	for i = 1, 5 do
		c_grass[i] = minetest.get_content_id("default:grass_"..i)
		blacklist_air[c_grass[i]]=true
	end

	-- read chunk data
	local vm = minetest.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
	local data = vm:get_data()
	local chulens = {x=emax.x-emin.x+1, y=emax.y-emin.y+1, z=emax.z-emin.z+1}

	-- generate noise data
	local density_map = minetest.get_perlin_map(np_density, chulens):get3dMap_flat({x=emin.x, y=emin.z, z=emin.z})

	-- initialize data index
	local nixyz = 1

	-- iterate through data and fill with materials
	for z = emin.z,emax.z do
		for y = emin.y,emax.y do
			for x = emin.x,emax.x do
				if true then
					-- which material?
					if density_map[nixyz] < 0 then
						if not blacklist_air[data[nixyz]] then
							data[nixyz] = c_air
						end
					elseif density_map[nixyz] > 0.15 then
						data[nixyz] = c_stone
					elseif y < emax.y and density_map[nixyz+chulens.x] < 0 then -- data[x,y+1,z] == air?
						-- top border between lump and air
						data[nixyz] = c_dirt_wg
						-- generate plants?
						local random_number = pr:next() -- 0..32767
						if random_number < 8192 then
							-- grass
							local grass_number = random_number % 5 + 1
							data[nixyz + chulens.x] = c_grass[grass_number] -- data[x,y+1,z] = grass
						end
					else
						data[nixyz] = c_dirt
					end-- if density

					-- next index
					nixyz = nixyz + 1
				else
					--print("node.name: "..vm:get_node_at({x=x,y=y,z=z}).name)
					--print("node.id: "..data[nixyz])
					--print('minetest.get_content_id("air"): '.. c_air)
					--print("what the")
				end-- if data
			end-- for x
		end-- for y
	end-- for z

	-- write back the chunk
	vm:set_data(data)
	vm:write_to_map(data)
end)

minetest.register_on_mapgen_init(function(mgparams)
	minetest.set_mapgen_params({mgname="singlenode", flags="nolight"})
end)
