ReadableFileStream = require('filestream').read
stlParser = require 'stl-parser'
meshlib = require 'meshlib'
log = require 'loglevel'

modelCache = require './modelCache'

averageFaceSize = 240 # Bytes

loadingPercentage = 80
processingPercentage = 90

idleText = 'Drop an STL File'
processingText = 'Processing Geometry'
viewPreparationText = 'Preparing View'

$loadingTextElement = $ '#loadingStatus'
progressBarElement = document.getElementById 'progressBar'

module.exports = (files) ->

	return new Promise (resolve, reject) ->

		if files.length > 1
			errorObject = {
				title: 'Import failed'
				message: 'Loading of multiple files is not supported.'
			}
			bootbox.alert errorObject
			return reject errorObject

		file = files[0]

		if not /stl$/i.test file.name
			bootbox.alert(
				title: 'Your file does not have the right format!'
				message: 'Only .stl files are supported at the moment.
					We are working on adding more file formats'
			)
			return Promise.reject('Wrong file format')

		faceCounter = file.size / averageFaceSize

		progressBarElement.style.width = 0
		$loadingTextElement.text 'Loading File'

		fileStream = new ReadableFileStream file
		fileStream.on 'error', (error) ->
			bootbox.alert {
				title: 'Import failed'
				message: 'Your file contains errors that we could not fix.
					You can try to fix your model with e.g.
					<a href=http://meshlab.sourceforge.net>meshlab</a>
					before uploading it.'
			}
			reject error

		streamingStlParser = stlParser {blocking: false}
		modelBuilder = new meshlib.ModelBuilder()

		streamingStlParser.on 'data', (data) ->
			# if data-chunk is the header
			if data.faceCount?
				faceCounter = data.faceCount
			# or a face
			else
				progress = (data.number / faceCounter) * loadingPercentage
				if progress < loadingPercentage
					progressBarElement.style.width = progress + '%'

		streamingStlParser.on 'warning', log.warn

		streamingStlParser.on 'error', (error) ->
			@end()
			streamingStlParser.unpipe modelBuilder
			bootbox.alert {
				title: 'Invalid STL-file'
				message: error.message
				callback: ->
					progressBarElement.style.width = 0
					$loadingTextElement.text idleText
			}
			reject error


		modelBuilder.on 'model', (model) ->
			progressBarElement.style.width = loadingPercentage + '%'
			$loadingTextElement.text processingText

			processModel = ->
				model
				.setFileName file.name
				.calculateNormals()
				.buildFaceVertexMesh()
				.done()
				.then ->
					progressBarElement.style.width = processingPercentage + '%'
					$loadingTextElement.text viewPreparationText
					return modelCache.store model
				.then (hash) ->
					progressBarElement.style.width = '100%'
					$loadingTextElement.text idleText
					resolve hash
					progressBarElement.style.width = 0

			# Give time to render text
			setTimeout processModel, 50

		fileStream
		.pipe streamingStlParser
		.pipe modelBuilder
