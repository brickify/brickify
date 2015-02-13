VoxelVisualizer = require './VoxelVisualizer'
interactionHelper = require '../../client/interactionHelper'

module.exports = class BrushHandler
	constructor: ( @bundle, @newBrickator ) ->
		return

	legoMouseDown: (event, selectedNode, cachedData) =>
		@_showVoxelGrid( event, selectedNode, cachedData )

		# show one layer of not-enabled (-> to be 3d printed) voxels
		# (one layer = voxel has at least one enabled neighbour)
		# so that users can re-select them
		for v in cachedData.modifiedVoxels
			c = v.voxelCoords
			
			enabledVoxels = cachedData.grid.getNeighbours c.x,
				c.y, c.z, (voxel) ->
					return voxel.enabled

			if enabledVoxels.length > 0
				v.visible = true

	printMouseDown: (event, selectedNode, cachedData) =>
		@_showVoxelGrid( event, selectedNode, cachedData )
		

	legoMouseMove: (event, selectedNode, cachedData) =>
		# enable all voxels we touch with the mouse
		obj = @_getSelectedVoxel event, selectedNode

		if obj
			obj.material = @voxelVisualizer.selectedMaterial
			c = obj.voxelCoords
			cachedData.grid.zLayers[c.z][c.x][c.y].enabled = true

	printMouseMove: (event, selectedNode, cachedData) =>
		# disable all voxels we touch with the mouse
		obj = @_getSelectedVoxel event, selectedNode

		if obj
			obj.material = @voxelVisualizer.deselectedMaterial
			c = obj.voxelCoords
			cachedData.grid.zLayers[c.z][c.x][c.y].enabled = false

			if cachedData.lastSelectedVoxels.indexOf(obj) < 0
				cachedData.lastSelectedVoxels.push obj

	mouseUp: (event, selectedNode, cachedData) =>
		@_hideVoxelGrid event, selectedNode, cachedData

	_hideVoxelGrid: (event, selectedNode, cachedData) =>
		cachedData.threeNode.visible = false

		# hide voxels that have been deselected in the last brush
		# action to allow to go go into the model
		for v in cachedData.lastSelectedVoxels
			v.visible = false
			cachedData.modifiedVoxels.push v
		cachedData.lastSelectedVoxels = []


	_showVoxelGrid: (event, selectedNode, cachedData) =>
		threeObjects = @newBrickator.getThreeObjectsByNode(selectedNode)

		if not cachedData.threeNode
			cachedData.threeNode = threeObjects.voxels
			@voxelVisualizer ?= new VoxelVisualizer()
			@voxelVisualizer.createVisibleVoxels(
				cachedData.grid
				cachedData.threeNode
				true
			)
		else
			cachedData.threeNode.visible = true

		# hide bricks
		threeObjects.bricks.visible = false

		return cachedData

	_getSelectedVoxel: (event, selectedNode) =>
		# returns the first visible voxel (three.Object3D) that is below
		# the cursor position, if it has a voxelCoords property
		threeNodes = @newBrickator.getThreeObjectsByNode selectedNode

		intersects =
			interactionHelper.getPolygonClickedOn(event
				threeNodes.voxels.children
				@bundle.renderer)

		if (intersects.length > 0)
			for intersection in intersects
				obj = intersection.object
			
				if obj.visible and obj.voxelCoords
					return obj
					
		return null
