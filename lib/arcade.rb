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
#require 'pg'
#require 'mini_sql'
require 'httparty'
require_relative '../lib/errors'
require_relative '../lib/logging'
require_relative '../lib/config'
require_relative '../lib/arcade/api/operations'
require_relative '../lib/arcade/database'
require_relative "../lib/models"

