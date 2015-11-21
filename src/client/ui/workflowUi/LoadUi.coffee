fileDropper = require '../../modelLoading/fileDropper'
readFiles = require '../../modelLoading/readFiles'
piwikTracking = require '../../piwikTracking'

class LoadUi
	constructor: (@workflowUi) ->
		@$panel = $('#loadGroup')
		@_initFileLoadHandler()

	setEnabled: (enabled) =>
		@$panel.find('.btn, .panel').toggleClass 'disabled', !enabled

	_initFileLoadHandler: =>
		fileDropper.init @fileLoadHandler

		$('#fileInput').on 'change', (event) =>
			@fileLoadHandler(event.target.files)
				.then =>
					$('#fileInput').val('')
					@workflowUi.hideMenuIfPossible()

	fileLoadHandler: (files) =>
		return unless files.length

		@_checkReplaceModel()
			.then (loadConfirmed) ->
				return unless loadConfirmed

				piwikTracking.trackEvent(
					'Editor'
					'LoadModel'
					files[0].name
				)

				return readFiles files

			.then @workflowUi.bundle.modelLoader.loadByIdentifier

	_checkReplaceModel: =>
		question = 'You already have a model in your scene.
				 Loading the new model will replace the existing model!'

		@workflowUi.bundle.sceneManager.scene.then (scene) ->
			return true if scene.nodes.length is 0
			return new Promise (resolve) -> bootbox.confirm question, resolve

module.exports = LoadUi
