Hotkeys = require '../hotkeys'
PointerDispatcher = require './pointerDispatcher'
WorkflowUi = require './workflowUi/workflowUi'
HintUi = require './HintUi'

###
# @module ui
###

module.exports = class Ui
	constructor: (@bundle) ->
		@renderer = @bundle.renderer
		@pluginHooks = @bundle.pluginHooks
		@workflowUi = new WorkflowUi(@bundle)
		@workflowUi.init()
		@hintUi = new HintUi()
		@pointerDispatcher = new PointerDispatcher(@bundle, @hintUi)

	# Bound to updates to the window size:
	# Called whenever the window is resized.
	windowResizeHandler: (event) =>
		@renderer.windowResizeHandler()

	init: =>
		@_initListeners()
		@_initHotkeys()

	_initListeners: =>
		@pointerDispatcher.init()

	_initHotkeys: =>
		@hotkeys = new Hotkeys(@pluginHooks, @bundle.sceneManager)
		@hotkeys.addEvents @bundle.sceneManager.getHotkeys()

		gridHotkeys = {
			title: 'UI'
			events: [
				{
					description: 'Toggle coordinate system / lego plate'
					hotkey: 'g'
					callback: @_toggleGridVisibility
				}
				{
					description: 'Toggle stability view'
					hotkey: 's'
					callback: @_toggleStabilityView
				}
				{
					description: 'Toggle LEGO assembly view'
					hotkey: 'l'
					callback: @_toggleAssemblyView
				}
			]
		}
		@hotkeys.addEvents gridHotkeys

	_toggleGridVisibility: =>
		@bundle.getPlugin('lego-board').toggleVisibility()
		@bundle.getPlugin('coordinate-system').toggleVisibility()

	_toggleStabilityView: =>
		@workflowUi.toggleStabilityView()

	_toggleAssemblyView: =>
		@workflowUi.toggleAssemblyView()
