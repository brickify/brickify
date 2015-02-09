OptimizedModel = require '../../common/OptimizedModel'
Vec3 = require '../../common/Vec3'

# Parses the content of a stl file.
# if optimize is set to true, an optimized mesh is returned
# else, a stl representation is returned, which should not be
# used for further processing
module.exports.parse = (fileContent, errorCallback,
												optimize = true,
												cleanse = true) ->
	model = null

	if fileContent.length == 0
		return null

	startsWithSolid = false
	hasFacet = false
	hasVertex = false
	if fileContent.indexOf('solid') == 0
		startsWithSolid = true
		if fileContent.indexOf('facet') > 0
			hasFacet = true
		if fileContent.indexOf('vertex') > 0
			hasVertex = true

	if !startsWithSolid
		#Import binary, since 'solid' is reserved for ascii
		model = parseBinary	toArrayBuffer fileContent
	else
		#Okay, it should be ascii. does it contain other keywords?
		if hasFacet and hasVertex
			model = parseAscii fileContent
		else
			#No facet and vertex? maybe it's a binary
			#that uses the solid keyword (it is not allowed to do so!)
			model = parseBinary	toArrayBuffer fileContent

	if model.importErrors.length > 0
		if errorCallback?
			errorCallback model.importErrors

	if optimize
		return optimizeModel model, cleanse
	return model

toArrayBuffer = (buf) ->
	if typeof buf is 'string'
		array_buffer = new Uint8Array(buf.length)
		i = 0

		while i < buf.length
			array_buffer[i] = buf.charCodeAt(i) & 0xff # implicitly assumes little-endian
			i++
		return array_buffer.buffer or array_buffer
	else
		return buf

# Parses an stl ASCII file to the internal representation
parseAscii = (fileContent) ->
	astl = new AsciiStl(fileContent)
	stl = new Stl()

	currentPoly = null
	while !astl.reachedEnd()
		cmd = astl.nextText()
		cmd = cmd.toLowerCase()

		switch cmd
			when 'solid'
				astl.nextText() #skip description of model
			when 'facet'
				if (currentPoly?)
					stl.addError 'Beginning a facet without ending the previous one'
					stl.addPolygon currentPoly
					currentPoly = null
				currentPoly = new StlPoly()
			when 'endfacet'
				if !(currentPoly?)
					stl.addError 'Ending a facet without beginning it'
				else
					stl.addPolygon currentPoly
					currentPoly = null
			when 'normal'
				nx = parseFloat astl.nextText()
				ny = parseFloat astl.nextText()
				nz = parseFloat astl.nextText()

				if (!(nx?) || !(ny?) || !(nz?))
					stl.addError "Invalid normal definition: (#{nx}, #{ny}, #{nz})"
				else
					if not (currentPoly?)
						stl.addError 'normal definition without an existing polygon'
						currentPoly = new StlPoly()
					currentPoly.setNormal new Vec3(nx,ny,nz)
			when 'vertex'
				vx = parseFloat astl.nextText()
				vy = parseFloat astl.nextText()
				vz = parseFloat astl.nextText()

				if (!(vx?) || !(vy?) || !(vz?))
					stl.addError "Invalid vertex definition: (#{nx}, #{ny}, #{nz})"
				else
					if not (currentPoly?)
						stl.addError 'point definition without an existing polygon'
						currentPoly = new StlPoly()
					currentPoly.addPoint new Vec3(vx, vy, vz)
	return stl

# Parses a binary stl file to the internal representation
parseBinary = (fileContent) ->
	stl = new Stl()
	reader = new DataView(fileContent,80)
	numTriangles = reader.getUint32 0, true

	#check if file size matches with numTriangles
	datalength = fileContent.byteLength - 80 - 4
	polyLength = 50
	calcDataLength = polyLength * numTriangles

	if (calcDataLength > datalength)
		stl.addError 'Calculated length of triangle data does not match filesize,
		triangles might be missing'

	binaryIndex = 4
	while (binaryIndex - 4) + polyLength <= datalength
		poly = new StlPoly()
		nx = reader.getFloat32 binaryIndex, true
		binaryIndex += 4
		ny = reader.getFloat32 binaryIndex, true
		binaryIndex += 4
		nz = reader.getFloat32 binaryIndex, true
		binaryIndex += 4
		poly.setNormal new Vec3(nx, ny, nz)
		for i in [0..2]
			vx = reader.getFloat32 binaryIndex, true
			binaryIndex += 4
			vy = reader.getFloat32 binaryIndex, true
			binaryIndex += 4
			vz = reader.getFloat32 binaryIndex, true
			binaryIndex += 4
			poly.addPoint new Vec3(vx,vy,vz)
		#skip uint 16
		binaryIndex += 2
		stl.addPolygon poly

	return stl


