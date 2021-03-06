class PreviewAssemblyUi
	constructor: (@previewUi) ->
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

		@buildLayerUi.slider.on 'input', =>
			@_updateBuildLayer @previewUi.sceneManager.selectedNode

		@buildLayerUi.increment.on 'click', =>
			@buildLayerUi.slider.val Number(@buildLayerUi.slider.val()) + 1
			@_updateBuildLayer @previewUi.sceneManager.selectedNode

		@buildLayerUi.decrement.on 'click', =>
			@buildLayerUi.slider.val Number(@buildLayerUi.slider.val()) - 1
			@_updateBuildLayer @previewUi.sceneManager.selectedNode

	setEnabled: (enabled) =>
		if enabled
			@_enableBuildMode @previewUi.sceneManager.selectedNode
		else
			@_disableBuildMode @previewUi.sceneManager.selectedNode

	_enableBuildMode: (selectedNode) =>
		@buildContainer.slideDown()

		@preBuildMode = @previewUi.nodeVisualizer.getDisplayMode()
		@previewUi.nodeVisualizer.setDisplayMode selectedNode, 'build'
		.then =>
			@previewUi.nodeVisualizer.getNumberOfBuildLayers selectedNode
			.then (numLayers) =>
				@buildLayerUi.slider.attr 'min', 1
				@buildLayerUi.slider.attr 'max', numLayers
				@buildLayerUi.maxLayer.text numLayers

				@buildLayerUi.slider.val 1
				@_updateBuildLayer selectedNode

	_updateBuildLayer: (selectedNode) =>
		layer = Number @buildLayerUi.slider.val()
		@buildLayerUi.curLayer.text layer
		@previewUi.nodeVisualizer.showBuildLayer selectedNode, layer

	_disableBuildMode: (selectedNode) =>
		@buildContainer.slideUp()
		@previewUi.nodeVisualizer.setDisplayMode selectedNode, @preBuildMode

module.exports = PreviewAssemblyUi
