Grid = require './Grid'

module.exports = class VolumeFiller
	fillGrid: (grid, gridPOJO, options, progressCallback) ->
		# fills spaces in the grid. Goes up from z=0 to z=max and looks for
		# voxels facing downwards (start filling), stops when it sees voxels
		# facing upwards

		callback = (message) =>
			if message.state is 'progress'
				progressCallback message.progress
			else # if state is 'finished'
				@terminate()
				grid.fromPojo message.data
				@resolve grid: grid

		@worker = @getWorker()
		@worker.fillGrid(
			gridPOJO
			callback
		)

		return new Promise (@resolve, reject) => return

	terminate: =>
		@worker?.terminate()
		@worker = null

	getWorker: ->
		return @worker if @worker?
		return operative {
			fillGrid: (grid, callback) ->
				numVoxelsX = grid.length
				numVoxelsY = 0
				numVoxelsZ = 0
				for x, voxelPlane of grid
					numVoxelsY = Math.max numVoxelsY, voxelPlane.length
					for y, voxelColumn of voxelPlane
						numVoxelsZ = Math.max numVoxelsZ, voxelColumn.length

				@resetProgress()
				for x, voxelPlane of grid
					x = parseInt x
					for y, voxelColumn of voxelPlane
						y = parseInt y
						@fillUp grid, x, y, numVoxelsZ
						@postProgress callback, x, y, numVoxelsX, numVoxelsY
				callback state: 'finished', data: grid

			fillUp: (grid, x, y, numVoxelsZ) ->
				#fill up from z=0 to z=max
				insideModel = false
				z = 0
				currentFillVoxelQueue = []

				while z <= numVoxelsZ
					if grid[x][y][z]?
						# current voxel already exists (shell voxel)
						dir = grid[x][y][z]

						if dir > 0
							#fill up voxels and leave model
							for v in currentFillVoxelQueue
								@setVoxel grid, v, 0
							insideModel = false
						else if dir < 0
							# re-entering model if inside? that seems odd. empty current fill queue
							if insideModel
								currentFillVoxelQueue = []
							#entering model
							insideModel = true
						else
							#if not sure, fill up (precautious people might leave this out?)
							for v in currentFillVoxelQueue
								@setVoxel grid, v, 0
							currentFillVoxelQueue = []

							insideModel = false
					else
						#voxel does not yet exist. create if inside model
						if insideModel
							currentFillVoxelQueue.push {x: x, y: y, z: z}
					z++

			setVoxel: (grid, {x: x, y: y, z: z}, voxelData) ->
				grid[x] ?= []
				grid[x][y] ?= []
				grid[x][y][z] ?= []
				grid[x][y][z] = voxelData

			resetProgress: ->
				@lastProgress = 0

			postProgress: (callback, x, y, numVoxelsX, numVoxelsY) ->
				progress = Math.round(
					100 * ((x - 1) * numVoxelsY + y - 1) / numVoxelsX / numVoxelsY)
				return unless progress > @lastProgress
				@lastProgress = progress
				callback state: 'progress', progress: progress

		}
