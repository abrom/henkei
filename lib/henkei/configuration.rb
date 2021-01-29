# frozen_string_literal: true

class Henkei
  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
    end
  end

  # Handle Henkei configuration
  class Configuration
    attr_accessor :mime_library

    def initialize
      @mime_library = 'mime/types'
    end
  end
end
