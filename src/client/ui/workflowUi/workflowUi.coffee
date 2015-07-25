perfectScrollbar = require 'perfect-scrollbar'

LoadUi = require './LoadUi'
EditUi = require './EditUi'
PreviewUi = require './PreviewUi'
ExportUi = require './ExportUi'
fullscreen = require 'fullscreen'

class WorkflowUi
	constructor: (@bundle) -> return

	# Called by sceneManager when a node is added
	onNodeAdd: (node) =>
		@_enable ['load', 'edit', 'preview', 'export']

	# Called by sceneManager when a node is removed
	onNodeRemove: (node) =>
		@workflow.preview.quit()
		@bundle.sceneManager.scene.then (scene) =>
			@enableOnly @workflow.load if scene.nodes.length == 0

	onNodeSelect: (node) =>
		@workflow.edit.onNodeSelect node

	onNodeDeselect: (node) =>
		@workflow.edit.onNodeDeselect node

	enableOnly: (groupUi) =>
		for step, ui of @workflow
			ui.setEnabled ui is groupUi

	enableAll: =>
		@_enable Object.keys @workflow

	_enable: (groupsList) =>
		for step, ui of @workflow
			ui.setEnabled step in groupsList

	init: =>
		@workflow =
			load: new LoadUi @
			edit: new EditUi @
			preview: new PreviewUi @
			export: new ExportUi @

		@enableOnly @workflow.load

		@_initScrollbar()
		@_initToggleButton()
		@_initFullscreenButton()

	_initScrollbar: ->
		sidebar = document.getElementById 'leftSidebar'
		perfectScrollbar.initialize sidebar
		window.addEventListener 'resize', -> perfectScrollbar.update sidebar

	_initToggleButton: ->
		$('#toggleMenu').click => @toggleMenu()

	_initFullscreenButton: ->
		if fullscreen.available()
			$('#fullScreen').click => @toggleFullScreen()
			$('#fullScreen').show()

	toggleMenu: ->
		$('#leftSidebar').css('height': 'auto')
		$('#sidebar-content').slideToggle null, ->
			$('#leftSidebar').toggleClass 'collapsed-sidebar'
			$('#leftSidebar').css('height': '')

	toggleFullScreen: =>
		fs = fullscreen(document.documentElement)
		if fs.target()?
			fs.release()
		else
			fs.request()

	hideMenuIfPossible: ->
		return unless $('#toggleMenu:visible').length > 0
		$('#leftSidebar').css('height': 'auto')
		$('#sidebar-content').slideUp null, ->
			$('#leftSidebar').addClass 'collapsed-sidebar'
			$('#leftSidebar').css('height': '')

	toggleStabilityView: =>
		@workflow.preview.toggleStabilityView()

	toggleAssemblyView: =>
		@workflow.preview.toggleAssemblyView()

module.exports = WorkflowUi
