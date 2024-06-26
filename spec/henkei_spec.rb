# frozen_string_literal: true

require 'helper'
require 'henkei'
require 'nokogiri'

# Some of the tests have been known to fail in weird and wonderful ways when `rails` is included
require 'rails' if ENV['INCLUDE_RAILS'] == 'true'

def ci?
  ENV['CI'] == 'true'
end

describe Henkei do
  let(:data) { File.read 'spec/samples/sample.docx' }

  before do
    ENV['JAVA_HOME'] = nil
  end

  describe '.read' do
    it 'reads text' do
      text = described_class.read :text, data

      expect(text).to include 'The quick brown fox jumped over the lazy cat.'
    end

    it 'reads metadata' do
      metadata = described_class.read :metadata, data

      expect(metadata['Content-Type']).to(
        eq 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      )
    end

    it 'reads metadata values with colons as strings' do
      data = File.read 'spec/samples/sample-metadata-values-with-colons.doc'
      metadata = described_class.read :metadata, data

      expect(metadata['dc:title']).to eq 'problem: test'
    end

    it 'reads mimetype' do
      mimetype = described_class.read :mimetype, data

      expect(mimetype.content_type).to(
        eq 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      )
      expect(mimetype.extensions).to include 'docx'
    end

    context 'when passing in the `pipe-error.png` test file' do
      let(:data) { File.read 'spec/samples/pipe-error.png' }

      it 'returns an empty result' do
        text = described_class.read :text, data

        expect(text).to eq ''
      end

      unless ci?
        context 'when `include_ocr` is enabled' do
          it 'returns parsed plain text in the image' do
            text = described_class.read :text, data, include_ocr: true

            expect(text).to include <<~TEXT
              West Side

              Sea Island
            TEXT
          end
        end
      end
    end

    context 'when a valid `encoding` value is provided' do
      let(:encoding) { 'UTF-32' }

      it 'returns the parsed text in the specified encoding' do
        text = described_class.read :text, data, encoding: encoding

        expect(text.encoding.name).to eq encoding
      end
    end

    context 'when an invalid `encoding` value is provided' do
      let(:encoding) { 'Beef' }

      it 'raises an error' do
        expect do
          described_class.read :text, data, encoding: encoding
        end.to raise_error(ArgumentError, "unsupported encoding - #{encoding}")
      end
    end
  end

  describe '.new' do
    it 'requires parameters' do
      expect { described_class.new }.to raise_error ArgumentError
    end

    it 'accepts a root path' do
      henkei = described_class.new File.join(Henkei::GEM_PATH, 'spec/samples/sample.pages')

      expect(henkei).to be_path
      expect(henkei).not_to be_uri
      expect(henkei).not_to be_stream
    end

    it 'accepts a relative path' do
      henkei = described_class.new 'spec/samples/sample.pages'

      expect(henkei).to be_path
      expect(henkei).not_to be_uri
      expect(henkei).not_to be_stream
    end

    it 'accepts a path with spaces' do
      henkei = described_class.new 'spec/samples/sample filename with spaces.pages'

      expect(henkei).to be_path
      expect(henkei).not_to be_uri
      expect(henkei).not_to be_stream
    end

    it 'accepts a URI' do
      henkei = described_class.new 'http://svn.apache.org/repos/asf/poi/trunk/test-data/document/sample.docx'

      expect(henkei).to be_uri
      expect(henkei).not_to be_path
      expect(henkei).not_to be_stream
    end

    it 'accepts a stream or object that can be read' do
      File.open 'spec/samples/sample.pages', 'r' do |file|
        henkei = described_class.new file

        expect(henkei).to be_stream
        expect(henkei).not_to be_path
        expect(henkei).not_to be_uri
      end
    end

    it 'refuses a path to a missing file' do
      expect { described_class.new 'test/sample/missing.pages' }.to raise_error Errno::ENOENT
    end

    it 'refuses other objects' do
      [nil, 1, 1.1].each do |object|
        expect { described_class.new object }.to raise_error TypeError
      end
    end
  end

  describe '.creation_date' do
    let(:henkei) { described_class.new 'spec/samples/sample.pages' }

    it 'returns a Time' do
      expect(henkei.creation_date).to be_a Time
    end
  end

  describe '.java' do
    specify 'with no specified JAVA_HOME' do
      expect(described_class.send(:java_path)).to eq 'java'
    end

    specify 'with a specified JAVA_HOME' do
      ENV['JAVA_HOME'] = '/path/to/java/home'

      expect(described_class.send(:java_path)).to eq '/path/to/java/home/bin/java'
    end
  end

  context 'when initialized with a given path' do
    let(:henkei) { described_class.new 'spec/samples/sample.pages' }

    specify '#text reads text' do
      expect(henkei.text).to include 'The quick brown fox jumped over the lazy cat.'
    end

    specify '#metadata reads metadata' do
      expect(henkei.metadata['Content-Type']).to eq %w[application/vnd.apple.pages application/vnd.apple.pages]
    end

    context 'when passing in the `pipe-error.png` test file' do
      let(:henkei) { described_class.new 'spec/samples/pipe-error.png' }

      it '#text returns an empty result' do
        expect(henkei.text).to eq ''
      end

      it '#html returns an empty body' do
        expect(henkei.html).to include '<body/>'
        expect(henkei.html).to include '<meta name="tiff:ImageWidth" content="792"/>'
      end

      it '#mimetype returns `image/png`' do
        expect(henkei.mimetype.content_type).to eq 'image/png'
      end

      unless ci?
        context 'when `include_ocr` is enabled' do
          it '#text returns plain text of parsed text in the image' do
            expect(henkei.text(include_ocr: true)).to include <<~TEXT
              West Side

              Sea Island
            TEXT
          end

          it '#html returns HTML of parsed text in the image' do
            expect(henkei.html(include_ocr: true)).to include '<meta name="tiff:ImageWidth" content="792"/>'

            html_body = Nokogiri::HTML(henkei.html(include_ocr: true)).at_xpath('//body')
            ['West Side', 'Sea Island', 'Richmond', 'Steveston'].each do |location|
              expect(html_body.text).to include location
            end
          end
        end
      end
    end
  end

  context 'when initialized with a given URI' do
    let(:henkei) { described_class.new 'http://svn.apache.org/repos/asf/poi/trunk/test-data/document/sample.docx' }

    specify '#text reads text' do
      expect(henkei.text).to include 'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.'
    end

    specify '#metadata reads metadata' do
      expect(henkei.metadata['Content-Type']).to(
        eq 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      )
    end
  end

  context 'when initialized with a given stream' do
    let(:henkei) { described_class.new File.open('spec/samples/sample.pages', 'rb') }

    specify '#text reads text' do
      expect(henkei.text).to include 'The quick brown fox jumped over the lazy cat.'
    end

    specify '#metadata reads metadata' do
      expect(henkei.metadata['Content-Type']).to eq %w[application/vnd.apple.pages application/vnd.apple.pages]
    end
  end

  context 'when source is a remote PDF' do
    let(:henkei) { described_class.new 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf' }

    specify '#text reads text' do
      expect(henkei.text).to include 'Dummy PDF file'
    end

    specify '#metadata reads metadata' do
      expect(henkei.metadata['Content-Type']).to eq 'application/pdf'
    end
  end
end
