require 'henkei/version'
require 'henkei/yomu'

require 'net/http'
require 'mime/types'
require 'time'
require 'json'

require 'socket'
require 'stringio'

class Henkei
  GEMPATH = File.dirname(File.dirname(__FILE__))
  JARPATH = File.join(Henkei::GEMPATH, 'jar', 'tika-app-1.14.jar')
  DEFAULT_SERVER_PORT = 9293 # an arbitrary, but perfectly cromulent, port

  @@server_port = nil
  @@server_pid = nil

  # Read text or metadata from a data buffer.
  #
  #   data = File.read 'sample.pages'
  #   text = Henkei.read :text, data
  #   metadata = Henkei.read :metadata, data

  def self.read(type, data)
    result = @@server_pid ? self._server_read(type, data) : self._client_read(type, data)

    case type
    when :text
      result
    when :html
      result
    when :metadata
      JSON.parse(result)
    when :mimetype
      MIME::Types[JSON.parse(result)['Content-Type']].first
    end
  end

  def self._client_read(type, data)
    switch =
      case type
      when :text
        '-t'
      when :html
        '-h'
      when :metadata
        '-m -j'
      when :mimetype
        '-m -j'
      end

    IO.popen "#{java} -Djava.awt.headless=true -jar #{Henkei::JARPATH} #{switch}", 'r+' do |io|
      io.write data
      io.close_write
      io.read
    end
  end


  def self._server_read(_, data)
    s = TCPSocket.new('localhost', @@server_port)
    file = StringIO.new(data, 'r')

    while 1
      chunk = file.read(65536)
      break unless chunk
      s.write(chunk)
    end

    # tell Tika that we're done sending data
    s.shutdown(Socket::SHUT_WR)

    resp = ''
    while 1
      chunk = s.recv(65536)
      break if chunk.empty? || !chunk
      resp << chunk
    end
    resp
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

  def initialize(input)
    if input.is_a? String
      if File.exists? input
        @path = input
      elsif input =~ URI::regexp
        @uri = URI.parse input
      else
        raise Errno::ENOENT.new "missing file or invalid URI - #{input}"
      end
    elsif input.respond_to? :read
      @stream = input
    else
      raise TypeError.new "can't read from #{input.class.name}"
    end
  end

  # Returns the text content of the Henkei document.
  #
  #   henkei = Henkei.new 'sample.pages'
  #   henkei.text

  def text
    return @text if defined? @text

    @text = Henkei.read :text, data
  end

  # Returns the text content of the Henkei document in HTML.
  #
  #   henkei = Henkei.new 'sample.pages'
  #   henkei.html

  def html
    return @html if defined? @html

    @html = Henkei.read :html, data
  end

  # Returns the metadata hash of the Henkei document.
  #
  #   henkei = Henkei.new 'sample.pages'
  #   henkei.metadata['Content-Type']

  def metadata
    return @metadata if defined? @metadata

    @metadata = Henkei.read :metadata, data
  end

  # Returns the mimetype object of the Henkei document.
  #
  #   henkei = Henkei.new 'sample.docx'
  #   henkei.mimetype.content_type #=> 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  #   henkei.mimetype.extensions #=> ['docx']

  def mimetype
    return @mimetype if defined? @mimetype

    type = metadata['Content-Type'].is_a?(Array) ? metadata['Content-Type'].first : metadata['Content-Type']
    
    @mimetype = MIME::Types[type].first
  end

  # Returns +true+ if the Henkei document was specified using a file path.
  #
  #   henkei = Henkei.new 'sample.pages'
  #   henkei.path? #=> true


  def creation_date
    return @creation_date if defined? @creation_date
 
    if metadata['Creation-Date']
      @creation_date = Time.parse(metadata['Creation-Date'])
    else
      nil
    end
  end

  def path?
    defined? @path
  end

  # Returns +true+ if the Henkei document was specified using a URI.
  #
  #   henkei = Henkei.new 'http://svn.apache.org/repos/asf/poi/trunk/test-data/document/sample.docx'
  #   henkei.uri? #=> true

  def uri?
    defined? @uri
  end

  # Returns +true+ if the Henkei document was specified from a stream or an object which responds to +read+.
  #
  #   file = File.open('sample.pages')
  #   henkei = Henkei.new file
  #   henkei.stream? #=> true

  def stream?
    defined? @stream
  end

  # Returns the raw/unparsed content of the Henkei document.
  #
  #   henkei = Henkei.new 'sample.pages'
  #   henkei.data

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
  def self.server(type, custom_port=nil)
    switch =
      case type
      when :text
        '-t'
      when :html
        '-h'
      when :metadata
        '-m -j'
      when :mimetype
        '-m -j'
      end

    @@server_port = custom_port || DEFAULT_SERVER_PORT
    
    @@server_pid = Process.spawn("#{java} -Djava.awt.headless=true -jar #{Henkei::JARPATH} --server --port #{@@server_port} #{switch}")
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
  #    my_texts = reports.map{|report_path| Henkei.new(report_path).text }
  #  rescue
  #  ensure
  #    Henkei.kill_server!
  #  end
  def self.kill_server!
    if @@server_pid
      Process.kill('INT', @@server_pid)
      @@server_pid = nil
      @@server_port = nil
    end
  end

  def self.java
    ENV['JAVA_HOME'] ? ENV['JAVA_HOME'] + '/bin/java' : 'java'
  end
  private_class_method :java
end
