###
# Dummy Plugin
###

###
# A demo plugin implementation for client-side
#
# We encourage plugin developers to split their plugins in several modules.
# The main file referenced in the module's `package.json`
# will be loaded by the brickify framework.
#
# This file must return a class which provides **hook-methods** that specify
# the interaction between the brickify framework and the plugin.
# E.g. `dummyPlugin.on3dUpdate()`.
#
# @class DummyPlugin
###

class DummyPlugin
	###
	# The plugin loader will call each plugin's `init` method (if provided) after
	# loading the plugin.
	#
	# It is the first method to be called and provides access to the global
	# configuration.
	#
	# @param {Bundle} bundle the bundle this plugin is loaded for
	# @see pluginLoader
	###
	init: (bundle) ->
		console.log 'Dummy Client Plugin initialization'

	###
	# Each plugin that provides a `init3d` method is able to initialize its 3D
	# rendering there and receives a three.js node as argument.
	#
	# If the plugin needs its node for later use it has to store it in `init3d`
	# because it won't be handed the node again later.
	#
	# @param {ThreeJsNode} threejsNode the plugin's node in the 3D-scenegraph
	# @see pluginLoader
	###
	init3d: (threejsNode) ->
		console.log 'Dummy Client Plugin initializes 3d'

	###
	# On each render frame the renderer will call the `on3dUpdate`
	# method of all plugins that provide it.
	#
	# @param {DOMHighResTimeStamp} timestamp the current time
	# @param {Number} lastFrameTime milliseconds it took to render the last frame
	# @see Renderer
	# @see https://developer.mozilla.org/en-US/docs/Web/API/DOMHighResTimeStamp
	###
	on3dUpdate: (timestamp, lastFrameTime) ->
		return undefined

	###
	# Each time a new node is added to the scene, the scene will inform plugins
	# by calling onNodeAdd
	#
	# @param {Node} node the added node
	# @see SceneManager
	###
	onNodeAdd: (node) ->
		console.log node, ' added'
		return

	###
	# Each time a scene's node is selected, the scene will inform plugins by
	# calling onNodeSelect
	#
	# @param {Node} node the selected node
	# @see SceneManager
	###
	onNodeSelect: (node) ->
		console.log node, ' selected'
		return

	###
	# Each time a scene's node is deselected, the scene will inform plugins by
	# calling onNodeDeselect
	#
	# @param {Node} node the deselected node
	# @see SceneManager
	###
	onNodeDeselect: (node) ->
		console.log node, ' deselected'
		return

	###
	# When a node is removed from the scene, the scene will inform plugins by
	# calling onNodeRemove
	#
	# @param {Node} node the removed node
	# @see SceneManager
	###
	onNodeRemove: (node) ->
		console.log node, ' removed'
		return

	###
	# Plugins should return an object with a title property (String) that is
	# displayed in the help and an array of events. These should have an event
	# (String) according to [Mousetrap](https://github.com/ccampbell/mousetrap),
	# a description (String) that is shown in the help dialog and a callback
	# function.
	# @see Hotkeys
	###
	getHotkeys: ->
		return {
		title: 'Dummy'
		events: [
			{
				hotkey: '+'
				description: 'display alert'
				callback: ->
					alert 'Dummy client plugin reports: \'+\' was pressed'
			},
			{
				hotkey: '-'
				description: 'display alert'
				callback: ->
					alert 'Dummy client plugin reports: \'-\' was pressed'
			}
		]
		}

	###
	# Plugins can return an array of brush descriptor objects.
	# @see EditBrushUi
	###
	getBrushes: ->
		return [{
			text: 'dummy-brush'
			icon: 'move'
			onBrushDown: -> console.log 'dummy-brush modifies scene (pointer down)'
			onBrushMove: -> console.log 'dumy-brush modifies scene (pointer move)'
			onBrushUp: -> console.log 'dummy-brush modifies scene (pointer up)'
			onBrushSelect: -> console.log 'dummy-brush was selected'
			onBrushDeselect: -> console.log 'dummy-brush was deselected'
		}]

	###
	# Plugins may offer downloads
	# @param {Node} selectedNode the selected node that should be processed
	# @param {Object} downloadOptions Additional download options
	# @param {Float} downloadOptions.studRadius Desired radius of the Lego studs
	# @param {String} downloadOptions.type desired type, 'stl' or 'instructions'
	###
	getDownload: (downloadOptions, selectedNode) ->
		return {
			fileName: ''
			data: ''
		}

	###
	# Plugins should adjust visual fidelity
	# @param {Number} fidelityLevel the new level of fidelity, which is an index
	# of
	# @param {Array<String>} availableFidelityLevels all available fidelity levels
	# @param {Object} options
	# @param {Boolean} options.screenshotMode true while instructions are rendered
	###
	setFidelity: (fidelityLevel, availableFidelityLevels, options) ->
		return

module.exports = DummyPlugin
