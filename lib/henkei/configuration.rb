# frozen_string_literal: true

# Henkei monkey patch for configuration support
class Henkei
  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end

  # Handle Henkei configuration
  class Configuration
    attr_accessor :mime_library

    def initialize
      @mime_library = 'mime/types'
    end
  end
end
