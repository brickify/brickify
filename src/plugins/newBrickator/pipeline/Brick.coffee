log = require 'loglevel'

###
# @class Brick
###
class Brick
	@direction = {
		Xp: 'Xp'
		Xm: 'Xm'
		Yp: 'Yp'
		Ym: 'Ym'
		Zp: 'Zp'
		Zm: 'Zm'
	}

	@validBrickSizes = [
		[1, 1, 1], [1, 2, 1], [1, 3, 1], [1, 4, 1], [1, 6, 1], [1, 8, 1],
		[2, 2, 1], [2, 3, 1], [2, 4, 1], [2, 6, 1], [2, 8, 1], [2, 10, 1],
		[1, 1, 3], [1, 2, 3], [1, 3, 3], [1, 4, 3],
		[1, 6, 3], [1, 8, 3], [1, 10, 3], [1, 12, 3], [1, 16, 3],
		[2, 2, 3], [2, 3, 3], [2, 4, 3], [2, 6, 3], [2, 8, 3], [2, 10, 3]
	]

	# Returns the array index of the first size that
	# matches isSizeEqual
	@getSizeIndex: (testSize) =>
		for size, i in @validBrickSizes
			if @isSizeEqual(
				{x: testSize.x, y: testSize.y, z: testSize.z}
				{x: size[0], y: size[1], z: size[2]}
			)
				return i
		return -1

	# Returns true if the given size is a valid size
	@isValidSize: (x, y, z) ->
		for testSize in Brick.validBrickSizes
			if testSize[0] == x and testSize[1] == y and testSize[2] == z
				return true
			else if testSize[0] == y and testSize[1] == x and testSize[2] == z
				return true
		return false

	# Returns true if the two sizes are equal in terms of
	# same height and same x/y dimensions which may be
	# switched
	@isSizeEqual: (a, b) ->
		return ((a.x == b.x and a.y == b.y) or
		(a.x == b.y and a.y == b.x)) and a.z == b.z

	# Creates a brick out of the given set of voxels
	# Takes ownership of voxels without further processing
	constructor: (arrayOfVoxels) ->
		@voxels = new Set()
		for voxel in arrayOfVoxels
			voxel.brick = @
			@voxels.add voxel
		# for connected components labelling algo
		@label = null
		# for articulation point algo
		@resetArticulationPointData()

	resetArticulationPointData: =>
		@visited = false
		@low = null
		@parent = null
		@discoveryTime = 0
		# Count of children in DFS Tree
		@children = 0
		@isArticulationPoint = false
		@isSignificantAP = false

	# Enumerates over each voxel that belongs to this brick
	forEachVoxel: (callback) =>
		@voxels.forEach callback

	# Returns the voxel the brick consists of, if it consists out
	# of one voxel. else returns null
	getVoxel: =>
		if @voxels.size > 1
			return null
		iterator = @voxels.entries()
		return iterator.next().value[0]

	# Returns true if a voxel with this coordinates
	# belongs to this brick
	isVoxelInBrick: (x, y, z) ->
		inBrick = false
		@forEachVoxel (vox) ->
			if vox.position.x == x and
			vox.position.y == y and
			vox.position.z == z
				inBrick = true
		return inBrick

	# Returns the {x, y, z} values of the voxel with
	# the smallest x, y and z.
	# To work properly, this function assumes that there
	# are no holes in the brick and the brick is a proper cuboid
	getPosition: =>
		return @_position if @_position?

		# To bring variables to correct scope
		x = undefined
		y = undefined
		z = undefined

		@forEachVoxel (voxel) ->
			x = voxel.position.x if not x?
			x = Math.min voxel.position.x, x
			y = voxel.position.y if not y?
			y = Math.min voxel.position.y, y
			z = voxel.position.z if not z?
			z = Math.min voxel.position.z, z

		@_position = {
			x: x
			y: y
			z: z
		}
		return @_position

	# Returns the size of the brick
	getSize: =>
		return @_size if @_size?
		@_size = {}

		@forEachVoxel (voxel) =>
			#init values
			@_size.maxX ?= @_size.minX ?= voxel.position.x
			@_size.maxY ?= @_size.minY ?= voxel.position.y
			@_size.maxZ ?= @_size.minZ ?= voxel.position.z

			@_size.minX = voxel.position.x if @_size.minX > voxel.position.x
			@_size.minY = voxel.position.y if @_size.minY > voxel.position.y
			@_size.minZ = voxel.position.z if @_size.minZ > voxel.position.z

			@_size.maxX = voxel.position.x if @_size.maxX < voxel.position.x
			@_size.maxY = voxel.position.y if @_size.maxY < voxel.position.y
			@_size.maxZ = voxel.position.z if @_size.maxZ < voxel.position.z

		@_size = {
			x: (@_size.maxX - @_size.minX) + 1
			y: (@_size.maxY - @_size.minY) + 1
			z: (@_size.maxZ - @_size.minZ) + 1
		}

		return @_size

	isSize: (x, y, z) =>
		size = @getSize()
		if size.x == x and size.y == y and size.z == z
			return true
		else if size.x == y and size.y == x and size.z == z
			return true
		else
			return false

	# Returns a set of all bricks that are next to this brick
	# in the given direction
	getNeighbors: (direction) =>
		###
			TODO
			This check can now 2015-30-06 potentially be removed
			However, I am leaving this check in place for some time
			If the issue does not reappear within two weeks, I will remove it
		###
		# Checking the cache for correctness
		if @_neighbors?[direction]?
			@_neighbors[direction].forEach (neighbor) =>
				if neighbor.voxels.size == 0
					log.warn 'got outdated neighbor from cache'
					@clearNeighborsCache()

		return @_neighbors[direction] if @_neighbors?[direction]?

		neighbors = new Set()

		@forEachVoxel (voxel) =>
			if voxel.neighbors[direction]?
				neighborBrick = voxel.neighbors[direction].brick
				neighbors.add neighborBrick if neighborBrick and neighborBrick != @

		@_neighbors ?= {}
		@_neighbors[direction] = neighbors

		return @_neighbors[direction]

	getNeighborsXY: =>
		neighbors = new Set()

		[Brick.direction.Xp, Brick.direction.Xm, Brick.direction.Yp,
		Brick.direction.Ym].forEach (direction) =>
			@getNeighbors(direction).forEach (brick) ->
				neighbors.add brick

		return neighbors

	###
	# Returns whether this brick is completely covered by other bricks.
	# @return {Object}
	# @returnprop {Boolean} isCompletelyCovered is this brick completely covered
	# @returnprop {Set} coveringBricks the bricks that cover this brick
	###
	getCover: =>
		if not @_isCoveredOnTop?
			stability = @fractionOfConnectionsInZDirection Brick.direction.Zp
			@_isCoveredOnTop = stability > 0.99

		return {
			isCompletelyCovered: @_isCoveredOnTop
			coveringBricks: @getNeighbors Brick.direction.Zp
		}

	# Connected Bricks are neighbors in Zp and Zm direction
	# because they are connected with studs to each other
	connectedBricks: =>
		connectedBricks = new Set()

		@getNeighbors(Brick.direction.Zp).forEach (brick) ->
			connectedBricks.add brick

		@getNeighbors(Brick.direction.Zm).forEach (brick) ->
			connectedBricks.add brick

		return connectedBricks

	# Splits up this brick in 1x1x1 bricks and returns them as a set
	# This brick has no voxels after this operation
	splitUp: =>
		# Tell neighbors to update their cache
		for direction of Brick.direction
			neighbors = @getNeighbors direction
			neighbors.forEach (neighbor) -> neighbor.clearNeighborsCache()

		# Create new bricks
		newBricks = new Set()

		@forEachVoxel (voxel) ->
			brick = new Brick([voxel])
			newBricks.add brick

		@_clearData()
		return newBricks

	# Returns the brick visualization that belongs to this brick
	getVisualBrick: =>
		return @_visualBrick

	# Sets the brick visualization that belongs to this brick
	setVisualBrick: (visualBrick) =>
		@_visualBrick?.setBrick(null) if @_visualBrick isnt visualBrick
		@_visualBrick = visualBrick
		@_visualBrick?.setBrick @

	# Removes all references to this brick from voxels
	# this brick has to be deleted after that
	clear: =>
		# Clear references
		@forEachVoxel (voxel) ->
			voxel.brick = false
		# And stored data
		@_clearData()

	_clearData: =>
		#clear stored data
		@_clearCache()
		@setVisualBrick null
		@voxels.clear()

	_clearCache: =>
		@_size = null
		@_position = null
		@label = null
		@clearNeighborsCache()

	clearNeighborsCache: =>
		@_neighbors = null
		@_isCoveredOnTop = null


	# Merges this brick with the other brick specified,
	# the other brick gets deleted in the process
	mergeWith: (otherBrick) =>
		# Tell neighbors to update their cache
		for direction of Brick.direction
			neighbors = @getNeighbors direction
			neighbors.forEach (neighbor) -> neighbor.clearNeighborsCache()

			otherNeighbors = otherBrick.getNeighbors direction
			otherNeighbors.forEach (neighbor) -> neighbor.clearNeighborsCache()

		#clear size, position and neighbors (to be recomputed)
		@_clearCache()

		# Clear reference to visual brick (needs to be recreated)
		@setVisualBrick null

		#take voxels from other brick
		newVoxels = new Set()

		otherBrick.forEachVoxel (voxel) ->
			newVoxels.add voxel

		otherBrick.clear()

		newVoxels.forEach (voxel) =>
			voxel.brick = @
			@voxels.add voxel

	# Returns true if the size of the brick matches one of @validBrickSizes
	hasValidSize: =>
		size = @getSize()
		return Brick.isValidSize(size.x, size.y, size.z)

	# Returns true if the brick has no holes in it, i.e. is a cuboid
	# voxels marked to be 3d printed count as holes
	isHoleFree: =>
		voxelCheck = {}

		p = @getPosition()
		s = @getSize()

		for x in [p.x...(p.x + s.x)]
			for y in [p.y...(p.y + s.y)]
				for z in [p.z...(p.z + s.z)]
					voxelCheck[x + '-' + y + '-' + z] = false

		@forEachVoxel (voxel) ->
			vp = voxel.position
			if voxel.isLego()
				voxelCheck[vp.x + '-' + vp.y + '-' + vp.z] = true

		hasHoles = false
		for val of voxelCheck
			if voxelCheck[val] is false
				hasHoles = true
				break

		return !hasHoles

	# Returns true if the brick is valid
	# a brick is valid when it has voxels, is hole free and
	# has a valid size
	isValid: =>
		return @voxels.size > 0 and @hasValidSize() and @isHoleFree()

	getStability: =>
		s = @getSize()
		p = @getPosition()
		conBricks = @connectedBricks()

		# Possible slots top & bottom
		possibleSlots = s.x * s.y * 2

		# How many slots are actually connected?
		usedSlots = 0

		lowerZ = p.z - 1
		upperZ = p.z + s.z

		# Test for each possible slot if neighbor bricks have
		# voxels that belong to this slot
		for x in [p.x...(p.x + s.x)]
			for y in [p.y...(p.y + s.y)]
				conBricks.forEach (brick) ->
					if brick.isVoxelInBrick(x, y, upperZ)
						usedSlots++
					if brick.isVoxelInBrick(x, y, lowerZ)
						usedSlots++

		return usedSlots / possibleSlots

	fractionOfConnectionsInZDirection: (directionZmOrZp) =>
		s = @getSize()
		p = @getPosition()
		conBricks = @getNeighbors(directionZmOrZp)

		# Possible slots top or bottom
		possibleSlots = s.x * s.y

		# How many slots are actually connected?
		usedSlots = 0

		if directionZmOrZp is Brick.direction.Zm
			testZ = p.z - 1
		else if directionZmOrZp is Brick.direction.Zp
			testZ = p.z + s.z

		# Test for each possible slot if neighbor bricks have
		# voxels that belong to this slot
		for x in [p.x...(p.x + s.x)]
			for y in [p.y...(p.y + s.y)]
				conBricks.forEach (brick) ->
					if brick.isVoxelInBrick(x, y, testZ)
						usedSlots++

		return usedSlots / possibleSlots

module.exports = Brick
