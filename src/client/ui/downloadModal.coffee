require 'image-map-resizer'

wizardLogicInitialized = false
currentWizardStep = 0
wizardSteps = [
	'#wizardStepIntro'
	'#wizardStepStuds'
	'#wizardStepHoles'
	'#wizardStepFinished'
]
wizardFadeTime = 300

# Scoping variables
$modal = undefined
$sizeSelect = undefined
$legoContent = undefined
$stlContent = undefined
$testStripContent = undefined
$wizardButtons = undefined
$wizardHoleSizeSelect = undefined
$wizardStudSizeSelect = undefined
$wizardStudImage = undefined
$wizardHoleImage = undefined
$wizardTextOverlayStud = undefined
$wizardTextOverlayHole = undefined
$studSizeSelect = undefined
$holeSizeSelect = undefined
$wizardStepObjects = undefined
$textMap = undefined
$numberMap = undefined

alphabeticalList = (i, range) ->
	# A = 65
	return String.fromCharCode 65 + (range + i)

numericalList = (i, range) ->
	return range + i + 1

addOptions = ($select, range, defaultValue, listFunction) ->
	for i in [-range..range]
		caption = listFunction(i, range)
		$select.append(
			$('<option/>')
				.attr('value', i)
				.text(caption)
		)

	$select.val defaultValue

disableWizard = ->
	$sizeSelect.fadeIn wizardFadeTime
	$legoContent.fadeIn wizardFadeTime
	$stlContent.fadeIn wizardFadeTime
	$wizardButtons.fadeOut wizardFadeTime

	for $step in $wizardStepObjects
		$step.fadeOut wizardFadeTime

	currentWizardStep = 0

# Initializes the logic for the test strip wizard
initializeWizard = ($modal) ->
	wizardLogicInitialized = true

	# Bind all jQuery Elements, hide everything
	$wizardButtons = $modal.find('#wizardButtons')
	$nextButton = $wizardButtons.find('#wizardNext')
	$nextButtonText = $nextButton.find('#text')
	$backButton = $wizardButtons.find('#wizardBack')
	$backButtonText = $backButton.find('#text')
	$calibrationSettings = $modal.find('#calibrationSettings')
	$wizardButtons.hide()

	$startWizard = $modal.find('#startWizard')

	# init imagemaps
	initializeImageMaps $modal

	$wizardStepObjects = wizardSteps.map (selector) ->
		$wizardStep = $modal.find(selector)
		$wizardStep.hide()
		return $wizardStep

	$sizeSelect = $modal.find('#sizeSelect')

	applyCurrentWizardStep = ->
		if currentWizardStep is wizardSteps.length or
		currentWizardStep is -1
			# Finish wizard

			# Apply data values
			studVal = $wizardStudSizeSelect.val()
			$studSizeSelect
				.find("option[value=#{studVal}]")
				.attr('selected', true)
			holeVal = $wizardHoleSizeSelect.val()
			$holeSizeSelect
				.find("option[value=#{holeVal}]")
				.attr('selected', true)

			# Trigger intput event - so that
			# the selected settings get stored fpr csg
			$studSizeSelect.trigger 'input'
			$holeSizeSelect.trigger 'input'

			disableWizard()
		else
			$wizardStepObjects[currentWizardStep]
			.fadeIn wizardFadeTime, ->
				# Trigger image map resize after images are loaded
				# and shown, since image size is not set accurately
				# before
				updateImageMapSize()

		# Update calibration preview on last step
		if currentWizardStep is wizardSteps.length - 1
			size = $wizardStudSizeSelect
				.find('option:selected')
				.html() +
				' ' +
				$wizardHoleSizeSelect
				.find('option:selected')
				.html()
			$calibrationSettings.html size

	updateButtonCaptions = ->
		if currentWizardStep is wizardSteps.length - 1
			$nextButtonText.html 'Finish'
		else
			$nextButtonText.html 'Next step'

		if currentWizardStep is 0
			$backButtonText.html 'Cancel wizard'
		else
			$backButtonText.html 'Go back'

	# Bind button logic
	$nextButton.click ->
		$wizardStepObjects[currentWizardStep]
		.fadeOut wizardFadeTime, ->
			currentWizardStep++
			applyCurrentWizardStep()
			updateButtonCaptions()

	$backButton.click ->
		$wizardStepObjects[currentWizardStep]
		.fadeOut wizardFadeTime, ->
			currentWizardStep--
			applyCurrentWizardStep()
			updateButtonCaptions()

	setHoleImageToSelectValue = ->
		id = $wizardHoleSizeSelect.find('option:selected').html()
		$wizardHoleImage.attr 'src', "img/testStripWizard/holes/#{id}.png"

	setStudImageToSelectValue = ->
		id = $wizardStudSizeSelect.find('option:selected').html()
		$wizardStudImage.attr 'src', "img/testStripWizard/studs/#{id}.png"

	# Update image on selection change
	$wizardHoleSizeSelect.on 'change', ->
		setHoleImageToSelectValue()

	$wizardStudSizeSelect.on 'change', ->
		setStudImageToSelectValue()

	# Reset image when leaving the selection area
	$wizardTextOverlayHole.mouseleave ->
		setHoleImageToSelectValue()

	$wizardTextOverlayStud.mouseleave ->
		setStudImageToSelectValue()

	# Fade out size select, start wizard on click
	$startWizard.click ->
		currentWizardStep = 0
		updateButtonCaptions()
		$legoContent.fadeOut wizardFadeTime
		$stlContent.fadeOut wizardFadeTime
		$sizeSelect.fadeOut wizardFadeTime, ->
			$wizardStepObjects[0].fadeIn wizardFadeTime
			$wizardButtons.fadeIn wizardFadeTime

