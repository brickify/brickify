diffHelper = require '../src/common/state/diffHelper'
diffpatch = diffHelper.createJsonDiffPatch()
clone = require 'clone'

logger = require 'winston'

pluginLoader = require('./../src/server/pluginLoader')
pluginHooks = pluginLoader.pluginHooksInstance

diffCallbacks = []

exports.getState = (request, response) ->
	state = getInitializedState request
	response.json state

exports.setState = (request, response) ->
	clientDiff = request.body.deltaState
	state = getInitializedState request

	diffpatch.patch(state,clientDiff)
	#state now contains the current state of both client and server

	oldState = clone(state)

	#check functionality of jsondiffpatch
	#ToDo: could cause performance problems, maybe replace in the future?
	if diffpatch.diff(oldState,state)?
		logger.error 'Diff of identical states was not undefined'

	#call callbacks, let them modify state
	pluginHooks.onStateUpdate state

	#send diff with our initial state to the client
	serverDiff = diffpatch.diff oldState, state

	logger.debug 'Sending delta to client: ' + JSON.stringify(serverDiff)
	if not serverDiff
		response.json {emptyDiff: true}
	else
		response.json serverDiff

exports.resetState = (request, response) ->
	request.session.state = {}
	response.json request.session.state

getInitializedState = (request) ->
	state = request.session.state
	stateInitialized = request.session.stateIsInitialized

	if stateInitialized == true
		return state
	else
		request.session.state = {}
		request.session.stateIsInitialized = true
		return request.session.state