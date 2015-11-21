require '../common/polyfills'

http = require 'http'
path = require 'path'
url = require 'url'
fs = require 'fs'

bootstrap = require 'bootstrap-styl'
winston = require 'winston'
express = require 'express'
bodyParser = require 'body-parser'
compress = require 'compression'
morgan = require 'morgan'
errorHandler = require 'errorhandler'
favicon = require 'serve-favicon'
stylus = require 'stylus'
nib = require 'nib'
exec = require('child_process').exec
http = require 'http'

yaml = require 'js-yaml'
# Support mixing .coffee and .js files in brickify-project
coffeeify = require 'coffeeify'
# Load yaml configuration into javascript file
browserifyData = require 'browserify-data'
envify = require 'envify'
# Load strings with browserify
stringify = require 'stringify'
browserify = require 'browserify-middleware'
urlSessions = require './urlSessions'
cookieParser = require 'cookie-parser'

# Make logger available to other modules.
# Must be instantiated before requiring bundled modules
winston.loggers.add 'log',
	console:
		level: loggingLevel
		colorize: true
log = winston.loggers.get('log')

pluginLoader = require './pluginLoader'
app = require '../../routes/app'
landingPage = require '../../routes/landingpage'
models = require '../../routes/models'
dataPackets = require '../../routes/dataPackets'
sharelinkGen = require '../../routes/share'
globalConfig = yaml.safeLoad(
	fs.readFileSync path.resolve(__dirname, '../common/globals.yaml')
)
webapp = express()

# Express assumes that no env means develop.
# Therefore override it to make it clear for all
developmentMode = webapp.get('env') is 'development'
if developmentMode
	process.env.NODE_ENV = 'development'
	log.info 'development mode activated'
else
	log.info 'production mode activated'

testMode = webapp.get('env') is 'test'

loggingLevel = if developmentMode then 'debug' else 'warn'
loggingLevel = 'error' if testMode

browserify.settings({
	transform: [stringify(['.scad']), coffeeify, browserifyData, envify]
})

server = http.createServer(webapp)
port = process.env.NODEJS_PORT or process.env.PORT or 3000
ip = process.env.NODEJS_IP or '127.0.0.1'
sessionSecret = process.env.BRICKIFY_SESSION_SECRET or 'brickifySessionSecret!'

module.exports.setupRouting = ->
	webapp.set 'hostname', if developmentMode then "localhost:#{port}" else
		process.env.HOSTNAME or 'brickify.it'

	webapp.set 'views', path.normalize 'views'
	webapp.set 'view engine', 'jade'

	webapp.use favicon(path.normalize 'public/img/favicon.png', {maxAge: 1000})

	webapp.use compress()

	webapp.use stylus.middleware(
		src: 'public',
		compile: (string, path) ->
			stylus string
			.set 'filename', path
			.set 'compress', !developmentMode
			.set 'sourcemap', {
				comment: developmentMode
				inline: true # Generating an extra map file doesn't seem to work
			}
			.set 'include css', true
			.use nib()
			.use bootstrap()
			# Ugly because of github.com/LearnBoost/stylus/issues/1828
			.define 'backgroundColor', '#' + ('000000' +
				globalConfig.colors.background.toString 16).slice -6
	)

	webapp.use (req, res, next) ->
		res.locals.app = webapp
		next()

	shared = [
		'blueimp-md5'
		'bootstrap'
		'clone'
		'es6-promise'
		'filesaver.js'
		'jquery'
		'mousetrap'
		'operative'
		'PEP'
		'path'
		'three'
		'three-pointer-controls'
		'zeroclipboard'
	]
	webapp.get '/shared.js', browserify(shared, {
		cache: true
		precompile: true
		noParse: shared
	})

	webapp.get '/app.js', browserify('src/client/main.coffee', {
		extensions: ['.coffee']
		external: shared
		insertGlobals: developmentMode
	})

	webapp.get '/landingpage.js', browserify('src/client/landingpage.coffee', {
		extensions: ['.coffee']
		external: shared
		insertGlobals: developmentMode
	})

	fontAwesomeRegex = /\/fonts\/fontawesome-.*/
	webapp.get fontAwesomeRegex, express.static('node_modules/font-awesome/')

	webapp.use express.static('public')
	webapp.use('/node_modules', express.static('node_modules'))

	if developmentMode
		webapp.use morgan 'dev',
			stream:
				write: (str) ->
					log.info str.substring(0, str.length - 1)
	else
		webapp.use morgan 'combined',
			stream:
				write: (str) ->
					log.info str.substring(0, str.length - 1)

	webapp.use cookieParser()
	webapp.use urlSessions.middleware

	jsonParser = bodyParser.json {limit: '100mb'}
	urlParser = bodyParser.urlencoded {extended: true, limit: '100mb'}
	rawParser = bodyParser.raw({limit: '100mb'})

	webapp.get '/', landingPage.getLandingpage
	webapp.get '/contribute', landingPage.getContribute
	webapp.get '/team', landingPage.getTeam
	webapp.get '/imprint', landingPage.getImprint
	webapp.get '/educators', landingPage.getEducators
	webapp.get '/app', app
	webapp.get '/share', sharelinkGen

	webapp.route '/model/:identifier'
		.head models.exists
		.get models.get
		.put rawParser, models.store

	webapp.post '/datapacket', urlParser, dataPackets.create
	webapp.route '/datapacket/:id'
		.head dataPackets.exists
		.get dataPackets.get
		.put jsonParser, dataPackets.put
		.delete dataPackets.delete

	webapp.post '/updateGitAndRestart', jsonParser, (request, response) ->
		if request.body.ref?
			ref = request.body.ref
			if not (ref.indexOf('develop') >= 0 or ref.indexOf('master') >= 0)
				log.debug 'Got a server restart command, but "ref" ' +
					'did not contain develop or master'
				response.send ''
				return
		else
			log.warn 'Got a server restart command without a "ref" ' +
				'json member from ' + request.connection.remoteAddress
			response.send ''
			return

		response.send ''
		exec '../updateAndRestart.sh', (error, out, code) ->
			if error
				log.warn "Error while updating server: #{error}"

	pluginLoader.loadPlugins path.resolve(__dirname, '../plugins')

	if developmentMode
		webapp.use errorHandler()

	webapp.use (req, res) ->
		res
		.status 404
		.render '404'

	return module.exports

module.exports.startServer = (_port, _ip) ->
	port = _port || port
	ip = _ip || ip

	server.on 'error', (error) ->
		if error.code is 'EADDRINUSE'
			log.error "Another Server is already listening on #{ip}:#{port}"
		else
			log.error 'Server could not be started:', error

	server.listen port, ip, ->
		log.info "Server is listening on #{ip}:#{port}"

	return server
