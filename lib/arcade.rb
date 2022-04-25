module Arcade

end

require "arcade/api/version"
require "dry/configurable"
require "dry/struct"
require "dry/core/class_builder"
require "dry/core/class_attributes"

module Types
  include Dry.Types()
end
require 'pg'          #  ruby postgres driver
#require 'mini_sql'
#require 'sequel'
#require 'httparty'
require 'yaml'
require 'typhoeus'    #  curl library
require_relative '../lib/errors'
require_relative '../lib/support/object'
require_relative '../lib/support/string'
require_relative '../lib/support/class'
require_relative '../lib/support/sql'
require_relative '../lib/support/model'
require_relative '../lib/logging'
require_relative '../lib/config'
require_relative '../lib/support/conversions'
require_relative '../lib/arcade/api/operations'
require_relative '../lib/arcade/base'
require_relative '../lib/arcade/database'
require_relative '../lib/init'
require_relative "../lib/models"
require_relative '../lib/query'
require_relative '../lib/match'
