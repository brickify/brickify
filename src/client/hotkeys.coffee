###
#  @module Hotkeys
###

module.exports = class Hotkeys
	constructor: (pluginHooks, @selection) ->
		@events = []
		@bind '?', 'General', 'Show this help', () =>
			@showHelp()
		@bind 'esc', 'General', 'Close modal window', () =>
			bootbox.hideAll()

		@addEvents events for events in pluginHooks.getHotkeys()

	showHelp: =>
		message = ''
		for own group, events of @events
			message += '<section><h4>' + group + '</h4>'
			for event in events
				message += '<p><span class="keys"><kbd>' + event.hotkey +
					'</kbd></span> <span>' + event.description + '</span></p>'
			message += '</section>'
		bootbox.dialog({
			title: 'Keyboard shortcuts'
			message: message
		})

	###
	# @param {String} hotkey Event description of Mousescript
	# @param {String} group Title of section to show in help
	# @param {String} description Description to show in help
	# @param {Function} callback Callback to be called when event is triggered
	###
	bind: (hotkey, titlegroup, description, callback) ->
		Mousetrap.bind hotkey, => callback @selection.selectedNode
		if @events[titlegroup] is undefined
			@events[titlegroup] = []
		@events[titlegroup].push {hotkey: hotkey, description: description}

	addEvents: (eventSpecs) ->
		for event in eventSpecs.events
			@bind(event.hotkey, eventSpecs.title, event.description, event.callback)
