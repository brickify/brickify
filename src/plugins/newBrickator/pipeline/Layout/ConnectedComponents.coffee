DataHelper = require '../DataHelper'

# Connected components using the connected component labelling algorithm
module.exports.findConnectedComponents = (
		bricks,
		ignoreArticulationPoints = false) =>
	labels = []
	id = 0

	# First pass
	bricks.forEach (brick) ->
		if ignoreArticulationPoints and brick.isSignificantAP
			brick.label = null
			return

		conBricks = brick.connectedBricks()
		conLabels = new Set()

		conBricks.forEach (conBrick) ->
			if ignoreArticulationPoints and conBrick.isSignificantAP
						return
			conLabels.add conBrick.label if conBrick.label?

		# Found neighbors that are already labelled
		if conLabels.size > 0
			smallestLabel = DataHelper.smallestElement conLabels
			# Assign label to this brick
			brick.label = labels[smallestLabel]
			for i in [0..labels.length]
				if conLabels.has labels[i]
					labels[i] = labels[smallestLabel]

		# No neighbor has a label
		else
			brick.label = id
			labels[id] = id
			id++

	# Second pass - applying labels
	bricks.forEach (brick) ->
		brick.label = labels[brick.label]

	# Count number of components
	finalLabels = new Set()
	for label in labels
		finalLabels.add label
	numberOfComponents = finalLabels.size

	return numberOfComponents

module.exports.bricksOnComponentInterfaces = (bricks) =>
	bricksOnInterfaces = new Set()

	bricks.forEach (brick) ->
		neighborsXY = brick.getNeighborsXY()
		neighborsXY.forEach (neighbor) ->
			if neighbor.label != brick.label
				bricksOnInterfaces.add neighbor
				bricksOnInterfaces.add brick

	return bricksOnInterfaces