initializeImageMaps = ($modal) ->
	$wizardStudImage = $modal.find '#wizardStudImage'
	$wizardHoleImage = $modal.find '#wizardHoleImage'
	$wizardTextOverlayHole = $modal.find '#wizardTextOverlayHole'
	$wizardTextOverlayStud = $modal.find '#wizardTextOverlayStud'

	$textMap = $modal.find('#textMap')
	$textMap.imageMapResize()
	$numberMap = $modal.find('#numberMap')
	$numberMap.imageMapResize()

	$textMap.find('area').each ->
		thisArea  = $(@)
		id = thisArea.attr 'id'
		thisArea.hover ->
			$wizardStudImage.attr 'src', "img/testStripWizard/studs/#{id}.png"
		thisArea.click ->
			$wizardStudImage.attr 'src', "img/testStripWizard/studs/#{id}.png"
			$wizardStudSizeSelect
			.find('option')
			.filter -> return $(@).html() is id
			.attr('selected', true)

	$numberMap.find('area').each ->
		thisArea  = $(@)
		id = thisArea.attr 'id'
		thisArea.hover ->
			$wizardHoleImage.attr 'src', "img/testStripWizard/holes/#{id}.png"
		thisArea.click ->
			$wizardHoleImage.attr 'src', "img/testStripWizard/holes/#{id}.png"
			$wizardHoleSizeSelect
			.find('option')
			.filter -> return $(@).html() is id
			.attr('selected', true)

updateImageMapSize = ->
	$textMap.imageMapResize()
	$numberMap.imageMapResize()

getModal = ({testStrip, stl, lego, steps} = {}) ->
	$modal ?= $('#downloadModal')
	$legoContent ?= $modal.find('#legoContent')
	$stlContent ?= $modal.find('#stlContent')
	$testStripContent ?= $modal.find('#testStripContent')

	if lego
		$legoContent.show()
	else
		$legoContent.hide()

	if stl
		$stlContent.show()
	else
		$stlContent.hide()

	if testStrip
		$testStripContent.show()

		# Prefill select values
		$studSizeSelect = $modal.find '#studSizeSelect'
		$wizardStudSizeSelect = $modal.find '#wizardStudSizeSelect'
		addOptions $studSizeSelect, steps, 0, alphabeticalList
		addOptions $wizardStudSizeSelect, steps, 0, alphabeticalList

		$holeSizeSelect = $modal.find '#holeSizeSelect'
		$wizardHoleSizeSelect = $modal.find '#wizardHoleSizeSelect'
		addOptions $holeSizeSelect, steps, 0, numericalList
		addOptions $wizardHoleSizeSelect, steps, 0, numericalList
	else
		$testStripContent.hide()

	if not wizardLogicInitialized
		initializeWizard $modal

	# Reset wizard when closing the modal
	$modal.on 'hidden.bs.modal', ->
		disableWizard()

	return $modal

module.exports = getModal
