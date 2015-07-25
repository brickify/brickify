extend = require 'extend'
THREE = require 'three'
PointerControls = require('three-pointer-controls')(THREE)
renderTargetHelper = require './renderTargetHelper'
FxaaShaderPart = require './shader/FxaaPart'
SsaoShaderPart = require './shader/ssaoPart'
SsaoBlurPart = require './shader/ssaoBlurPart'
log = require 'loglevel'
threeHelper = require '../threeHelper'

###
# @class Renderer
###
class Renderer
	constructor: (@pluginHooks, globalConfig, controls) ->
		@scene = null
		@camera = null
		@threeRenderer = null
		@init globalConfig, controls
		@pipelineEnabled = false
		@useBigRendertargets = false
		@usePipelineSsao = false
		@imageRenderQueries = []
		window.addEventListener(
			'resize'
			@windowResizeHandler
		)

	# renders the current scene to an image, uses the camera if provided
	# returns a promise which will resolve with the image
	renderToImage: (camera = @camera, resolution = null) =>
		return new Promise (resolve, reject) =>
			@imageRenderQueries.push {
				resolve
				reject
				camera
				resolution: renderTargetHelper.getNextValidTextureDimension resolution
			}

	localRenderer: (timestamp) =>
		startTime = window.performance.now()
		# Call update hook
		@pluginHooks.on3dUpdate timestamp, @lastFrameTime

		if @imageRenderQueries.length == 0
			@_renderFrame timestamp, @camera, null
		else
			@_renderImage timestamp

		@renderPromiseResolver()
		@renderPromise = null
		@lastFrameTime = window.performance.now() - startTime

	# Renders all plugins
	_renderFrame: (timestamp, camera, renderTarget = null) =>
		# Clear screen
		@threeRenderer.setRenderTarget(renderTarget)
		@threeRenderer.context.stencilMask(0xFF)
		@threeRenderer.clear()

		# Render the default scene (plugins add objects in the init3d hook)
		@threeRenderer.render @scene, camera, renderTarget

		# Allow for custom render passes
		if @pipelineEnabled
			# Init render target
			@_initializePipelineTarget()

			# Clear render target
			@threeRenderer.setRenderTarget(@pipelineRenderTarget.renderTarget)
			@threeRenderer.context.stencilMask(0xFF)
			@threeRenderer.clear()
			@threeRenderer.setRenderTarget(null)

			# let plugins render in our target
			@pluginHooks.onPaint(
				@threeRenderer,
				camera,
				@pipelineRenderTarget.renderTarget
			)

			# Render our target to the screen
			@threeRenderer.render @pipelineRenderTarget.quadScene, @camera

			if @usePipelineSsao
				# Take data from our target and render SSAO
				# data into gauss target
				@threeRenderer.render(
					@ssaoTarget.quadScene, @camera, @ssaoBlurTarget.renderTarget, true
				)

				# Take the SSAO values and render a gaussed version on the screen
				@threeRenderer.render(
					@ssaoBlurTarget.quadScene, @camera
				)

	_renderImage: (timestamp) =>
		# render first query to image
		imageQuery = @imageRenderQueries.shift()

		# override render size if requested
		if imageQuery.resolution?
			renderTargetHelper.configureSize true, imageQuery.resolution

		# create rendertarget
		if not @imageRenderTarget? or
			not renderTargetHelper.renderTargetHasRightSize(
				@imageRenderTarget.renderTarget, @threeRenderer
			)
			if @imageRenderTarget?
				renderTargetHelper.deleteRenderTarget @imageRenderTarget, @threeRenderer

			@imageRenderTarget = renderTargetHelper.createRenderTarget(
				@threeRenderer,
				[],
				null,
				1.0
			)

		# render to target
		@_renderFrame timestamp, imageQuery.camera, @imageRenderTarget.renderTarget

		# save image data
		width = @imageRenderTarget.renderTarget.width
		height = @imageRenderTarget.renderTarget.height

		pixels = new Uint8Array(width * height * 4)

		# fix three inconsistency on current depthTarget dev branch
		rt = @imageRenderTarget.renderTarget
		rt.format = rt.texture.format

		@threeRenderer.readRenderTargetPixels(
			@imageRenderTarget.renderTarget, 0, 0,
			width, height, pixels
		)

		# restore original renderTarget size if it was altered
		if imageQuery.resolution?
			renderTargetHelper.configureSize @useBigRendertargets

		# resolve promise
		imageQuery.resolve {
			viewWidth: @size().width
			viewHeight: @size().height
			imageWidth: width
			imageHeight: height
			pixels: pixels
		}

	# Create / update target for all pipeline passes
	_initializePipelineTarget: =>
		if not @pipelineRenderTarget? or @pipelineRenderTarget.dirty or
		not renderTargetHelper.renderTargetHasRightSize(
			@pipelineRenderTarget.renderTarget, @threeRenderer
		)
			# Create the render target that renders everything anti-aliased to the screen
			shaderParts = []
			if @usePipelineFxaa
				shaderParts.push new FxaaShaderPart()

			if @pipelineRenderTarget?
				renderTargetHelper.deleteRenderTarget @pipelineRenderTarget, @threeRenderer

			@pipelineRenderTarget = renderTargetHelper.createRenderTarget(
				@threeRenderer,
				shaderParts,
				null,
				1.0
			)

			if @usePipelineSsao
				# Get a random texture for SSAO
				randomTex = THREE.ImageUtils.loadTexture('img/randomTexture.png')
				randomTex.wrapS = THREE.RepeatWrapping
				randomTex.wrapT = THREE.RepeatWrapping

				# Delete existing Targets
				if @ssaoTarget?
					renderTargetHelper.deleteRenderTarget @ssaoTarget, @threeRenderer
				if @ssaoBlurTarget?
					renderTargetHelper.deleteRenderTarget @ssaoBlurTarget, @threeRenderer

				# Clone the pipeline render target:
				# use this render target to create SSAO values out of scene
				@ssaoTarget = renderTargetHelper.cloneRenderTarget(
					@pipelineRenderTarget,
					[new SsaoShaderPart()],
					{tRandom: {	type: 't', value: randomTex}},
					1.0
				)

				# Create a rendertarget that applies a gauss filter on everything
				@ssaoBlurTarget = renderTargetHelper.createRenderTarget(
					@threeRenderer,
					[new SsaoBlurPart()],
					{},
					1.0,
					@useBigPipelineTargets
				)

	setFidelity: (fidelityLevel, availableLevels) =>
		@pipelineEnabled = fidelityLevel >= availableLevels.indexOf 'PipelineLow'

		if @pipelineEnabled
			# Determine whether to use FXAA
			if fidelityLevel >= availableLevels.indexOf 'PipelineMedium'
				# Only do something when FXAA is not already used
				if not @usePipelineFxaa
					@usePipelineFxaa = true
					@pipelineRenderTarget = null
			else
				if @usePipelineFxaa
					@usePipelineFxaa = false
					@pipelineRenderTarget = null

			# Determine whether to use bigger render targets (super sampling)
			@useBigRendertargets =
				fidelityLevel >= availableLevels.indexOf 'PipelineHigh'

			renderTargetHelper.configureSize @useBigRendertargets

			# Determine whether to use SSAO
			if fidelityLevel >= availableLevels.indexOf 'PipelineUltra'
				# Only do something when SSAO is not already used
				if not @usePipelineSsao
					@usePipelineSsao = true

					@pipelineRenderTarget?.dirty = true
			else
				if @usePipelineSsao
					@usePipelineSsao = false

					@pipelineRenderTarget?.dirty = true

	addToScene: (node) ->
		@scene.add node

	getDomElement: ->
		return @threeRenderer.domElement

	getCamera: ->
		return @camera

	windowResizeHandler: =>
		@camera.aspect = @size().width / @size().height
		@camera.updateProjectionMatrix()
		@threeRenderer.setSize @size().width, @size().height

		@threeRenderer.render @scene, @camera
		@render()

	zoomToNode: (threeNode) ->
		boundingSphere = threeHelper.getBoundingSphere threeNode
		# Zooms out/in the camera so that the object is fully visible
		threeHelper.zoomToBoundingSphere @camera, @scene, @controls, boundingSphere

	init: (@globalConfig, controls) ->
		@_setupSize @globalConfig
		@_setupRenderer @globalConfig
		@scene = @getDefaultScene()
		@_setupCamera @globalConfig
		@_setupControls @globalConfig, controls

	_setupSize: (globalConfig) ->
		@$canvasWrapper = $ '.canvasWrapper'

	size: ->
		return {
			width: @$canvasWrapper.width()
			height: @$canvasWrapper.height()
		}

	_setupRenderer: (globalConfig) ->
		@threeRenderer = new THREE.WebGLRenderer(
			alpha: true
			antialias: true
			stencil: true
			preserveDrawingBuffer: true
			logarithmicDepthBuffer: false
			canvas: document.getElementById globalConfig.renderAreaId
		)
		@threeRenderer.sortObjects = false

		# Needed for rendering pipeline
		@threeRenderer.extensions.get 'EXT_frag_depth'

		# Stencil test
		gl = @threeRenderer.context
		contextAttributes = gl.getContextAttributes()
		if not contextAttributes.stencil
			log.warn 'The current WebGL context does not have a stencil buffer.
			 Rendering will be (partly) broken'
			@threeRenderer.hasStencilBuffer = false
		else
			@threeRenderer.hasStencilBuffer = true

		@threeRenderer.setSize @size().width, @size().height
		@threeRenderer.autoClear = false

	_setupScene: (globalConfig) ->
		scene = new THREE.Scene()

		scene.fog = new THREE.Fog(
			globalConfig.colors.background
			globalConfig.cameraNearPlane
			globalConfig.cameraFarPlane
		)

		return scene

	_setupCamera: (globalConfig) ->
		@camera = new THREE.PerspectiveCamera(
			globalConfig.fov,
			(@size().width / @size().height),
			globalConfig.cameraNearPlane,
			globalConfig.cameraFarPlane
		)
		@camera.position.set(
			globalConfig.axisLength
			globalConfig.axisLength
			globalConfig.axisLength
		)
		@camera.up.set(0, 0, 1)
		@camera.lookAt(new THREE.Vector3(0, 0, 0))
		Object.observe @camera.position, =>
			@render()

	_setupControls: (globalConfig, controls) ->
		unless controls
			controls = new PointerControls()
			extend true, controls.config, globalConfig.controls
		@controls = controls

	initControls: ->
		@controls.control(@camera).with(@threeRenderer.domElement)

	getControls: =>
		@controls

	_setupLighting: (scene) ->
		ambientLight = new THREE.AmbientLight(0x404040)
		scene.add ambientLight

		directionalLight = new THREE.DirectionalLight(0xffffff)
		directionalLight.position.set 0, 20, 30
		scene.add directionalLight

		directionalLight = new THREE.DirectionalLight(0x808080)
		directionalLight.position.set 20, 0, 30
		scene.add directionalLight

		directionalLight = new THREE.DirectionalLight(0x808080)
		directionalLight.position.set 20, -20, -30
		scene.add directionalLight

	# Creates a scene with default light and rotation settings
	getDefaultScene: =>
		scene = @_setupScene(@globalConfig)
		@_setupLighting(scene)
		return scene

	render: =>
		if not @renderPromise?
			@renderPromise = new Promise (@renderPromiseResolver) =>
				requestAnimationFrame @localRenderer
		return @renderPromise

module.exports = Renderer
