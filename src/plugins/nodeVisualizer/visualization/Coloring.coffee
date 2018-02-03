THREE = require 'three'
LineMatGenerator = require './LineMatGenerator'

# Provides a simple implementation on how to color voxels and bricks
module.exports = class Coloring
	constructor: (@globalConfig) ->
		@textureMaterialCache = {}

		@brickMaterial = @_createMaterial 0xfff000 #orange

		@studTexture = THREE.ImageUtils.loadTexture('img/stud.png')
		@studTexture.wrapS = THREE.RepeatWrapping
		@studTexture.wrapT = THREE.RepeatWrapping

		@selectedMaterial = @_createMaterial 0xff0000
		@selectedStudMaterial = @_lightenMaterial @selectedMaterial

		@hiddenMaterial = @_createMaterial 0xffaaaa, 0.0

		@legoBoxHighlightMaterial = @_createMaterial 0xff7755, 0.5
		@_setPolygonOffset @legoBoxHighlightMaterial, -1, -1

		@printBoxHighlightMaterial = @_createMaterial 0xeeeeee, 0.4
		@_setPolygonOffset @printBoxHighlightMaterial, -1, -1

		@csgMaterial = @_createMaterial 0xb5ffb8 #greenish gray

		@legoShadowMat = new THREE.MeshBasicMaterial({
			color: 0x707070
			transparent: true
			opacity: 0.3
		})
		@_setPolygonOffset @legoShadowMat, +2, +2

		# printed object material
		@objectPrintMaterial = @_createMaterial(
			@globalConfig.colors.modelColor
			@globalConfig.colors.modelOpacity
		)

		# remove z-Fighting on baseplate
		@_setPolygonOffset @objectPrintMaterial, +3, +3

		@objectShadowMat = new THREE.MeshBasicMaterial(
			color: 0x000000
			transparent: true
			opacity: 0.4
			depthFunc: THREE.GreaterDepth
		)
		@_setPolygonOffset @objectShadowMat, +3, +3

		lineMaterialGenerator = new LineMatGenerator()
		@objectLineMat = lineMaterialGenerator.generate 0x000000
		@objectLineMat.linewidth = 2
		@objectLineMat.transparent = true
		@objectLineMat.opacity = 0.1
		@objectLineMat.depthFunc = THREE.GreaterDepth
		@objectLineMat.depthWrite = false

		@_createBrickMaterials()

	_setPolygonOffset: (material, polygonOffsetFactor, polygonOffsetUnits) ->
		material.polygonOffset = true
		material.polygonOffsetFactor = polygonOffsetFactor
		material.polygonOffsetUnits = polygonOffsetUnits

	setPipelineMode: (enabled) =>
		@objectPrintMaterial.transparent = !enabled

		@objectShadowMat.visible = !enabled
		@objectLineMat.transparent = !enabled
		@objectLineMat.depthWrite = enabled
		if enabled
			@objectLineMat.depthFunc = THREE.LessEqualDepth
		else
			@objectLineMat.depthFunc = THREE.GreaterDepth

		@legoBoxHighlightMaterial.transparent = !enabled
		@printBoxHighlightMaterial.transparent = !enabled
		@objectPrintMaterial.transparent = !enabled
		@legoShadowMat.transparent = !enabled

	###
	# Returns the highlight material collection for the supplied type of voxel
	# @param {String} type either 'lego' or '3d' to get the respective material
	###
	getHighlightMaterial: (type) =>
		if type == 'lego'
			return {
				voxel: @_getLegoHighlightMaterials()
				box: @legoBoxHighlightMaterial
			}
		else if type == '3d'
			return {
				voxel: @_getPrintHighlightMaterials()
				box: @printBoxHighlightMaterial
			}
		return null

	_getLegoHighlightMaterials: =>
		return @legoHighlightMaterials if @legoHighlightMaterials?

		legoHighlightMaterial = @_createMaterial 0xff7755
		legoHighlightStudMaterial = @_lightenMaterial legoHighlightMaterial
		legoHighlightTextureMaterial = @getTextureMaterialForBrick()
		return @legoHighlightMaterials = {
			color: legoHighlightMaterial
			colorStuds: legoHighlightStudMaterial
			textureStuds: legoHighlightTextureMaterial
		}

	_getPrintHighlightMaterials: =>
		return @printHighlightMaterials if @printHighlightMaterials?

		printHighlightMaterial = @_createMaterial 0xeeeeee
		@_setPolygonOffset printHighlightMaterial, -1, -1
		printHighlightStudMaterial = @_lightenMaterial printHighlightMaterial
		@_setPolygonOffset printHighlightStudMaterial, -1, -1

		printHighlightTextureMaterial = @getTextureMaterialForBrick()
		@_setPolygonOffset printHighlightTextureMaterial, -1, -1
		return @printHighlightMaterials = {
			color: printHighlightMaterial
			colorStuds: printHighlightStudMaterial
			textureStuds: printHighlightTextureMaterial
		}

	getSelectedMaterials: =>
		return {
			color: @selectedMaterial
			colorStuds: @selectedStudMaterial
			textureStuds: @getTextureMaterialForBrick()
		}

	getMaterialsForBrick: (brick) =>
		# return stored material or assign a random one
		if brick.visualizationMaterials?
			return brick.visualizationMaterials


		if brick.isSignificantAP
			green = @_getRandomGreenColor()
			apMaterial = @_createMaterial green
			return {
				color: apMaterial
				colorStuds: apMaterial
				gray: apMaterial
				grayStuds: apMaterial
			}
		else if brick.isArticulationPoint
			blue = @_getRandomBlueColor()
			iapMaterial = @_createMaterial blue
			return {
				color: iapMaterial
				colorStuds: iapMaterial
				gray: iapMaterial
				grayStuds: iapMaterial
			}

		# collect materials of neighbors
		neighbors = brick.getNeighborsXY()
		connections = brick.connectedBricks()

		neighborColors = new Set()
		neighbors.forEach (neighbor) ->
			if neighbor.visualizationMaterials?
				neighborColors.add neighbor.visualizationMaterials.color
		connections.forEach (connection) ->
			if connection.visualizationMaterials?
				neighborColors.add connection.visualizationMaterials.color

		# try max. (brickMaterials.length) times to
		# find a material that has not been used
		# by neighbors to visually distinguish bricks
		for i in [0...@_brickMaterials.length]
			materials = @_getRandomBrickMaterials()
			continue if neighborColors.has(materials.color)
			break

		materials.textureStuds = @getTextureMaterialForBrick brick

		brick.visualizationMaterials = materials
		return brick.visualizationMaterials

	getStabilityMaterialForBrick: (brick) =>
		 @getMaterialForBrick brick

	_getRandomBrickMaterials: =>
		i = Math.floor(Math.random() * @_brickMaterials.length)
		return {
			color: @_brickMaterials[i]
			colorStuds: @_studMaterials[i]
			gray: @_grayBrickMaterials[i]
			grayStuds: @_grayStudMaterials[i]
		}

	_createBrickMaterials: =>
		colorList = [
			0x550000
			0x8e0000
			0xc60000
			0xff0000
			0xcc4444
			0xdd4f4f
			0xee5b5b
			0xff6666
		]
		@_brickMaterials = []
		for color in colorList
			@_brickMaterials.push @_createMaterial color

		@_studMaterials = []
		for material in @_brickMaterials
			@_studMaterials.push @_lightenMaterial material

		@_grayBrickMaterials = []
		for material in @_brickMaterials
			@_grayBrickMaterials.push @_convertToGrayscale material

		@_grayStudMaterials = []
		for material in @_grayBrickMaterials
			@_grayStudMaterials.push @_lightenMaterial material

	_lightenMaterial: (material) ->
		newMaterial = material.clone()
		newMaterial.color.addScalar 0.05
		return newMaterial

	# Clones the material and converts its color to grayscale
	_convertToGrayscale: (material) ->
		newMaterial = material.clone()
		gray = material.color.r * 0.3
		gray += material.color.g * 0.6
		gray += material.color.b * 0.1
		newMaterial.color.setRGB gray, gray, gray

		return newMaterial

	_createMaterial: (color, opacity = 1) ->
		return new THREE.MeshLambertMaterial(
			color: color
			opacity: opacity
			transparent: opacity < 1.0
		)

	getTextureMaterialForBrick: (brick) =>
		if brick and brick.getVisualBrick()?
			return brick.getVisualBrick().textureMaterial

		size = if brick then brick.getSize() else {x: 1, y: 1}
		dimensionsHash = @_getHash size
		if @textureMaterialCache[dimensionsHash]?
			return @textureMaterialCache[dimensionsHash]

		studsTexture = @studTexture.clone()
		studsTexture.needsUpdate = true
		studsTexture.repeat.set size.x, size.y

		textureMaterial = new THREE.MeshLambertMaterial(
			map: studsTexture
			transparent: true
			opacity: 0.2
		)

		@textureMaterialCache[dimensionsHash] = textureMaterial
		return textureMaterial

	_getHash: (dimensions) ->
		return dimensions.x + '-' + dimensions.y

	_getRandomBlueColor: ->
		letters = '0123456789'.split('')
		color = '#'
		i = 0
		while i < 4
			color += letters[Math.floor(Math.random() * letters.length)]
			i++
		color += 'ff'
		return color

	_getRandomGreenColor: ->
				# Excluded 0123 to avoid very dark colors
				# Add 0123 to get random color from full spectrum
		letters = '0123'.split('')
		color = '#'
		i = 0
		while i < 2
			color += letters[Math.floor(Math.random() * letters.length)]
			i++
		color += 'ff'
		i = 0
		while i < 2
			color += letters[Math.floor(Math.random() * letters.length)]
			i++
		return color
