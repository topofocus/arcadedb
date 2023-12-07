module Arcade

end

require "arcade/version"
require "dry/configurable"
require "dry/struct"
require "dry/core/class_builder"
require "dry/core/class_attributes"
require 'json'

module Types
  include Dry.Types()
end
require 'yaml'
require 'securerandom'
require 'httpx'
require 'arcade/errors'
require_relative '../lib/support/object'
require_relative '../lib/support/string'
require_relative '../lib/support/class'
require_relative '../lib/support/sql'
require_relative '../lib/support/model'
require_relative '../lib/arcade/logging'
require_relative '../lib/config'
require_relative '../lib/support/conversions'
require_relative '../lib/arcade/api/primitives'
require_relative '../lib/arcade/api/operations'
require_relative '../lib/arcade/base'
require_relative '../lib/arcade/database'
require_relative '../lib/arcade/match'
require_relative '../lib/init'
require_relative "../lib/models"
require_relative '../lib/query'
require_relative '../lib/railtie'  if defined? Rails::Railtie

