lastTarget = null

module.exports.init = (callback) ->
	target = document.body
	overlay = addOverlay target
	bindDropHandler target, overlay, callback

addOverlay = (target) ->
	overlay = document.createElement 'div'
	overlay.className = 'modal-backdrop'
	overlay.id = 'dropoverlay'
	overlay.style.opacity = 0
	overlay.style.transition = 'opacity .1s ease-in-out'
	overlay.innerHTML =
	'<div id="dropborder">
		<div id="dropinfo" class="text-center">drop here</div>
	</div>'
	target.appendChild overlay
	return overlay

bindDropHandler = (target, overlay, callback) ->
	target.addEventListener 'drop', (event) ->
		hideOverlay overlay
		callback event.dataTransfer.files
		stopEvent event
	target.addEventListener 'dragover', (event) ->
		stopEvent event
	target.addEventListener 'dragenter', (event) ->
		stopEvent event
		showOverlay overlay
		lastTarget = event.target
	target.addEventListener 'dragleave', (event) ->
		return unless event.target is lastTarget
		stopEvent event
		hideOverlay overlay

showOverlay = (overlay) ->
	overlay.style.opacity = '0.8'

hideOverlay = (overlay) ->
	overlay.style.opacity = '0'

stopEvent = (event) ->
	event.preventDefault()
	event.stopPropagation()
