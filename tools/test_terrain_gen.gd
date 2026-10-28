extends SceneTree

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var grid_size := 80
	var cell_size := 5.0
	var origin_x := -200.0
	var origin_z := -200.0
	
	# Sample height function
	var get_h := func(x: float, z: float) -> float:
		if z > -20.0 and x > -30.0:
			return 0.0
		var ridge_dist := absf((x - (-90.0)) - (z - (-120.0)) * 0.7)
		var t := clampf((-20.0 - z) / 100.0, 0.0, 1.0)
		var h_spine := t * 14.0
		var flank := clampf((ridge_dist - 12.0) / 40.0, 0.0, 1.0) * 12.0
		return h_spine + flank

	for iz in range(grid_size):
		for ix in range(grid_size):
			var x0 := origin_x + ix * cell_size
			var z0 := origin_z + iz * cell_size
			var x1 := x0 + cell_size
			var z1 := z0 + cell_size
			
			var y00: float = get_h.call(x0, z0)
			var y10: float = get_h.call(x1, z0)
			var y01: float = get_h.call(x0, z1)
			var y11: float = get_h.call(x1, z1)
			
			var p00 := Vector3(x0, y00, z0)
			var p10 := Vector3(x1, y10, z0)
			var p01 := Vector3(x0, y01, z1)
			var p11 := Vector3(x1, y11, z1)
			
			# Tri 1
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(x0 * 0.1, z0 * 0.1))
			st.add_vertex(p00)
			st.set_uv(Vector2(x1 * 0.1, z0 * 0.1))
			st.add_vertex(p10)
			st.set_uv(Vector2(x0 * 0.1, z1 * 0.1))
			st.add_vertex(p01)
			
			# Tri 2
			st.set_uv(Vector2(x1 * 0.1, z0 * 0.1))
			st.add_vertex(p10)
			st.set_uv(Vector2(x1 * 0.1, z1 * 0.1))
			st.add_vertex(p11)
			st.set_uv(Vector2(x0 * 0.1, z1 * 0.1))
			st.add_vertex(p01)
			
	st.generate_normals()
	var mesh := st.commit()
	var shape := mesh.create_trimesh_shape()
	var elapsed := Time.get_ticks_msec() - t0
	print("Terrain generated in ", elapsed, " ms, faces: ", shape.get_faces().size() / 3)
	quit()
