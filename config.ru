require 'rubygems'
require 'sinatra'
require 'rack/reloader'
require './myapp'

set :environment, :development
set :reload_templates, true
use Rack::Reloader, 0 if development?
run Sinatra::Application
