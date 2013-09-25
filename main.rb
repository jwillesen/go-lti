require 'bundler'
Bundler.require
require 'oauth/request_proxy/rack_request'

enable :sessions
set :protection, :except => :frame_options

require_relative 'app/application.rb'
require_relative 'app/routes.rb'