# Optimizes the internal stl model representation by removing duplicate points
# and creating an indexed face list
# Takes the face normals from the stl and calculates vertex normals
# if cleanseStl is set to true, invalid polygons will be removed and
# the face normals will be recalculated before processing the model
# further
optimizeModel = (importedStl, cleanseStl = true,
                 pointDistanceEpsilon = 0.0001) ->
	if cleanseStl
		importedStl.cleanse()

	vertexnormals = []
	faceNormals = []
	index = [] #vert1 vert2 vert3

	octreeRoot = new Octree(pointDistanceEpsilon)
	biggestPointIndex = -1

	for poly in importedStl.polygons
		#add points if they don't exist, or get index of these points
		indices = [-1,-1,-1]
		for vertexIndex in [0..2]
			point = poly.points[vertexIndex]
			newPointIndex = octreeRoot.add point,
				new Vec3(poly.normal.x, poly.normal.y, poly.normal.z), biggestPointIndex
			indices[vertexIndex] = newPointIndex
			if newPointIndex > biggestPointIndex
				biggestPointIndex = newPointIndex

		index.push indices[0]
		index.push indices[1]
		index.push indices[2]
		faceNormals.push poly.normal.x
		faceNormals.push poly.normal.y
		faceNormals.push poly.normal.z

	#get a list out of the octree
	vertexPositions = new Array((biggestPointIndex + 1) * 3)
	octreeRoot.forEach (node) ->
		v = node.vec
		i = node.index * 3
		vertexPositions[i] = v.x
		vertexPositions[i + 1] = v.y
		vertexPositions[i + 2] = v.z

	#average all vertexnormals
	avgNormals = new Array((biggestPointIndex + 1) * 3)
	octreeRoot.forEach (node) ->
		normalList = node.normalList
		i = node.index * 3
		avg = new Vec3(0,0,0)
		for normal in normalList
			normal = normal.normalized()
			avg = avg.add normal
		avg = avg.normalized()
		avgNormals[i] = avg.x
		avgNormals[i + 1] = avg.y
		avgNormals[i + 2] = avg.z

	optimized = new OptimizedModel()
	optimized.positions = vertexPositions
	optimized.indices = index
	optimized.vertexNormals = avgNormals
	optimized.faceNormals = faceNormals

	return optimized
module.exports.optimizeModel = optimizeModel

class AsciiStl
	constructor: (fileContent) ->
		@content = fileContent
		@index = 0
		@whitespaces = [' ', '\r', '\n', '\t', '\v', '\f']
	nextText: () ->
		@skipWhitespaces()
		cmd = @readUntilWhitespace();
	skipWhitespaces: () ->
		#moves the index to the next non whitespace character
		skip = true
		while skip
			if (@currentCharIsWhitespace() && !@reachedEnd())
				@index++
			else
				skip = false
	currentChar: () ->
		return @content[@index]
	currentCharIsWhitespace: () ->
		for space in @whitespaces
			if @currentChar() == space
				return true
		return false
	readUntilWhitespace: () ->
		readContent = ''
		while (!@currentCharIsWhitespace() && !@reachedEnd())
			readContent = readContent + @currentChar()
			@index++
		return readContent
	reachedEnd: () ->
		return (@index == @content.length)

