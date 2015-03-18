SyncObject = require '../sync/syncObject'
Scene = require './scene'

###
# A project is the root node of a synchronization. It holds at least one
# (active) scene and might have references to several other old scenes as well.
#
# @class Project
###
class Project extends SyncObject
	@load: =>
		#TODO: Load from share or session
		return Promise.resolve new @()

	constructor: (params = {}) ->
		super params
		@_initScenes() unless params._syncObjectLoad

	_initScenes: =>
		@scenes = []
		@scenes.active = new Scene()
		@scenes.push @scenes.active

	_loadSubObjects: =>
		_loadScene = (reference) -> Scene.from reference
		if Array.isArray(@scenes) and @scenes.length > 0
			return Promise.all(@scenes.map _loadScene)
				.then (scenes) => @scenes = scenes
		else
			@_initScenes()

	getScene: ->
		return @done => @scenes.active

module.exports = Project
