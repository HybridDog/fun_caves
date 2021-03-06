local DEBUG = false

local cave_noise_1 = {offset = 0, scale = 1, seed = 3901, spread = {x = 40, y = 10, z = 40}, octaves = 3, persist = 1, lacunarity = 2}
local cave_noise_2 = {offset = 0, scale = 1, seed = -8402, spread = {x = 40, y = 20, z = 40}, octaves = 3, persist = 1, lacunarity = 2}
local cave_noise_3 = {offset = 15, scale = 10, seed = 3721, spread = {x = 40, y = 40, z = 40}, octaves = 3, persist = 1, lacunarity = 2}
local seed_noise = {offset = 0, scale = 32768, seed = 5202, spread = {x = 80, y = 80, z = 80}, octaves = 2, persist = 0.4, lacunarity = 2}
local biome_noise = {offset = 0.0, scale = 1.0, spread = {x = 400, y = 400, z = 400}, seed = 903, octaves = 3, persist = 0.5, lacunarity = 2.0}
local fortress_noise = {offset = 0, scale = 1, seed = -4082, spread = {x = 200, y = 200, z = 200}, octaves = 2, persist = 1, lacunarity = 2}


local node_cache = {}
local function get_node(name)
	if not node_cache then
		node_cache = {}
	end

	if not node_cache[name] then
		node_cache[name] = minetest.get_content_id(name)
		if name ~= "ignore" and node_cache[name] == 127 then
			print("*** Failure to find node: "..name)
		end
	end

	return node_cache[name]
end

local node = get_node
local deco_depth = 30

local data = {}
--local p2data = {}  -- vm rotation data buffer

-- Create a table of biome ids, so I can use the biomemap.
local biome_ids = {}
for name, desc in pairs(minetest.registered_biomes) do
	biome_ids[minetest.get_biome_id(desc.name)] = desc.name
end

--local function place_schematic(pos, schem, center)
--	local rot = math.random(4) - 1
--	local yslice = {}
--	if schem.yslice_prob then
--		for _, ys in pairs(schem.yslice_prob) do
--			yslice[ys.ypos] = ys.prob
--		end
--	end
--
--	if center then
--		pos.x = pos.x - math.floor(schem.size.x / 2)
--		pos.z = pos.z - math.floor(schem.size.z / 2)
--	end
--
--	for z1 = 0, schem.size.z - 1 do
--		for x1 = 0, schem.size.x - 1 do
--			local x, z
--			if rot == 0 then
--				x, z = x1, z1
--			elseif rot == 1 then
--				x, z = schem.size.z - z1 - 1, x1
--			elseif rot == 2 then
--				x, z = schem.size.x - x1 - 1, schem.size.z - z1 - 1
--			elseif rot == 3 then
--				x, z = z1, schem.size.x - x1 - 1
--			end
--			local dz = pos.z - minp.z + z
--			local dx = pos.x - minp.x + x
--			if pos.x + x > minp.x and pos.x + x < maxp.x and pos.z + z > minp.z and pos.z + z < maxp.z then
--				local ivm = area:index(pos.x + x, pos.y, pos.z + z)
--				local isch = z1 * schem.size.y * schem.size.x + x1 + 1
--				for y = 0, schem.size.y - 1 do
--					local dy = pos.y - minp.y + y
--					if math.min(dx, csize.x - dx) + math.min(dy, csize.y - dy) + math.min(dz, csize.z - dz) > bevel then
--						if yslice[y] or 255 >= math.random(255) then
--							local prob = schem.data[isch].prob or schem.data[isch].param1 or 255
--							if prob >= math.random(255) and schem.data[isch].name ~= "air" then
--								data[ivm] = node(schem.data[isch].name)
--							end
--							local param2 = schem.data[isch].param2 or 0
--							p2data[ivm] = param2
--						end
--					end
--
--					ivm = ivm + area.ystride
--					isch = isch + schem.size.x
--				end
--			end
--		end
--	end
--end

--local function get_decoration(biome)
--	for i, deco in pairs(fun_caves.decorations) do
--		if not deco.biomes or deco.biomes[biome] then
--			local range = 1000
--			if deco.deco_type == "simple" then
--				if deco.fill_ratio and math.random(range) - 1 < deco.fill_ratio * 1000 then
--					return deco.decoration
--				end
--			else
--				-- nop
--			end
--		end
--	end
--end

fun_caves.is_fortress = function(pos, csize)
	local cs = csize
	if not cs then
		-- Fix this to get csize, somehow.
		cs = {x=80, y=80, z=80}
	end

	local x = math.floor((pos.x + 33) / cs.x)
	local y = math.floor((pos.y + 33) / cs.y)
	local z = math.floor((pos.z + 33) / cs.z)

	if y > -3 or (pos.y + 33) % cs.y > cs.y - 5 then
		return false
	end

	local n = minetest.get_perlin(fortress_noise):get3d({x=x, y=y, z=z})
	n = (n * 10000) % 20

	if n == 1 or DEBUG then
		return true
	end

	return false
