# frozen_string_literal: true

require_relative "pulse/version"
require_relative "pulse/date_helpers"
require_relative "pulse/cli"
require_relative "pulse/analyzer"
require_relative "pulse/github_client"
require_relative "pulse/git_analyzer"
require_relative "pulse/reporter"

module Github
  module Pulse
    class Error < StandardError; end
  end
end