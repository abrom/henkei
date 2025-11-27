# frozen_string_literal: true

require 'henkei/version'
require 'henkei/yomu'
require 'henkei/configuration'

require 'net/http'
require 'mini_mime'

# require 'mime/types' if available
begin
  require 'mime/types'
rescue LoadError
  nil
end

require 'time'
require 'json'

require 'socket'
require 'stringio'

require 'open3'

# Read text and metadata from files and documents using Apache Tika toolkit
class Henkei # rubocop:disable Metrics/ClassLength
  GEM_PATH = File.dirname(File.dirname(__FILE__))
  JAR_PATH = File.join(Henkei::GEM_PATH, 'jar', 'tika-app-2.9.3.jar')
  CONFIG_PATH = File.join(Henkei::GEM_PATH, 'jar', 'tika-config.xml')
  CONFIG_WITHOUT_OCR_PATH = File.join(Henkei::GEM_PATH, 'jar', 'tika-config-without-ocr.xml')

  def self.mimetype(content_type)
    if Henkei.configuration.mime_library == 'mime/types' && defined?(MIME::Types)
      warn '[DEPRECATION] `mime/types` is deprecated. Please use `mini_mime` instead. ' \
           'Use Henkei.configure and assign "mini_mime" to `mime_library`.'
      MIME::Types[content_type].first
    else
      MiniMime.lookup_by_content_type(content_type).tap do |object|
        object.define_singleton_method(:extensions) { [extension] }
      end
    end
  end

  # Read text or metadata from a data buffer.
  #
  #   data = File.read 'sample.pages'
  #   text = Henkei.read :text, data
  #   metadata = Henkei.read :metadata, data
  #
  def self.read(type, data, include_ocr: false, encoding: nil)
    result = client_read(type, data, include_ocr: include_ocr, encoding: encoding)

    case type
    when :text, :html then result
    when :metadata then JSON.parse(result)
    when :mimetype then Henkei.mimetype(JSON.parse(result)['Content-Type'])
    end
  end

  # Create a new instance of Henkei with a given document.
  #
  # Using a file path:
  #
  #   Henkei.new 'sample.pages'
  #
  # Using a URL:
  #
  #   Henkei.new 'http://svn.apache.org/repos/asf/poi/trunk/test-data/document/sample.docx'
  #
  # From a stream or an object which responds to +read+
  #
  #   Henkei.new File.open('sample.pages')
  #
  def initialize(input)
    if input.is_a? String
      if File.exist? input
        @path = input
      elsif input =~ URI::DEFAULT_PARSER.make_regexp
        @uri = URI.parse input
      else
        raise Errno::ENOENT, "missing file or invalid URI - #{input}"
      end
    elsif input.respond_to? :read
      @stream = input
    else
      raise TypeError, "can't read from #{input.class.name}"
    end
  end

  # Returns the text content of the Henkei document.
  #
  #   henkei = Henkei.new 'sample.pages'
  #   henkei.text
  #
  # Include OCR results from images (includes embedded images in pages/docx/pdf etc)
  #
  #   henkei.text(include_ocr: true)
  #
  # Set the output character encoding (e.g. 'UTF-8')
  #
  #   henkei.text(encoding: 'UTF-8')
  #
  def text(include_ocr: false, encoding: nil)
    return @text if defined? @text

    @text = Henkei.read :text, data, include_ocr: include_ocr, encoding: encoding
  end

  # Returns the text content of the Henkei document in HTML.
  #
  #   henkei = Henkei.new 'sample.pages'
  #   henkei.html
  #
  # Include OCR results from images (includes embedded images in pages/docx/pdf etc)
  #
  #   henkei.html(include_ocr: true)
  #
  # Set the output character encoding (e.g. 'UTF-8')
  #
  #   henkei.text(encoding: 'UTF-8')
  #
  def html(include_ocr: false, encoding: nil)
    return @html if defined? @html

    @html = Henkei.read :html, data, include_ocr: include_ocr, encoding: encoding
  end

  # Returns the metadata hash of the Henkei document.
  #
  #   henkei = Henkei.new 'sample.pages'
  #   henkei.metadata['Content-Type']
  #
  def metadata
    return @metadata if defined? @metadata

    @metadata = Henkei.read :metadata, data
  end

  # Returns the mimetype object of the Henkei document.
  #
  #   henkei = Henkei.new 'sample.docx'
  #   henkei.mimetype.content_type #=> 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  #   henkei.mimetype.extensions #=> ['docx']
  #
  def mimetype
    return @mimetype if defined? @mimetype

    content_type = metadata['Content-Type'].is_a?(Array) ? metadata['Content-Type'].first : metadata['Content-Type']
    @mimetype = Henkei.mimetype(content_type)
  end

  # Returns +true+ if the Henkei document was specified using a file path.
  #
  #   henkei = Henkei.new 'sample.pages'
  #   henkei.path? #=> true
  #
  def creation_date
    return @creation_date if defined? @creation_date
    return unless metadata['dcterms:created']

    @creation_date = Time.parse(metadata['dcterms:created'])
  end

  # Returns +true+ if the Henkei document was specified using a file path.
  #
  #   henkei = Henkei.new '/my/document/path/sample.docx'
  #   henkei.path? #=> true
  #
  def path?
    !!@path
  end

  # Returns +true+ if the Henkei document was specified using a URI.
  #
  #   henkei = Henkei.new 'http://svn.apache.org/repos/asf/poi/trunk/test-data/document/sample.docx'
  #   henkei.uri? #=> true
  #
  def uri?
    !!@uri
  end

  # Returns +true+ if the Henkei document was specified from a stream or an object which responds to +read+.
  #
  #   file = File.open('sample.pages')
  #   henkei = Henkei.new file
  #   henkei.stream? #=> true
  #
  def stream?
    !!@stream
  end

  # Returns the raw/unparsed content of the Henkei document.
  #
  #   henkei = Henkei.new 'sample.pages'
  #   henkei.data
  #
  def data
    return @data if defined? @data

    if path?
      @data = File.read @path
    elsif uri?
      @data = Net::HTTP.get @uri
    elsif stream?
      @data = @stream.read
    end

    @data
  end

  ### Private class methods

  # Provide the path to the Java binary
  #
  def self.java_path
    ENV['JAVA_HOME'] ? "#{ENV['JAVA_HOME']}/bin/java" : 'java'
  end
  private_class_method :java_path

  # Internal helper for calling to Tika library directly
  #
  def self.client_read(type, data, include_ocr: false, encoding: nil)
    unless encoding.nil? || Encoding.name_list.include?(encoding)
      raise ArgumentError, "unsupported encoding - #{encoding}"
    end

    Open3.popen2(*tika_command(type, include_ocr: include_ocr, encoding: encoding)) do |stdin, stdout|
      stdin.binmode
      stdout.binmode
      stdout.set_encoding encoding unless encoding.nil?

      out_reader = Thread.new { stdout.read }

      write_data_to_stdin(data, stdin)

      stdin.close

      out_reader.value
    end
  end
  private_class_method :client_read

  # Internal helper for building the Java command to call Tika
  #
  def self.tika_command(type, include_ocr: false, encoding: nil)
    [
      java_path,
      '-Djava.awt.headless=true',
      '-jar',
      Henkei::JAR_PATH,
      "--config=#{include_ocr ? Henkei::CONFIG_PATH : Henkei::CONFIG_WITHOUT_OCR_PATH}",
      *("--encoding=#{encoding}" unless encoding.nil?)
    ] + switch_for_type(type)
  end
  private_class_method :tika_command

  # Internal helper for building the Java command to call Tika
  #
  def self.switch_for_type(type)
    {
      text: ['-t'],
      html: ['-h'],
      metadata: %w[-m -j],
      mimetype: %w[-m -j]
    }[type]
  end
  private_class_method :switch_for_type

  # Internal helper for writing the input data to stdin when calling Tika
  #
  def self.write_data_to_stdin(data, stdin)
    return unless data

    begin
      if data.respond_to? :readpartial
        IO.copy_stream(data, stdin)
      else
        stdin.write data
      end
    rescue Errno::EPIPE
      # Catch broken pipe.
    end
  end
  private_class_method :write_data_to_stdin
end
