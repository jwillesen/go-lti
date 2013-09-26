require 'bundler'
Bundler.require
require 'oauth/request_proxy/rack_request'
require 'ims/lti/extensions'

require 'fileutils'
require 'securerandom'
require 'uri'

enable :sessions
#enable :logging
set :protection, :except => [:frame_options]
# getting these log warnings:
#   attack prevented by Rack::Protection::HttpOrigin
#   attack prevented by Rack::Protection::RemoteToken
# but it is still working -- need to figure out the security for these things
#set :protection, :except => [:frame_options, :http_origin, :remote_token]
# to turn off the development warning, should be secure in production
set :session_secret, '~~~very_secure~~~'

require_relative 'app/application.rb'
require_relative 'app/routes.rb'

