###
  #Fidelity Control Plugin#

  Measures the current FPS and instigates rendering fidelity changes
  accordingly via the `uglify()` and `beautify()` plugin hooks
###

$ = require 'jquery'
piwikTracking = require '../../client/piwikTracking'

minimalAcceptableFps = 20
upgradeThresholdFps = 40
accumulationFrames = 10
timesBelowThreshold = 5
fpsDisplayUpdateTime = 1000
maxNoPipelineDecisions = 3
piwikStatInterval = 20

###
# @class FidelityControl
###
class FidelityControl
	@fidelityLevels = [
		'DefaultLow'
		'DefaultMedium'
		'DefaultHigh'
		'PipelineLow'
		'PipelineMedium'
		'PipelineHigh'
		'PipelineUltra'
	]
	@minimalPipelineLevel = @fidelityLevels.indexOf 'PipelineLow'

	init: (@bundle) =>
		@pluginHooks = @bundle.pluginHooks
		@renderer = @bundle.renderer

		@currentFidelityLevel = 0

		@autoAdjust = true
		@screenShotMode = false

		@accumulatedFrames = 0
		@accumulatedDelta = 0
		@timesBelowMinimumFps = 0

		@currentPiwikStat = 0

		@showFidelity = process.env.NODE_ENV is 'development'
		@_setupFidelityDisplay()

		# allow pipeline only if we have the needed extension and a stencil buffer
		# and if the pipeline is enabled in the global config
		usePipeline = @bundle.globalConfig.rendering.usePipeline
		depth = @renderer.threeRenderer.supportsDepthTextures()
		fragDepth = @renderer.threeRenderer.extensions.get 'EXT_frag_depth'
		stencilBuffer = @renderer.threeRenderer.hasStencilBuffer

		capabilities = ''
		capabilities += 'DepthTextures ' if depth?
		capabilities += 'ExtFragDepth ' if fragDepth?
		capabilities += 'stencilBuffer ' if stencilBuffer

		piwikTracking.setCustomSessionVariable 0, 'GpuCapabilities', capabilities

		@pipelineAvailable = usePipeline and depth? and fragDepth? and stencilBuffer
		@noPipelineDecisions = 0

	on3dUpdate: (time, lastFrameTime) =>
		# lastFrameTime is not set the very first time
		return unless lastFrameTime

		@accumulatedDelta += lastFrameTime
		@accumulatedFrames++

		if @accumulatedFrames > accumulationFrames
			average = @accumulatedDelta / @accumulatedFrames
			fps = 1000 / average
			@accumulatedDelta = 0
			@accumulatedFrames = 0
			@_adjustFidelity fps

			@currentPiwikStat++
			if @currentPiwikStat > piwikStatInterval
				@_sendFpsStats fps
				@currentPiwikStat = 0

	_sendFpsStats: (fps) =>
		piwikTracking.trackEvent(
			'FidelityControl', 'FpsAverage',
			FidelityControl.fidelityLevels[@currentFidelityLevel],
			fps
		)

	_adjustFidelity: (fps) =>
		return if @screenShotMode or not @autoAdjust

		if fps < minimalAcceptableFps and @currentFidelityLevel > 0
			# count how often we dropped below the desired fps
			# it has to occur at least @timesBelowThreshold times to cause a change
			@timesBelowMinimumFps++
			return if @timesBelowMinimumFps < timesBelowThreshold

			@timesBelowMinimumFps = 0
			if @currentFidelityLevel is FidelityControl.minimalPipelineLevel
				@noPipelineDecisions++
			@_decreaseFidelity()

		else if fps > upgradeThresholdFps and
		@currentFidelityLevel < FidelityControl.fidelityLevels.length - 1
			# upgrade instantly, but reset downgrade counter
			@timesBelowMinimumFps = 0
			if @currentFidelityLevel is FidelityControl.minimalPipelineLevel - 1
				return if @noPipelineDecisions > maxNoPipelineDecisions
			@_increaseFidelity()

	_increaseFidelity: =>
		# only allow pipeline when we have the extensions needed for it
		return if @currentFidelityLevel is 2 and not @pipelineAvailable

		# Increase fidelity
		@currentFidelityLevel++
		@_setFidelity()

	_decreaseFidelity: =>
		# Decrease fidelity
		@currentFidelityLevel--
		@_setFidelity()

	_setFidelity: =>
		@pluginHooks.setFidelity(
			@currentFidelityLevel, FidelityControl.fidelityLevels, {}
		)

		@renderer.setFidelity(
			@currentFidelityLevel, FidelityControl.fidelityLevels, {}
		)

		@_showFidelity()
		pipelineUltraIndex = FidelityControl.fidelityLevels.indexOf 'PipelineUltra'
		if @currentFidelityLevel is pipelineUltraIndex
			@renderer.render()
			.then @renderer.render
			.then @renderer.render
		else
			@renderer.render()

	getHotkeys: =>
		return {
			title: 'Visual Complexity'
			events: [
				{
					description: 'Increase visual complexity (turns off automatic adjustment)'
					hotkey: 'i'
					callback: @_manualIncrease
				}
				{
					description: 'Decrease visual complexity (turns off automatic adjustment)'
					hotkey: 'd'
					callback: @_manualDecrease
				}
			]
		}

	_manualIncrease: =>
		@autoAdjust = false
		if @currentFidelityLevel < FidelityControl.fidelityLevels.length - 1
			@_increaseFidelity()

	_manualDecrease: =>
		@autoAdjust = false
		@_decreaseFidelity() if @currentFidelityLevel > 0

	_setupFidelityDisplay: =>
		return unless @showFidelity
		@$fidelityDisplay = $('<div class="fidelity-display"></div>')
		$('body').append @$fidelityDisplay
		@_showFidelity()

	_showFidelity: =>
		return unless @showFidelity
		levelAbbreviation = FidelityControl.fidelityLevels[@currentFidelityLevel]
			.match(/[A-Z]/g).join('')
		@$fidelityDisplay.text levelAbbreviation

	# disables pipeline for screenshots
	enableScreenshotMode: =>
		@screenShotMode = true

		level = FidelityControl.fidelityLevels.indexOf 'DefaultHigh'
		@_levelBeforeScreenshot = @currentFidelityLevel
		@currentFidelityLevel = level

		@pluginHooks.setFidelity(
			level, FidelityControl.fidelityLevels
			screenshotMode: true
		)
		@renderer.setFidelity(
			level, FidelityControl.fidelityLevels
			screenshotMode: true
		)

	# resets screenshot mode, restores old fidelity level
	disableScreenshotMode: =>
		@screenShotMode = false

		@currentFidelityLevel = @_levelBeforeScreenshot

		@pluginHooks.setFidelity(
			@currentFidelityLevel, FidelityControl.fidelityLevels
			screenshotMode: false
		)
		@renderer.setFidelity(
			@currentFidelityLevel, FidelityControl.fidelityLevels
			screenshotMode: false
		)

module.exports = FidelityControl
