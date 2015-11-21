require './polyfills'
$ = require 'jquery'
window.jQuery = window.$ = $
bootstrap = require 'bootstrap'
piwikTracking = require './piwikTracking'

# Init quickconvert after basic page functionality has been initialized
globalConfig = require '../common/globals.yaml'
Bundle = require './bundle'
clone = require 'clone'
fileDropper = require './modelLoading/fileDropper'
modelCache = require './modelLoading/modelCache'
readFiles = require './modelLoading/readFiles'


# Set renderer size to fit to 3 bootstrap columns
globalConfig.staticRendererSize = true
globalConfig.staticRendererWidth = 388
globalConfig.staticRendererHeight = 300
globalConfig.buildUi = false
globalConfig.plugins.dummy = false
globalConfig.plugins.undo = false
globalConfig.plugins.coordinateSystem = false
globalConfig.plugins.legoBoard = false
globalConfig.plugins.editController = false
globalConfig.plugins.csg = false
globalConfig.colors.modelOpacity = globalConfig.colors.modelOpacityLandingPage

# disable wireframe and pipeline on landingpage
globalConfig.rendering.showShadowAndWireframe = false
globalConfig.rendering.usePipeline = false

# clone global config 2 times
config1 = clone globalConfig
config2 = clone globalConfig

# configure left bundle to only show model, disable lego instructions
config1.plugins.newBrickator = false
config1.plugins.legoInstructions = false

# configure right bundle to not show the model
config2.rendering.showModel = false

# configure right bundle to offer downloading lego instructions
config2.offerDownload = true
config2.downloadSettings = {
	testStrip: false
	stl: false
	lego: true
	steps: 0
}

# instantiate 2 brickify bundles
config1.renderAreaId = 'renderArea1'
bundle1 = new Bundle config1
b1 = bundle1.init().then ->
	controls = bundle1.getControls()
	controls.animation.orbit yawSpeed: -1 / 30
	config2.renderAreaId = 'renderArea2'
	bundle2 = new Bundle config2, controls
	b2 = bundle2.init()

	loadAndConvert = (identifier) ->
		b1
			.then -> bundle1.sceneManager.clearScene()
			.then -> bundle1.loadByIdentifier identifier
			.then -> $('#' + config1.renderAreaId).css 'backgroundImage', 'none'
		b2
			.then -> bundle2.sceneManager.clearScene()
			.then -> bundle2.loadByIdentifier identifier
			.then -> $('#' + config2.renderAreaId).css 'backgroundImage', 'none'
		$('.applink').prop 'href', "app#initialModel=#{identifier}"

	#load and process model
	loadAndConvert 'goggles'

	fileInputCallback = (files) ->
		if files.length
			piwikTracking.trackEvent(
				'Landingpage'
				'LoadModel'
				files[0].name
			)

			readFiles files
				.then loadAndConvert
		else
			identifier = event.dataTransfer.getData 'text/plain'
			piwikTracking.trackEvent(
				'Landingpage'
				'LoadModelFromImage'
				identifier
			)
			modelCache.exists identifier
				.then -> loadAndConvert identifier
				.catch -> bootbox.alert(
					title: 'This is not a valid model!'
					message: 'You can only drop stl files or our example images.'
				)

	fileDropper.init fileInputCallback

	document
		.getElementById 'fileInput'
		.addEventListener 'change', (event) ->
			fileInputCallback @files
			@value = ''

	$('#loadButton img').hide()
	$('#loadingStatus').text 'Drop an STL file'
	$('#preview img, #preview a').on 'dragstart', (event) ->
			event.originalEvent.dataTransfer.setData(
				'text/plain'
				event.originalEvent.target.getAttribute 'data-identifier'
			)