end


local function generate(p_minp, p_maxp, seed)
	local minp, maxp = p_minp, p_maxp
	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	vm:get_data(data)
	--p2data = vm:get_param2_data()
	local heightmap = minetest.get_mapgen_object("heightmap")
	local biomemap = minetest.get_mapgen_object("biomemap")
	local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
	local csize = vector.add(vector.subtract(maxp, minp), 1)
	local noise_area = VoxelArea:new({MinEdge={x=0,y=0,z=0}, MaxEdge=vector.subtract(csize, 1)})

	local write = false

	-- use the same seed (based on perlin noise).
	math.randomseed(minetest.get_perlin(seed_noise):get2d({x=minp.x, y=minp.z}))

	local fortress = maxp.y / 3100
	if fun_caves.is_fortress(minp, csize) then
		fun_caves.fortress(node, data, area, minp, maxp, math.ceil(maxp.y / 3100))
		write = true
	else
		local cave_1 = minetest.get_perlin_map(cave_noise_1, csize):get3dMap_flat(minp)
		local cave_2 = minetest.get_perlin_map(cave_noise_2, csize):get3dMap_flat(minp)
		local cave_3 = minetest.get_perlin_map(cave_noise_3, {x=csize.x, y=csize.z}):get2dMap_flat({x=minp.x, y=minp.z})
		local biome_n = minetest.get_perlin_map(biome_noise, csize):get3dMap_flat(minp)


		local index = 0
		local index3d = 0
		for z = minp.z, maxp.z do
			for x = minp.x, maxp.x do
				index = index + 1
				index3d = noise_area:index(x - minp.x, 0, z - minp.z)
				local ivm = area:index(x, minp.y, z)

				local height = heightmap[index]
				if height >= maxp.y - 1 and data[area:index(x, maxp.y, z)] ~= node('air') then
					height = 31000
					heightmap[index] = height
				elseif height <= minp.y then
					height = -31000
					heightmap[index] = height
				end

				for y = minp.y, maxp.y do
					if data[ivm] ~= node('air') and y < height - cave_3[index] and cave_1[index3d] * cave_2[index3d] > 0.05 then
						data[ivm] = node("air")
						write = true

						if y > 0 and cave_3[index] < 1 and y == height then
							-- Clear the air above a cave mouth.
							local ivm2 = ivm
							for y2 = y + 1, maxp.y + 8 do
								ivm2 = ivm2 + area.ystride
								if data[ivm2] ~= node("default:water_source") then
									data[ivm2] = node("air")
								end
							end
						end
					end

					ivm = ivm + area.ystride
					index3d = index3d + csize.x
				end
			end
		end

		-- Air needs to be placed prior to decorations.
		local index = 0
		local index3d = 0
		for z = minp.z, maxp.z do
			for x = minp.x, maxp.x do
				index = index + 1
				index3d = noise_area:index(x - minp.x, 0, z - minp.z)
				local ivm = area:index(x, minp.y, z)

				local height = heightmap[index]

				for y = minp.y, maxp.y do
					if y <= height - deco_depth and (height < 31000 or y < 0) then
						local new_node = fun_caves.decorate_cave(node, data, area, minp, y, ivm, biome_n[index3d])
						if new_node then
							data[ivm] = new_node
							write = true
						end
					elseif y < height then
						if data[ivm] == node("air") and (data[ivm - area.ystride] == node('default:stone') or data[ivm - area.ystride] == node('default:sandstone')) then
							data[ivm - area.ystride] = node("fun_caves:dirt")
							write = true
						end
					else
						local pn = minetest.get_perlin(plant_noise):get2d({x=x, y=z})
						local biome = biome_ids[biomemap[index]]
						local new_node = fun_caves.decorate_water(node, data, area, minp, maxp, {x=x,y=y,z=z}, ivm, biome, pn)
						if new_node then
							data[ivm] = new_node
							write = true
						end
					end

					ivm = ivm + area.ystride
					index3d = index3d + csize.x
				end
			end
		end
	end


	if write then
		vm:set_data(data)
		--vm:set_param2_data(p2data)
		if DEBUG then
			vm:set_lighting({day = 15, night = 15})
		else
			vm:calc_lighting({x=minp.x,y=emin.y,z=minp.z},maxp)
		end
		vm:update_liquids()
		vm:write_to_map()
	end

	-- Deal with memory issues. This, of course, is supposed to be automatic.
	if math.floor(collectgarbage("count")/1024) > 400 then
		print("Fun Caves: Manually collecting garbage...")
		collectgarbage("collect")
	end
end


-- Inserting helps to ensure that fun_caves operates first.
table.insert(minetest.registered_on_generateds, 1, generate)
