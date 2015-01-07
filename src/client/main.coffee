require('es6-promise').polyfill()

path = require 'path'
r = require 'react'

globalConfig = require './globals.yaml'
Bundle = require './bundle'

window.jQuery = window.$ = require 'jquery'
bootstrap = require 'bootstrap'


commandFunctions = {
	initialModel: (value) ->
		console.log 'loading initial model'
		p = /^[0-9a-z]{32}/
		if p.test value
			bundle.modelLoader.loadByHash value
		else
			console.warn 'Invalid value for initialModel'
}

postInitCallback = () ->
	#look at url hash and run commands
	hash = window.location.hash
	hash = hash.substring 1, hash.length
	commands = hash.split '+'
	for cmd in commands
		key = cmd.split('=')[0]
		value = cmd.split('=')[1]
		if commandFunctions[key]?
			commandFunctions[key](value)

	#clear url hash after executing commands
	window.location.hash = ''

bundle = new Bundle(globalConfig)
bundle.init().then(postInitCallback)
