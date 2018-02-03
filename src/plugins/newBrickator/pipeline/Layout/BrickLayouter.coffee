log = require 'loglevel'

Brick = require '../Brick'
Voxel = require '../Voxel'
DataHelper = require '../DataHelper'
Random = require '../Random'
Layouter = require './Layouter'

###
# @class BrickLayouter
###

class BrickLayouter extends Layouter
	constructor: (pseudoRandom = false) ->
		Random.usePseudoRandom pseudoRandom

	_isBrickLayouter: ->
		return true

	_isPlateLayouter: ->
		return false

	_findMergeableNeighbors: (brick) =>
		mergeableNeighbors = []

		if brick.getSize().z is 1
			mergeableNeighbors.push @_findMergeableNeighborsUpOrDownwards(
				brick
				Brick.direction.Zp
			)
			mergeableNeighbors.push @_findMergeableNeighborsUpOrDownwards(
				brick
				Brick.direction.Zm
			)
			return mergeableNeighbors

		mergeableNeighbors.push @_findMergeableNeighborsInDirection(
			brick
			Brick.direction.Yp
			(obj) -> return obj.x
			(obj) -> return obj.y
		)
		mergeableNeighbors.push @_findMergeableNeighborsInDirection(
			brick
			Brick.direction.Ym
			(obj) -> return obj.x
			(obj) -> return obj.y
		)
		mergeableNeighbors.push @_findMergeableNeighborsInDirection(
			brick
			Brick.direction.Xm
			(obj) -> return obj.y
			(obj) -> return obj.x
		)
		mergeableNeighbors.push @_findMergeableNeighborsInDirection(
			brick
			Brick.direction.Xp
			(obj) -> return obj.y
			(obj) -> return obj.x
		)


		return mergeableNeighbors

	_findMergeableNeighborsInDirection: (brick, dir, widthFn, lengthFn) =>
		if widthFn(brick.getSize()) > 2 and lengthFn(brick.getSize()) >= 2
			return null

		voxels = brick.voxels
		mergeVoxels = new Set()
		mergeBricks = new Set()

		# Find neighbor voxels, noMerge if any is empty
		voxelIter = voxels.values()
		while voxel = voxelIter.next().value
			mVoxel = voxel.neighbors[dir]
			return null unless mVoxel?
			mergeVoxels.add mVoxel unless mVoxel.brick is brick

		# Find neighbor bricks,
		# noMerge if any not present
		# noMerge if any brick not 1x1x1
		mergeVoxelIter = mergeVoxels.values()
		while mVoxel = mergeVoxelIter.next().value
			mBrick = mVoxel.brick
			return null unless mBrick and mBrick.isSize(1, 1, 1)
			mergeBricks.add mBrick

		allVoxels = DataHelper.union [voxels, mergeVoxels]

		size = Voxel.sizeFromVoxels(allVoxels)
		if Brick.isValidSize(size.x, size.y, size.z)
			return mergeBricks if @_minFractionOfConnectionsPresent(allVoxels)

		# Check another set of voxels in merge direction, starting from mergeVoxels
		# This is necessary for the 2 brick steps of larger bricks
		mergeVoxels2 = new Set()
		mergeVoxelIter = mergeVoxels.values()
		while mVoxel = mergeVoxelIter.next().value
			mVoxel2 = mVoxel.neighbors[dir]
			return null unless mVoxel2?
			mergeVoxels2.add mVoxel2

		mergeVoxel2Iter = mergeVoxels2.values()
		while mVoxel2 = mergeVoxel2Iter.next().value
			mBrick2 = mVoxel2.brick
			return null unless mBrick2 and mBrick2.isSize(1, 1, 1)
			mergeBricks.add mBrick2

		mergeVoxels2.forEach (mVoxel2) ->
			allVoxels.add mVoxel2

		size = Voxel.sizeFromVoxels(allVoxels)
		if Brick.isValidSize(size.x, size.y, size.z)
			return mergeBricks if @_minFractionOfConnectionsPresent(allVoxels)

		return null

	###
		Check if at least half of the top and half of the bottom voxels
		offer connection possibilities
		This is used as a heuristic to determine whether or not to merge bricks:
		if a brick has less than minFraction connection
		it may lead to a more unstable layout
	###
	_minFractionOfConnectionsPresent: (voxels) =>
		minFraction = .51
		fraction = Voxel.fractionOfConnections voxels
		return fraction >= minFraction

	_chooseNeighborsToMergeWith: (mergeableNeighbors) =>
		numBricks = []
		maxBricks = 0

		for neighborSet, i in mergeableNeighbors
			continue if not neighborSet?
			numBricks.push {
				num: neighborSet.size
				index: i
			}
			maxBricks = Math.max maxBricks, neighborSet.size

		largestConnections = numBricks.filter (element) ->
			return element.num is maxBricks

		randomOfLargest = largestConnections[Random.next(largestConnections.length)]
		return randomOfLargest.index

	# Assumes brick is 1x1x1
	_findMergeableNeighborsUpOrDownwards: (brick, direction) =>
		return null if brick.getSize().z != 1

		secondLayerBricks = brick.getNeighbors(Brick.direction.Zp)
		return null unless secondLayerBricks.size is 1

		slBrick = secondLayerBricks.values().next().value
		return null unless slBrick.isSize(1, 1, 1)

		thirdLayerBricks = slBrick.getNeighbors(Brick.direction.Zp)
		return null unless thirdLayerBricks.size is 1

		tlBrick = thirdLayerBricks.values().next().value
		return null unless tlBrick.isSize(1, 1, 1)

		neighbors = new Set()
		neighbors.add slBrick
		neighbors.add tlBrick
		return neighbors

module.exports = BrickLayouter
