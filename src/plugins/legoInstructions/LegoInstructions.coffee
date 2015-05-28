PNG = require('node-png').PNG
streamToArray = require 'stream-to-array'
THREE = require 'three'
log = require 'loglevel'

class LegoInstructions
	init: (bundle) ->
		@renderer = bundle.renderer
		@nodeVisualizer = bundle.getPlugin 'nodeVisualizer'

	onNodeSelect: (@selectedNode) => return

	onNodeDeselect: => @selectedNode = null

	getDownload: (downloadOptions, selectedNode) =>
		return new Promise (resolve, reject) =>
			log.debug 'Creating pdf instructions...'

			# pseudoisometric
			cam = new THREE.PerspectiveCamera(@renderer.camera.fov, @renderer.camera.aspect, 1, 1000)
			cam.position.set(100,100,100)
			cam.lookAt(new THREE.Vector3(0,0,0))
			cam.up = new THREE.Vector3(0,0,1)

			# enter build mode
			@nodeVisualizer.setDisplayMode(@selectedNode, 'build')
			.then (numLayers) =>
				resultingFiles = []

				# screenshot of each layer
				promiseChain = Promise.resolve()
				for layer in [1..numLayers]
					promiseChain = @_createScreenshotOfLayer(promiseChain, layer, cam)
					promiseChain = promiseChain.then (fileData) =>
						resultingFiles.push fileData
				
				promiseChain.then =>
					console.log 'Finished pdf instructions screenshots'
					resolve resultingFiles

	_createScreenshotOfLayer: (promiseChain, layer, cam) =>
		return promiseChain.then () =>
			return @nodeVisualizer.showBuildLayer(@selectedNode, layer)
			.then =>
				console.log 'create screenshot of layer',layer
				@renderer.renderToImage(cam)
				.then (pixelData) =>
					pixelData.pixels = @_flipAndFitImage pixelData
					@_convertToPng(pixelData)
					.then (pngData) =>
						return ({
							fileName: "LEGO assembly instructions #{layer}.png"
							data: pngData.buffer
						})

	_convertToPng: (renderedImage) ->
		return new Promise (resolve, reject) ->
			png = new PNG({width: renderedImage.viewWidth, height: renderedImage.viewHeight})
			for i in [0...renderedImage.pixels.length]
				png.data[i] = renderedImage.pixels[i]
			png.pack()

			pngData = new Uint8Array(0)

			# read png stream
			png.on 'data', (data) ->
				newData = new Uint8Array(pngData.length + data.length)
				for i in [0...pngData.length]
					newData[i] = pngData[i]
				for i in [0...data.length]
					newData[pngData.length + i] = data[i]
				pngData = newData
			png.on 'end', ->
				resolve pngData

	# flips the image horizontally (because renderer delivers it upside down)
	# and scales it to actual recorded screen measurements (because it is always
	# in size 2^n)
	_flipAndFitImage: (renderedImage) ->
		sw = renderedImage.viewWidth
		sh = renderedImage.viewHeight
		iw = renderedImage.imageWidth
		ih = renderedImage.imageHeight

		newImage = new Uint8Array(sw * sh * 4)

		scaleX = iw / sw
		scaleY = ih / sh

		maxX = sw - 1
		maxY = sh - 1

		for y in [0..maxY]
			# flip new y coordinates
			newY = maxY - y
			oldY = Math.round(y * scaleY)

			for x in [0..maxX]
				newCoords =  (newY * sw) + x
				newCoords *= 4
				oldCoords =  (oldY * iw) + Math.round(x * scaleX)
				oldCoords *= 4
				
				newImage[newCoords] = renderedImage.pixels[oldCoords]
				newImage[newCoords + 1] = renderedImage.pixels[oldCoords + 1]
				newImage[newCoords + 2] = renderedImage.pixels[oldCoords + 2]
				newImage[newCoords + 3] = renderedImage.pixels[oldCoords + 3]

		return newImage
module.exports = LegoInstructions