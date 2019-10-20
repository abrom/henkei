[![Travis Build Status](http://img.shields.io/travis/abrom/henkei.svg?style=flat)](https://travis-ci.org/abrom/henkei)
[![Maintainability](https://api.codeclimate.com/v1/badges/d06e8c917cf7d8c07234/maintainability)](https://codeclimate.com/github/abrom/henkei/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/d06e8c917cf7d8c07234/test_coverage)](https://codeclimate.com/github/abrom/henkei/test_coverage)
[![Gem Version](http://img.shields.io/gem/v/henkei.svg?style=flat)](#)

# Henkei 変形

[Henkei](http://github.com/abrom/henkei) is a library for extracting text and metadata from files and documents using the [Apache Tika](http://tika.apache.org/) content analysis toolkit.

The library was forked from [Yomu](http://github.com/Erol/yomu) as it is no longer maintained.

Here are some of the formats supported:

- Microsoft Office OLE 2 and Office Open XML Formats (.doc, .docx, .xls, .xlsx,
  .ppt, .pptx)
- OpenOffice.org OpenDocument Formats (.odt, .ods, .odp)
- Apple iWorks Formats
- Rich Text Format (.rtf)
- Portable Document Format (.pdf)

For the complete list of supported formats, please visit the Apache Tika
[Supported Document Formats](http://tika.apache.org/0.9/formats.html) page.

## Usage

Text, metadata and MIME type information can be extracted by calling `Henkei.read` directly:

```ruby
require 'henkei'

data = File.read 'sample.pages'
text = Henkei.read :text, data
metadata = Henkei.read :metadata, data
mimetype = Henkei.read :mimetype, data
```

Henkei is backward compatible with Yomu

```ruby
text = Yomu.read :text, data
```

### Reading text from a given filename

Create a new instance of Henkei and pass a filename.

```ruby
henkei = Henkei.new 'sample.pages'
text = henkei.text
```

### Reading text from a given URL

This is useful for reading remote files, like documents hosted on Amazon S3.

```ruby
henkei = Henkei.new 'http://svn.apache.org/repos/asf/poi/trunk/test-data/document/sample.docx'
text = henkei.text
```

### Reading text from a stream

Henkei can also read from a stream or any object that responds to `read`, including file uploads from Ruby on Rails or Sinatra.

```ruby
post '/:name/:filename' do
  henkei = Henkei.new params[:data][:tempfile]
  henkei.text
end
```

### Reading metadata

Metadata is returned as a hash.

```ruby
henkei = Henkei.new 'sample.pages'
henkei.metadata['Content-Type'] #=> "application/vnd.apple.pages"
```

### Reading MIME types

MIME type is returned as a MIME::Type object.

```ruby
henkei = Henkei.new 'sample.docx'
henkei.mimetype.content_type #=> "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
henkei.mimetype.extensions #=> ['docx']
```

### Using shell pipe

Some files appear to have issues being piped to Tika using IO pipes. The result is an Errno::EPIPE exception
being raised. One possible solution is to use Ruby Shell to pipe the data. This can be passed through either
the initializer or via the Henkei `.read` method.

```ruby
henkei = Henkei.new 'sample.docx', shell_pipe: true
text = henkei.text

data = File.read 'sample.pages'
text = Henkei.read :text, data, shell_pipe: true
```

N.B. this property only applies to client mode and not server.


## Installation and Dependencies

### Java Runtime

Henkei packages the Apache Tika application jar and requires a working JRE for it to work.
Check that you either have the `JAVA_HOME` environment variable set, or that `java` is in your path. 

### Gem

Add this line to your application's Gemfile:

    gem 'henkei'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install henkei
    
### Heroku

Add the JVM Buildpack to your Heroku project:

    $ heroku buildpacks:add heroku/jvm --index 1 -a YOUR_APP_NAME

## Contributing

1. Fork it
2. Create your feature branch ( `git checkout -b my-new-feature` )
3. Create tests and make them pass ( `rake test` )
4. Commit your changes ( `git commit -am 'Added some feature'` )
5. Push to the branch ( `git push origin my-new-feature` )
6. Create a new Pull Request
