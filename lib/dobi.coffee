# dependencies
Firebase = require 'firebase'
fs = require 'fs'
open = require 'open'
optimist = require 'optimist'
path = require 'path'
readline = require 'readline'

# usage
USAGE = """
Usage: dobi <command> [command-specific-options]

where <command> [command-specific-options] is one of:
  create <my-app>                 create a new app
  deploy <my-app>                 deploy an app (COMING SOON)
  init                            initialize a workspace
  install <my-app> <site-slug>    create a site using your app
  login                           authenticate your user
  open <site-slug>                open a site
  run                             run a development server
  start                           daemonize a development server
  stop                            stop a daemonized development server
  version                         check your dobi version
  whoami                          check your authentication status
"""

# constants
CWD = process.cwd()
FIREBASE_URL = 'https://lessthan3.firebaseio.com'
USER_HOME = process.env.HOME or process.env.HOMEPATH or process.env.USERPROFILE
USER_CONFIG_PATH = "#{USER_HOME}/.lt3_config"

# helpers
rl = readline.createInterface {
  input: process.stdin
  output: process.stdout
}

exit = (msg) ->
  log msg if msg
  process.exit()

getWorkspacePath = (current, next) ->
  [current, next] = [CWD, current] if not next
  fs.exists path.join(current, 'dobi.json'), (exists) ->
    if exists
      next current
    else
      parent = path.join current, '..'
      return next null if parent is current
      getWorkspacePath parent, next

log = (msg) ->
  console.log "[dobi] #{msg}"

login = (require_logged_in, next) ->
  [require_logged_in, next] = [false, require_logged_in] unless next

  log 'authenticating user'
  readUserConfig (config) ->
    if config.user
      next config
    else if not require_logged_in
      next null
    else
      log 'not logged in: must authenticate'
      log 'opening login portal in just a few moments'
      setTimeout ( ->
        open 'http://www.dobi.io/auth'
        rl.question "Enter Token: ", (token) ->
          exit 'must specify token' unless token
          fb = new Firebase FIREBASE_URL
          fb.auth token, (err, data) ->
            exit 'invalid token' if err
            config.user = data.auth
            config.token = token
            config.token_expires = data.expires
            saveUserConfig config, ->
              next config
      ), 3000

readUserConfig = (next) ->
  fs.exists USER_CONFIG_PATH, (exists) ->
    if exists
      fs.readFile USER_CONFIG_PATH, 'utf8', (err, data) ->
        exit 'unable to read user config' if err
        next JSON.parse data
    else
      saveUserConfig {}, ->
        next {}

saveUserConfig = (data, next) ->
  config = JSON.stringify data
  fs.writeFile USER_CONFIG_PATH, config, 'utf8', (err) ->
    exit 'unable to write user config' if err
    next()

# get arguments and options
argv = optimist.argv._
command = argv[0]
args = argv[1...argv.length]
opts = optimist.argv

switch command

  # create a new app
  when 'create'
    exit 'not available yet'

  # deploy an app
  when 'deploy'
    exit 'not available yet'

  # initialize a workspace
  when 'init'
    getWorkspacePath (workspace) ->
      exit "already in a workspace: #{workspace}" if workspace
      fs.writeFile path.join(CWD, 'dobi.json'), JSON.stringify({
        created: Date.now()
      }), (err) ->
        exit 'failed to create workspace config' if err
        fs.mkdir path.join(CWD, 'pkg'), (err) ->
          exit 'failed to create pkg directory' if err
          exit "workspace successfully created at: #{CWD}"

  # create a site using your app
  when 'install'
    exit 'not available yet'

  # authenticate your user
  when 'login'
    login true, (config) ->
      exit JSON.stringify user, null, 2 if config.user
      exit 'not logged in. try "dobi login"'

  # open a site
  when 'open'
    url = 'http://www.lessthan3.com'
    url += "/#{arg}" for arg in args
    open url
    exit()

  # run a development server
  when 'run'
    exit 'not available yet'

  # daemonize a development server
  when 'start'
    login (config) ->
      ((next) ->
        if config.pid
          log "killing running server: #{config.pid}" if config.pid
          try process.kill config.pid, 'SIGHUP'
          config.pid = null
          saveUserConfig config, next
        else
          next()
      )( ->
        log "starting process"
        cp = require 'child_process'
        child = cp.spawn 'coffee', ["#{__dirname}/dobi.coffee", 'run'], {
          detached: true
          stdio: [ 'ignore', 'ignore', 'ignore']
        }
        child.unref()
        config.pid = child.pid
        log "server running at: #{config.pid}"
        saveUserConfig config, exit
      )

  # daemonize a development server
  when 'stop'
    login (config) ->
      return exit() if not config.pid
      try process.kill config.pid, 'SIGHUP'
      config.pid = null
      saveUserConfig config, exit

  # check your dobi version
  when 'version'
    pkg = require path.join '..', 'package'
    exit pkg.version

  # check your authentication status
  when 'whoami'
    login (config) ->
      exit JSON.stringify user, null, 2 if config.user
      exit 'not logged in. try "dobi login"'

  # invalid command
  else
    exit "invalid command: #{command}"
