# frozen_string_literal: true

require 'henkei/version'
require 'henkei/yomu'

require 'net/http'
require 'mime/types'
require 'time'
require 'json'

require 'socket'
require 'stringio'

require 'open3'

# Read text and metadata from files and documents using Apache Tika toolkit
class Henkei # rubocop:disable Metrics/ClassLength
  GEM_PATH = File.dirname(File.dirname(__FILE__))
  JAR_PATH = File.join(Henkei::GEM_PATH, 'jar', 'tika-app-1.23.jar')
  CONFIG_PATH = File.join(Henkei::GEM_PATH, 'jar', 'tika-config.xml')
  DEFAULT_SERVER_PORT = 9293 # an arbitrary, but perfectly cromulent, port

  @@server_port = nil
  @@server_pid = nil

  # Read text or metadata from a data buffer.
  #
  #   data = File.read 'sample.pages'
  #   text = Henkei.read :text, data
  #   metadata = Henkei.read :metadata, data
  #
  def self.read(type, data)
    result = @@server_pid ? server_read(data) : client_read(type, data)

    case type
    when :text then result
    when :html then result
    when :metadata then JSON.parse(result)
    when :mimetype then MIME::Types[JSON.parse(result)['Content-Type']].first
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
  def text
    return @text if defined? @text

    @text = Henkei.read :text, data
  end

  # Returns the text content of the Henkei document in HTML.
  #
  #   henkei = Henkei.new 'sample.pages'
  #   henkei.html
  #
  def html
    return @html if defined? @html

    @html = Henkei.read :html, data
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

    type = metadata['Content-Type'].is_a?(Array) ? metadata['Content-Type'].first : metadata['Content-Type']

    @mimetype = MIME::Types[type].first
  end

  # Returns +true+ if the Henkei document was specified using a file path.
  #
  #   henkei = Henkei.new 'sample.pages'
  #   henkei.path? #=> true
  #
  def creation_date
    return @creation_date if defined? @creation_date
    return unless metadata['Creation-Date']

    @creation_date = Time.parse(metadata['Creation-Date'])
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

  # Returns pid of Tika server, started as a new spawned process.
  #
  #  type :html, :text or :metadata
  #  custom_port e.g. 9293
  #
  #  Henkei.server(:text, 9294)
  #
  def self.server(type, custom_port = nil)
    @@server_port = custom_port || DEFAULT_SERVER_PORT

    @@server_pid = Process.spawn tika_command(type, true)
    sleep(2) # Give the server 2 seconds to spin up.
    @@server_pid
  end

  # Kills server started by Henkei.server
  #
  #  Always run this when you're done, or else Tika might run until you kill it manually
  #  You might try putting your extraction in a begin..rescue...ensure...end block and
  #    putting this method in the ensure block.
  #
  #  Henkei.server(:text)
  #  reports = ["report1.docx", "report2.doc", "report3.pdf"]
  #  begin
  #    my_texts = reports.map{ |report_path| Henkei.new(report_path).text }
  #  rescue
  #  ensure
  #    Henkei.kill_server!
  #  end
  #
  def self.kill_server!
    return unless @@server_pid

    Process.kill('INT', @@server_pid)
    @@server_pid = nil
    @@server_port = nil
  end

  ### Private class methods

  # Provide the path to the Java binary
  #
  def self.java_path
    ENV['JAVA_HOME'] ? ENV['JAVA_HOME'] + '/bin/java' : 'java'
  end
  private_class_method :java_path

  # Internal helper for calling to Tika library directly
  #
  def self.client_read(type, data)
    Open3.capture2(tika_command(type), stdin_data: data).first
  end
  private_class_method :client_read

  # Internal helper for calling to running Tika server
  #
  def self.server_read(data)
    s = TCPSocket.new('localhost', @@server_port)
    file = StringIO.new(data, 'r')

    loop do
      chunk = file.read(65_536)
      break unless chunk

      s.write(chunk)
    end

    # tell Tika that we're done sending data
    s.shutdown(Socket::SHUT_WR)

    resp = String.new ''
    loop do
      chunk = s.recv(65_536)
      break if chunk.empty? || !chunk

      resp << chunk
    end
    resp
  end
  private_class_method :server_read

  # Internal helper for building the Java command to call Tika
  #
  def self.tika_command(type, server = false)
    command = ["#{java_path} -Djava.awt.headless=true -jar #{Henkei::JAR_PATH} --config=#{Henkei::CONFIG_PATH}"]
    command << "--server --port #{@@server_port}" if server
    command << switch_for_type(type)
    command.join ' '
  end
  private_class_method :tika_command

  # Internal helper for building the Java command to call Tika
  #
  def self.switch_for_type(type)
    case type
    when :text then '-t'
    when :html then '-h'
    when :metadata then '-m -j'
    when :mimetype then '-m -j'
    end
  end
  private_class_method :switch_for_type
end
