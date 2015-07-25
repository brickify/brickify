###
  #Lego Board Plugin#

  Creates a lego board as a workspace surface to help people align models
  to the lego grid
###

THREE = require 'three'
threeConverter = require '../../client/threeConverter'
modelCache = require '../../client/modelLoading/modelCache'
globalConfig = require '../../common/globals.yaml'
RenderTargetHelper = require '../../client/rendering/renderTargetHelper'
stencilBits = require '../../client/rendering/stencilBits'

dimension = 400

module.exports = class LegoBoard
	# Store the global configuration for later use by init3d
	init: (@bundle) ->
		@globalConfig = @bundle.globalConfig
		return

	# Load the board
	init3d: (@threejsNode) =>
		@fidelity = 0
		@usePipeline = false
		@isVisible = true
		@isScreenshotMode = no

		@_initMaterials()
		@_initbaseplateBox()
		@_initStudGeometries()

		@_updateFidelitySettings()

		# create scene for pipeline
		@pipelineScene = @bundle.renderer.getDefaultScene()

	_initbaseplateBox: =>
		# Create baseplate with 5 faces in each direction
		box = new THREE.BoxGeometry(dimension, dimension, 8, 5, 5)
		bufferGeometry = new THREE.BufferGeometry()
		bufferGeometry.fromGeometry box
		@baseplateBox = new THREE.Mesh(bufferGeometry, @baseplateMaterial)
		@baseplateBox.translateZ -4
		@threejsNode.add @baseplateBox

	_initStudGeometries: =>
		@studsContainer = @_generateStuds 7
		@studsContainer.visible = false
		@threejsNode.add @studsContainer

		@highFiStudsContainer = @_generateStuds 42
		@highFiStudsContainer.visible = false
		@threejsNode.add @highFiStudsContainer

	_generateStuds: (radiusSegments) =>
		studGeometry = new THREE.CylinderGeometry(
			@globalConfig.studSize.radius
			@globalConfig.studSize.radius
			@globalConfig.studSize.height
			radiusSegments
		)
		rotation = new THREE.Matrix4()
		rotation.makeRotationX(1.571)
		studGeometry.applyMatrix(rotation)

		translation = new THREE.Matrix4()
		translation.makeTranslation 0, 0, @globalConfig.studSize.height / 2
		studGeometry.applyMatrix translation

		studsGeometry = new THREE.Geometry()
		xSpacing = @globalConfig.gridSpacing.x
		ySpacing = @globalConfig.gridSpacing.y
		studsGeometrySize = 80
		for x in [0...studsGeometrySize] by xSpacing
			for y in [0...studsGeometrySize] by ySpacing
				translation.makeTranslation x, y, 0
				studsGeometry.merge studGeometry, translation
		bufferGeometry = new THREE.BufferGeometry()
		bufferGeometry.fromGeometry studsGeometry

		container = new THREE.Object3D()
		for x in [(-dimension + xSpacing) / 2 ... dimension / 2] by studsGeometrySize
			for y in [(-dimension + ySpacing) / 2 ... dimension / 2] by studsGeometrySize
				mesh = new THREE.Mesh(bufferGeometry, @studMaterial)
				mesh.translateX x
				mesh.translateY y
				container.add mesh

		return container

	_initMaterials: =>
		studTexture = THREE.ImageUtils.loadTexture(
			'img/baseplateStud.png'
			undefined
			@bundle.renderer.render
		)
		studTexture.wrapS = THREE.RepeatWrapping
		studTexture.wrapT = THREE.RepeatWrapping
		studTexture.repeat.set dimension / 8, dimension / 8

		@baseplateMaterial = new THREE.MeshLambertMaterial(
			color: globalConfig.colors.basePlate
		)
		@baseplateTexturedMaterial = new THREE.MeshLambertMaterial(
			map: studTexture
		)
		@currentBaseplateMaterial = @baseplateTexturedMaterial

		@baseplateTransparentMaterial = new THREE.MeshLambertMaterial(
				color: globalConfig.colors.basePlate
				opacity: 0.4
				transparent: true
		)

		@studMaterial = new THREE.MeshLambertMaterial(
				color: globalConfig.colors.basePlateStud
		)

	on3dUpdate: =>
		# This check is only important if we don't use the pipeline
		return if @usePipeline or @isScreenshotMode

		# Check if the camera is below z=0. if yes, make the plate transparent
		# and hide studs
		if not @bundle?
			return

		camera = @bundle.renderer.camera

		if camera.position.z < 0
			@baseplateBox.material = @baseplateTransparentMaterial
			@studsContainer.visible = false
			@highFiStudsContainer.visible = false
		else
			@_updateFidelitySettings()

	onPaint: (threeRenderer, camera, target) =>
		return if not @isVisible or @isScreenshotMode

		# Recreate textures if either they havent been generated yet or
		# the screen size has changed
		if not (@renderTargetsInitialized? and
		RenderTargetHelper.renderTargetHasRightSize(
			@pipelineSceneTarget.renderTarget, threeRenderer
		))
			if @pipelineSceneTarget?
				RenderTargetHelper.deleteRenderTarget @pipelineSceneTarget, threeRenderer

			@pipelineSceneTarget = RenderTargetHelper.createRenderTarget(
				threeRenderer, null, null, 1.0
			)
			@renderTargetsInitialized = true

		# Render board
		threeRenderer.render(
			@pipelineScene, camera, @pipelineSceneTarget.renderTarget, true
		)

		gl = threeRenderer.context

		# Render baseplate transparent if cam looks from below
		if camera.position.z < 0
			# One fully transparent render pass
			@pipelineSceneTarget.blendingMaterial.uniforms.opacity.value = 0.4
			threeRenderer.render @pipelineSceneTarget.quadScene, camera, target, false
		else
			# One default opaque pass
			@pipelineSceneTarget.blendingMaterial.uniforms.opacity.value = 1
			threeRenderer.render @pipelineSceneTarget.quadScene, camera, target, false

			# Render one pass transparent, where visible object or shadow is
			# (= no lego)
			gl.enable(gl.STENCIL_TEST)
			gl.stencilFunc(gl.EQUAL, 0x00, stencilBits.legoMask)
			gl.stencilOp(gl.KEEP, gl.KEEP, gl.KEEP)
			gl.stencilMask(0x00)

			@pipelineSceneTarget.blendingMaterial.uniforms.opacity.value = 0.4

			gl.disable(gl.DEPTH_TEST)
			threeRenderer.render @pipelineSceneTarget.quadScene, camera, target, false
			gl.enable(gl.DEPTH_TEST)

			gl.disable(gl.STENCIL_TEST)

	toggleVisibility: =>
		@threejsNode.visible = !@threejsNode.visible
		@isVisible = !@isVisible

	setFidelity: (fidelityLevel, availableLevels, options) =>
		if options.screenshotMode?
			@isScreenshotMode = options.screenshotMode
			@threejsNode.visible = @isVisible and not @isScreenshotMode

		# Determine whether to show or hide studs
		if fidelityLevel >= availableLevels.indexOf 'PipelineHigh'
			@fidelity = 2
			@_updateFidelitySettings()
		else if fidelityLevel > availableLevels.indexOf 'DefaultMedium'
			@fidelity = 1
			@_updateFidelitySettings()
		else
			@fidelity = 0
			@_updateFidelitySettings()

		# Determine whether to use the pipeline or not
		if fidelityLevel >= availableLevels.indexOf 'PipelineLow'
			if not @usePipeline
				@usePipeline = true

				# move lego board and studs from threeNode to pipeline scene
				@_moveThreeObjects @threejsNode, @pipelineScene, [
					@baseplateBox
					@studsContainer
					@highFiStudsContainer
				]
		else
			if @usePipeline
				@usePipeline = false

				# move lego board and studs from pipeline to threeNode
				@_moveThreeObjects @pipelineScene, @threejsNode, [
					@baseplateBox
					@studsContainer
					@highFiStudsContainer
				]

	_moveThreeObjects: (from, to, objects) ->
		for object in objects
			from.remove object
			to.add object

	_updateFidelitySettings: =>
		# show studs?
		@studsContainer.visible = @fidelity is 1
		@highFiStudsContainer.visible = @fidelity is 2

		# remove texture because we have physical studs?
		if @fidelity is 0
			@baseplateBox.material =  @baseplateTexturedMaterial
		else
			@baseplateBox.material = @baseplateMaterial
		@currentBaseplateMaterial = @baseplateBox.material
