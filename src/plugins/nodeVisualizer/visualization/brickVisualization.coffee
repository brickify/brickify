GeometryCreator = require './GeometryCreator'
THREE = require 'three'
Coloring = require './Coloring'
StabilityColoring = require './StabilityColoring'
interactionHelper = require '../../../client/interactionHelper'
VoxelWireframe = require './VoxelWireframe'
VoxelSelector = require '../VoxelSelector'

###
# This class provides visualization for Voxels and Bricks
# @class BrickVisualization
###
class BrickVisualization
	constructor: (@bundle,  @brickThreeNode, @brickShadowThreeNode,
								@defaultColoring, @fidelity) ->

		@renderer = @bundle.renderer

		@csgSubnode = new THREE.Object3D()
		@brickThreeNode.add @csgSubnode

		@bricksSubnode = new THREE.Object3D()
		@temporaryVoxels = new THREE.Object3D()
		@brickThreeNode.add @bricksSubnode
		@brickThreeNode.add @temporaryVoxels

		@stabilityColoring = new StabilityColoring()

		@printVoxels = []

		@isStabilityView = false
		@_highlightVoxelVisibility = true

	initialize: (@grid) =>
		@voxelWireframe = new VoxelWireframe(
			@bundle, @grid, @brickShadowThreeNode, @defaultColoring
		)
		@geometryCreator = new GeometryCreator(@bundle.globalConfig, @grid)
		@voxelSelector = new VoxelSelector @

		@_highlightVoxel = @geometryCreator.getBrick(
			{x: 0, y: 0, z: 0},
			{x: 1, y: 1, z: 1},
			@defaultColoring.getHighlightMaterial('3d').voxel
			@fidelity
		)
		@_highlightVoxel.visible = false

		@brickThreeNode.add @_highlightVoxel

	showCsg: (newCsgGeometry) =>
		@csgSubnode.children = []
		if not newCsgGeometry?
			@csgSubnode.visible = false

		for geometry in newCsgGeometry
			csgMesh = new THREE.Mesh geometry, @defaultColoring.csgMaterial
			@csgSubnode.add csgMesh

		@csgSubnode.visible = true
		@_render()

	hideCsg: =>
		@csgSubnode.visible = false
		@_render()

	hideVoxelAndBricks: =>
		@bricksSubnode.visible = false
		@_render()

	showVoxelAndBricks: =>
		@bricksSubnode.visible  = true
		@_render()

	# Updates brick and voxel visualization
	updateVisualization: (coloring = @defaultColoring, recreate = false) =>
		# Delete temporary voxels
		@temporaryVoxels.children = []

		if recreate
			@bricksSubnode.children = []
		else
			# Throw out all visual bricks that have no valid linked brick
			for layer in @bricksSubnode.children
				deletionList = []
				for visualBrick in layer.children
					if not visualBrick.brick? or not visualBrick.brick.isValid()
						deletionList.push visualBrick

				for delBrick in deletionList
					# Remove from scenegraph
					layer.remove delBrick
					# Delete reference from datastructure brick
					if delBrick.brick?
						delBrick.brick.setVisualBrick null

		# Recreate visible bricks for all bricks in the datastructure that
		# have no linked brick

		# Sort layerwise for build view
		brickLayers = []
		maxZ = 0

		@grid.getAllBricks().forEach (brick) =>
			z = brick.getPosition().z
			maxZ = Math.max z, maxZ
			brickLayers[z] ?= []

			if (not recreate) and (not brick.getVisualBrick()?)
				brickLayers[z].push brick
			if brick.getVisualBrick()?
				brick.getVisualBrick().visible = yes
				brick.getVisualBrick().hasBeenSplit = no

		# Create three layer object if it does not exist
		for z in [0..maxZ]
			if not @bricksSubnode.children[z]?
				layerObject = new THREE.Object3D()
				@bricksSubnode.add layerObject

		for z, brickLayer of brickLayers
			z = Number(z)
			layerObject = @bricksSubnode.children[z]

			for brick in brickLayer
				# Create visual brick
				materials = coloring.getMaterialsForBrick brick
				threeBrick = @geometryCreator.getBrick(
					brick.getPosition()
					brick.getSize()
					materials
					@fidelity
				)

				# Link data <-> visuals
				brick.setVisualBrick threeBrick

				# Add to scene graph
				layerObject.add threeBrick

		# Set stud visibility in second pass so that visibility of
		# all bricks in all layers is in the correct state
		for z, brickLayer of brickLayers
			for brick in brickLayer
				@_setStudVisibility brick

		# If this coloring differs from the last used coloring, go through
		# all visible bricks to update their material
		if @_oldColoring != coloring
			for layer in @bricksSubnode.children
				for visualBrick in layer.children
					materials = coloring.getMaterialsForBrick visualBrick.brick
					visualBrick.setMaterial materials
		@_oldColoring = coloring

		@unhighlightBigBrush()

		@_render()

		# Show not filled lego shape as outline
		outlineCoords = @printVoxels.map (voxel) -> voxel.position
		@voxelWireframe.createWireframe outlineCoords

		@_visibleChildLayers = null

	_setStudVisibility: (brick) ->
		cover = brick.getCover()
		if cover.isCompletelyCovered
			showStuds = false
			cover.coveringBricks.forEach (brick) ->
				showStuds = showStuds or not brick.getVisualBrick().visible
		else
			showStuds = true

		brick.getVisualBrick().setStudVisibility showStuds

	setPossibleLegoBoxVisibility: (isVisible) =>
		@voxelWireframe.setVisibility isVisible

	setStabilityView: (enabled) =>
		@isStabilityView = enabled
		coloring = if @isStabilityView then @stabilityColoring else @defaultColoring
		@updateVisualization(coloring)

		# Turn off possible lego box and highlight during stability view
		if enabled
			@_legoBoxVisibilityBeforeStability = @voxelWireframe.isVisible()
			@voxelWireframe.setVisibility false
			@_highlightVoxel.visible = false
		else
			@voxelWireframe.setVisibility @_legoBoxVisibilityBeforeStability

	showBrickLayer: (layer) =>
		layer += @_getBuildLayerModifier()

		# Hide highlight when in build mode
		@_highlightVoxel.visible = false
		@unhighlightBigBrush()

		visibleLayers = @_getVisibleLayers()
		for i in [0...visibleLayers.length] by 1
			threeLayer = visibleLayers[i]
			if i <= layer
				if i < layer
					@_makeLayerGrayscale threeLayer
				else
					@_makeLayerColored threeLayer
				for visibleBrick in threeLayer.children
					visibleBrick.visible = true
			else
				for visibleBrick in threeLayer.children
					visibleBrick.visible = false

		# Set stud visibility in second pass so that visibility of
		# all bricks in all layers is in the correct state
		for threeLayer in visibleLayers
			for visibleBrick in threeLayer.children
				@_setStudVisibility visibleBrick.brick

		@_render()

	_makeLayerGrayscale: (layer) ->
		for threeBrick in layer.children
			threeBrick.setGray true

	_makeLayerColored: (layer) ->
		for threeBrick in layer.children
			threeBrick.setGray false

	showAllBrickLayers: =>
		for layer in @_getVisibleLayers()
			layer.visible = true
			@_makeLayerColored layer

	getNumberOfVisibleLayers: =>
		return @_getVisibleLayers().length

	getNumberOfBuildLayers: =>
		numLayers = @getNumberOfVisibleLayers()
		numLayers -= @_getBuildLayerModifier()
		return numLayers

	_getBuildLayerModifier: =>
		# If there is 3D print below first lego layer, show lego starting
		# with layer 1 and show only 3D print in first instruction layer
		minLayer = @grid.getLegoVoxelsZRange().min
		return if minLayer > 0 then -1 else 0

	_getVisibleLayers: =>
		@_visibleChildLayers ?= @bricksSubnode.children.filter (layer) ->
			return layer.children.length > 0
		return @_visibleChildLayers

	# Highlights the voxel below mouse and returns it
	highlightVoxel: (event, selectedNode, type, bigBrush) =>
		# Invert type, because if we are highlighting a 'lego' voxel,
		# we want to display it as 'could be 3d printed'
		voxelType = '3d'
		voxelType = 'lego' if type is '3d'

		highlightMaterial = @defaultColoring.getHighlightMaterial voxelType
		hVoxel = highlightMaterial.voxel
		hBox = highlightMaterial.box

		voxel = @voxelSelector.getVoxel event, {type: type}
		if voxel?
			@_highlightVoxel.visible = true and @_highlightVoxelVisibility
			worldPos = @grid.mapVoxelToWorld voxel.position
			return voxel if @_highlightVoxel.position.equals worldPos
			@_highlightVoxel.position.set(
				worldPos.x, worldPos.y, worldPos.z
			)
			@_highlightVoxel.setMaterial hVoxel
			@_highlightBigBrush voxel, hBox if bigBrush
		else
			return unless @_highlightVoxel.visible
			# Clear highlight if no voxel is below mouse
			@_highlightVoxel.visible = false
			@unhighlightBigBrush()

		@_render()

		return voxel

	_highlightBigBrush: (voxel, material) =>
		size = @voxelSelector.getBrushSize true
		dimensions = new THREE.Vector3 size.x, size.y, size.z
		unless @bigBrushHighlight? and
		@bigBrushHighlight.dimensions.equals dimensions
			@brickShadowThreeNode.remove @bigBrushHighlight if @bigBrushHighlight
			@bigBrushHighlight = @geometryCreator.getBrickBox(
				dimensions
				material
			)
			@brickShadowThreeNode.add @bigBrushHighlight

		worldPosition = @grid.mapVoxelToWorld voxel.position
		@bigBrushHighlight.position.copy worldPosition
		@bigBrushHighlight.material = material
		@bigBrushHighlight.visible = true

	unhighlightBigBrush: =>
		@bigBrushHighlight?.visible = false

	# Makes the voxel below mouse to be 3d printed
	makeVoxel3dPrinted: (event, selectedNode, bigBrush) =>
		# Hide highlight voxel since it will be made invisible
		@_highlightVoxel.visible = false

		if bigBrush
			mainVoxel = @voxelSelector.getVoxel event, {type: 'lego'}
			mat = @defaultColoring.getHighlightMaterial '3d'
			@_highlightBigBrush mainVoxel, mat.box if mainVoxel?
		voxels = @voxelSelector.getVoxels event, {type: 'lego', bigBrush: bigBrush}
		return null unless voxels

		for voxel in voxels
			voxel.make3dPrinted()
			# Show studs of brick below
			brickBelow = voxel.neighbors.Zm?.brick
			if brickBelow
				brickBelow.getVisualBrick().setStudVisibility true

			# Split visual brick into voxels (only once per brick)
			if (voxel.brick)
				visualBrick = voxel.brick.getVisualBrick()
				if not visualBrick.hasBeenSplit
					voxel.brick.forEachVoxel (voxel) =>
						# Give this brick a 1x1 stud texture
						visualBrick.materials.textureStuds =
							@defaultColoring.getTextureMaterialForBrick()
						temporaryVoxel = @geometryCreator.getBrick(
							voxel.position
							{x: 1, y: 1, z: 1}
							visualBrick.materials
							@fidelity
						)
						temporaryVoxel.voxelPosition = voxel.position
						@temporaryVoxels.add temporaryVoxel
					visualBrick.hasBeenSplit = true
					visualBrick.visible = false
			# Hide visual voxels for 3d printed geometry
			for temporaryVoxel in @temporaryVoxels.children
				if temporaryVoxel.voxelPosition is voxel.position
					temporaryVoxel.visible = false
					break

		@_render()
		return voxels

	###
	# @return {Array} the list of changed voxels
	###
	makeAllVoxels3dPrinted: (selectedNode) =>
		@printVoxels = @voxelSelector.getAllVoxels(selectedNode)
		legoVoxels = @printVoxels.filter (voxel) -> voxel.isLego()
		legoVoxels.map (voxel) -> voxel.make3dPrinted()
		@voxelSelector.clearSelection()
		return legoVoxels

	resetTouchedVoxelsToLego: =>
		voxel.makeLego() for voxel in @voxelSelector.touchedVoxels
		@voxelSelector.clearSelection()

	# Makes the voxel below mouse to be made out of lego
	makeVoxelLego: (event, selectedNode, bigBrush) =>
		# Hide highlight
		@_highlightVoxel.visible = false

		if bigBrush
			mainVoxel = @voxelSelector.getVoxel event, {type: '3d'}
			mat = @defaultColoring.getHighlightMaterial 'lego'
			@_highlightBigBrush mainVoxel, mat.box if mainVoxel?
		voxels = @voxelSelector.getVoxels event, {type: '3d', bigBrush: bigBrush}
		return null unless voxels

		for voxel in voxels
			voxel.makeLego()

			# Create a visible temporary voxel at this position
			temporaryVoxel = @geometryCreator.getBrick(
				voxel.position
				{x: 1, y: 1, z: 1}
				@defaultColoring.getSelectedMaterials()
				@fidelity
			)
			temporaryVoxel.voxelPosition = voxel.position
			@temporaryVoxels.add temporaryVoxel
		@_render()
		return voxels

	###
	# @return {Array} the list of changed voxels
	###
	makeAllVoxelsLego: (selectedNode) =>
		printVoxels = @printVoxels
		@printVoxels = []
		printVoxels.map (voxel) -> voxel.makeLego()
		@voxelSelector.clearSelection()
		return printVoxels

	resetTouchedVoxelsTo3dPrinted: =>
		voxel.make3dPrinted() for voxel in @voxelSelector.touchedVoxels
		@voxelSelector.clearSelection()

	# Clears the selection and updates the possibleLegoWireframe
	updateModifiedVoxels: =>
		@printVoxels = @printVoxels
			.concat @voxelSelector.touchedVoxels
			.filter (voxel) -> not voxel.isLego()
		return @voxelSelector.clearSelection()

	setHighlightVoxelVisibility: (@_highlightVoxelVisibility) => return

	setFidelity: (@fidelity) =>
		@_highlightVoxel?.setFidelity @fidelity

		for voxel in @temporaryVoxels.children
			voxel.setFidelity @fidelity

		for layer in @bricksSubnode.children
			for threeBrick in layer.children
				threeBrick.setFidelity @fidelity

	_render: =>
		@renderer.render()

module.exports = BrickVisualization
