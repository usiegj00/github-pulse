# frozen_string_literal: true

require "date"

module Github
  module Pulse
    module DateHelpers
      refine Date do
        def beginning_of_week
          self - (self.cwday - 1)
        end

        def beginning_of_month
          Date.new(year, month, 1)
        end
      end
    end
  end
end