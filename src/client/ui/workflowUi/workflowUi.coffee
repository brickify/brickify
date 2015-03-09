DownloadProvider = require './downloadProvider'
UiObjects = require './objects'

module.exports = class WorkflowUi
	constructor: (@bundle) ->
		@downloadProvider = new DownloadProvider(@bundle)
		@objects = new UiObjects(@bundle)

	init: () =>
		@sceneManager = @bundle.sceneManager
		@downloadProvider.init('#downloadButton', @sceneManager)
		@objects.init('#objectsContainer', '#brushContainer', '#visibilityContainer')
		@newBrickator = @bundle.getPlugin 'newBrickator'

		@_initStabilityCheck()
		@_initBuildButton()
		@_initNotImplementedMessages()

	_initStabilityCheck: () =>
		@stabilityCheckButton = $('#stabilityCheckButton')
		@stabilityCheckModeEnabled = false

		@stabilityCheckButton.on 'click', () =>
			@stabilityCheckModeEnabled = !@stabilityCheckModeEnabled
			@_applyStabilityViewMode()
	
	_applyStabilityViewMode: () =>
		#disable other UI
		if @stabilityCheckModeEnabled
			@_disabelNonStabilityUi()
		else
			@_enableNonStabilityUi()
			
		@stabilityCheckButton.toggleClass 'active', @stabilityCheckModeEnabled
		@newBrickator._setStabilityView(
			@sceneManager.selectedNode, @stabilityCheckModeEnabled
		)

	_initBuildButton: () =>
		@buildButton = $('#buildButton')
		@buildModeEnabled = false

		@buildContainer = $('#buildContainer')
		@buildContainer.hide()
		@buildContainer.removeClass 'hidden'

		@buildLayerUi = {
			slider: $('#buildSlider')
			decrement: $('#buildDecrement')
			increment: $('#buildIncrement')
			curLayer: $('#currentBuildLayer')
			maxLayer: $('#maxBuildLayer')
			}

		@buildLayerUi.slider.on 'input', () =>
			selectedNode = @bundle.sceneManager.selectedNode
			v = @buildLayerUi.slider.val()
			@_updateBuildLayer(selectedNode)

		@buildLayerUi.increment.on 'click', () =>
			selectedNode = @bundle.sceneManager.selectedNode
			v = @buildLayerUi.slider.val()
			v++
			@buildLayerUi.slider.val(v)
			@_updateBuildLayer(selectedNode)

		@buildLayerUi.decrement.on 'click', () =>
			selectedNode = @bundle.sceneManager.selectedNode
			v = @buildLayerUi.slider.val()
			v--
			@buildLayerUi.slider.val(v)
			@_updateBuildLayer(selectedNode)

		@buildButton.click () =>
			selectedNode = @bundle.sceneManager.selectedNode

			if @buildModeEnabled
				@buildContainer.slideUp()
				@buildButton.removeClass('active')
				@_disableBuildMode selectedNode
			else
				@buildContainer.slideDown()
				@buildButton.addClass('active')
				@_enableBuildMode selectedNode

			@buildModeEnabled = !@buildModeEnabled

	_enableBuildMode: (selectedNode) =>
		@newBrickator.enableBuildMode(selectedNode).then (numZLayers) =>
			# disable other UI
			@_disableNonBuildUi()
	
			# apply grid size to layer view
			@buildLayerUi.slider.attr('min', 0)
			@buildLayerUi.slider.attr('max', numZLayers)
			@buildLayerUi.maxLayer.html(numZLayers)

			@buildLayerUi.slider.val(1)
			@_updateBuildLayer selectedNode

	_updateBuildLayer: (selectedNode) =>
		layer = @buildLayerUi.slider.val()
		@buildLayerUi.curLayer.html(Number(layer))

		@newBrickator.showBuildLayer(selectedNode, layer)

	_disableBuildMode: (selectedNode) =>
		@newBrickator.disableBuildMode(selectedNode).then () =>
			# enable other ui
			@_enableNonBuildUi()


	_disableNonBuildUi: () =>
		@_disableNonPreviewGroups()
		@stabilityCheckButton.addClass 'disabled'

	_enableNonBuildUi: () =>
		@_enableNonPreviewGroups()
		@stabilityCheckButton.removeClass 'disabled'

	_disabelNonStabilityUi: () =>
		@_disableNonPreviewGroups()
		@buildButton.addClass 'disabled'

	_enableNonStabilityUi: () =>
		@_enableNonPreviewGroups()
		@buildButton.removeClass 'disabled'

	_disableNonPreviewGroups: () =>
		$('#loadGroup').find('.btn, .panel').addClass 'disabled'
		$('#editGroup').find('.btn').addClass 'disabled'
		$('#exportGroup').find('.btn').addClass 'disabled'

	_enableNonPreviewGroups: () =>
		$('#loadGroup').find('.btn, .panel').removeClass 'disabled'
		$('#editGroup').find('.btn').removeClass 'disabled'
		$('#exportGroup').find('.btn').removeClass 'disabled'

	_initNotImplementedMessages: () =>
		alertCallback = () ->
			bootbox.alert({
					title: 'Not implemented yet'
					message: 'We are sorry, but this feature is not implemented yet.
					 Please check back later.'
			})

		$('#everythingPrinted').click alertCallback
		$('#everythingLego').click alertCallback
		$('#downloadPdfButton').click alertCallback
		$('#shareButton').click alertCallback


