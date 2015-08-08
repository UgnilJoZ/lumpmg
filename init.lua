local np_density = {
	offset = -0.5,
	scale = 1,
	spread = {x=32, y=24, z=32},
	octaves = 3,
	seeddiff = 42,
	persist = 0.6,
	flags = "eased"
}

minetest.register_on_generated(function (minp,maxp)
	-- read content ids
	local c_air     = minetest.get_content_id("air")
	local c_stone   = minetest.get_content_id("stone")
	local c_dirt    = minetest.get_content_id("dirt")
	local c_dirt_wg = minetest.get_content_id("dirt_with_grass")

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
				-- which material?
				if density_map[nixyz] < 0 then
					data[nixyz] = c_air
				elseif density_map[nixyz] > 0.1 then
					data[nixyz] = c_stone
				elseif y < emax.y and density_map[nixyz+chulens.x] < 0 then -- data[x,y+1,z] == air?
					data[nixyz] = c_dirt_wg
				else
					data[nixyz] = c_dirt
				end

				-- next index
				nixyz = nixyz + 1
			end
		end
	end

	-- write back the chunk
	vm:set_data(data)
	vm:write_to_map(data)
end)