# An unoptimized data structure that holds the same content as a stl file
class Stl
	constructor: () ->
		@polygons = []
		@importErrors = []
	addPolygon: (stlPolygon) ->
		@polygons.push(stlPolygon)
	addError: (string) ->
		@importErrors.push string
	removeInvalidPolygons: (infoResult) ->
		newPolys = []
		deletedPolys = 0

		for poly in @polygons
			#check if it has 3 vectors
			if poly.points.length == 3
				newPolys.push poly

		if (infoResult)
			deletedPolys = @polygons.length - newPolys.length

		@polygons = newPolys
		return deletedPolys
	recalculateNormals: (infoResult) ->
		newNormals = 0
		for poly in @polygons
			d1 = poly.points[1].minus poly.points[0]
			d2 = poly.points[2].minus poly.points[0]
			n = d1.crossProduct d2
			n = n.normalized()

			if infoResult
				if poly.normal?
					dist = poly.normal.euclideanDistanceTo n
					if (dist > 0.001)
						newNormals++
				else
					newNormals++

			poly.normal = n
		return newNormals
	cleanse: (infoResult = false) ->
		result = {}
		result.deletedPolygons = @removeInvalidPolygons infoResult
		result.recalculatedNormals = @recalculateNormals infoResult
		return result
module.exports.Stl = Stl

class StlPoly
	constructor: () ->
		@points = []
		@normal = new Vec3(0,0,0)
	setNormal: (@normal) ->
		return undefined
	addPoint: (p) ->
		@points.push p
module.exports.Stlpoly = StlPoly

class Octree
	constructor: (@distanceDelta) ->
		@index = -1
		@vec = null
		@normalList = null
		@bxbybz = null #child that has a _b_igger x,y and z
		@bxbysz = null
		@bxsybz = null
		@bxsysz = null
		@sxbybz = null
		@sxbysz = null
		@sxsybz = null
		@sxbysz = null
	forEach: (callback) ->
		callback(@)
		if @bxbybz?
			@bxbybz.forEach callback
		if @bxbysz?
			@bxbysz.forEach callback
		if @bxsybz?
			@bxsybz.forEach callback
		if @bxsysz?
			@bxsysz.forEach callback
		if @sxbybz?
			@sxbybz.forEach callback
		if @sxbysz?
			@sxbysz.forEach callback
		if @sxsybz?
			@sxsybz.forEach callback
		if @sxsysz?
			@sxsysz.forEach callback
	add: (point, normal, biggestUsedIndex = 0) ->
		if @vec == null
			#if the tree is not initialized, set the vector as first element
			@vec = point
			@normalList = []
			@normalList.push normal
			@index = biggestUsedIndex + 1
			return @index
		else if (point.euclideanDistanceTo @vec) < @distanceDelta
			#if the points are near together, return own index
			@normalList.push normal
			return @index
		else
			#init the subnode this leaf belongs to
			if point.x > @vec.x
				#bx....
				if point.y > @vec.y
					#bxby..
					if point.z > @vec.z
						if (!(@bxbybz?))
							@bxbybz = new Octree(@distanceDelta)
						return @bxbybz.add point, normal, biggestUsedIndex
					else
						if (!(@bxbysz?))
							@bxbysz = new Octree(@distanceDelta)
						return @bxbysz.add point, normal, biggestUsedIndex
				else
					#bxsy..
					if point.z > @vec.z
						if (!(@bxsybz?))
							@bxsybz = new Octree(@distanceDelta)
						return @bxsybz.add point, normal, biggestUsedIndex
					else
						if (!(@bxsysz?))
							@bxsysz = new Octree(@distanceDelta)
						return @bxsysz.add point, normal, biggestUsedIndex
			else
				#sx....
				if point.y > @vec.y
					#sxby..
					if point.z > @vec.z
						if (!(@sxbybz?))
							@sxbybz = new Octree(@distanceDelta)
						return @sxbybz.add point, normal, biggestUsedIndex
					else
						if (!(@sxbysz?))
							@sxbysz = new Octree(@distanceDelta)
						return @sxbysz.add point, normal, biggestUsedIndex
				else
					#sxsy..
					if point.z > @vec.z
						if (!(@sxsybz?))
							@sxsybz = new Octree(@distanceDelta)
						return @sxsybz.add point, normal, biggestUsedIndex
					else
						if (!(@sxsysz?))
							@sxsysz = new Octree(@distanceDelta)
						return @sxsysz.add point, normal, biggestUsedIndex