THREE = require 'three'

# This class provides basic functionality to create simple Voxel/Brick geometry
module.exports = class GeometryCreator
	constructor: (@grid) ->
		@brickGeometryCache = {}
		@knobGeometryCache = {}

		@knob = new THREE.CylinderGeometry(
			#these numbers are made up to look good. don't use for csg operations
			@grid.spacing.x * 0.3, @grid.spacing.y * 0.3, @grid.spacing.z * 0.7, 7
		)
		
		rotation = new THREE.Matrix4()
		rotation.makeRotationX(1.571)
		@knob.applyMatrix(rotation)

	getVoxel: (gridPosition, material) =>
		return @getBrick gridPosition, {x: 1, y: 1, z: 1}, material

	getBrick: (gridPosition, brickDimensions, material) =>
		# returns a THREE.Geometry that uses the given material and is
		# transformed to match the given grid position
		brickGeometry = @_getBrickGeometry(brickDimensions)
		knobGeometry = @_getKnobsGeometry(brickDimensions)

		brick = new BrickObject(brickGeometry, knobGeometry, material)

		worldBrickSize = {
			x: brickDimensions.x * @grid.spacing.x
			y: brickDimensions.y * @grid.spacing.y
			z: brickDimensions.z * @grid.spacing.z
		}
		worldBrickPosition = @grid.mapVoxelToWorld gridPosition

		#translate so that the x:0 y:0 z:0 coordinate matches the models corner
		#(center of model is physical center of box)
		brick.translateX worldBrickSize.x / 2.0
		brick.translateY worldBrickSize.y / 2.0
		brick.translateZ worldBrickSize.z / 2.0

		# normal voxels have their origin in the middle, so translate the brick
		# to match the center of a voxel
		brick.translateX @grid.spacing.x / -2.0
		brick.translateY @grid.spacing.y / -2.0
		brick.translateZ @grid.spacing.z / -2.0

		# move to world position
		brick.translateX worldBrickPosition.x
		brick.translateY worldBrickPosition.y
		brick.translateZ worldBrickPosition.z

		#store references for further use
		brick.setVoxelCoords gridPosition

		return brick

	_getBrickGeometry: (brickDimensions) =>
		# returns a box geometry for the given dimensions

		ident = @_getHash brickDimensions
		if @brickGeometryCache[ident]?
			return @brickGeometryCache[ident]

		brickGeometry = new THREE.BoxGeometry(
			brickDimensions.x * @grid.spacing.x
			brickDimensions.y * @grid.spacing.y
			brickDimensions.z * @grid.spacing.z
		)

		@brickGeometryCache[ident] = brickGeometry
		return brickGeometry

	_getKnobsGeometry: (brickDimensions) =>
		# returns knobs for the given brick size

		ident = @_getHash brickDimensions
		if @knobGeometryCache[ident]?
			return @knobGeometryCache[ident]

		knobs = new THREE.Geometry()

		worldBrickSize = {
			x: brickDimensions.x * @grid.spacing.x
			y: brickDimensions.y * @grid.spacing.y
			z: brickDimensions.z * @grid.spacing.z
		}

		for xi in [0..brickDimensions.x - 1] by 1
			for yi in [0..brickDimensions.y - 1] by 1
				tx = (@grid.spacing.x * (xi + 0.5)) - (worldBrickSize.x / 2)
				ty = (@grid.spacing.y * (yi + 0.5)) - (worldBrickSize.y / 2)
				tz = (@grid.spacing.z * 0.7)

				translation = new THREE.Matrix4()
				translation.makeTranslation(tx, ty, tz)

				knobs.merge @knob, translation

		@knobGeometryCache[ident] = knobs
		return knobs

	_getHash: (dimensions) =>
		return dimensions.x + '-' + dimensions.y + '-' + dimensions.z

class BrickObject extends THREE.Object3D
	constructor: (brickGeometry, knobGeometry, material) ->
		super()
		brickMesh = new THREE.Mesh(brickGeometry, material)
		knobMesh = new THREE.Mesh(knobGeometry, material)
		@add brickMesh
		@add knobMesh

	setMaterial: (@material) =>
		@children[0].material = @material
		@children[1].material = @material

	setKnobVisibility: (boolean) =>
		@children[1].visible = boolean

	setVoxelCoords: (@voxelCoords) =>
		# stores a reference of this bricks voxel coordinates for
		# further usage
		return

	setHighlight: (isHighlighted, material) =>
		# one may highlight this brick with a special material
		if isHighlighted
			@_nonHighlightMaterial = @children[0].material
			@setMaterial material
		else if @_nonHighlightMaterial?
			@setMaterial @_nonHighlightMaterial

			



