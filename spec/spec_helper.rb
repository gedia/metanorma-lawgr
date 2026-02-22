require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
end

require "bundler/setup"
require "metanorma-lawgr"
require "rspec/matchers"
require "equivalent-xml"
require "xml-c14n"

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

OPTIONS = [backend: :lawgr, header_footer: true,
           agree_to_terms: true].freeze

ASCIIDOC_BLANK_HDR = <<~HDR.freeze
  = Document title
  Author
  :docfile: test.adoc
  :nodoc:
  :novalid:
  :no-isobib:
  :docnumber: 1234
  :doctype: act
  :language: el
  :script: Grek

HDR

BLANK_HDR = <<~HDR.freeze
  <lawgr-standard xmlns="https://www.metanorma.org/ns/lawgr" type="semantic" version="">
    <bibdata type="standard">
      <title language="el" format="text/plain" type="main">Document title</title>
      <docidentifier primary="true">1234</docidentifier>
      <contributor>
        <role type="author"/>
        <organization>
          <name>ΕΘΝΙΚΟ ΤΥΠΟΓΡΑΦΕΙΟ</name>
        </organization>
      </contributor>
      <contributor>
        <role type="publisher"/>
        <organization>
          <name>ΕΘΝΙΚΟ ΤΥΠΟΓΡΑΦΕΙΟ</name>
        </organization>
      </contributor>
      <language>el</language>
      <script>Grek</script>
      <status>
        <stage>published</stage>
      </status>
      <copyright>
        <from>#{Time.now.year}</from>
        <owner>
          <organization>
            <name>ΕΘΝΙΚΟ ΤΥΠΟΓΡΑΦΕΙΟ</name>
          </organization>
        </owner>
      </copyright>
      <ext>
        <doctype>act</doctype>
      </ext>
    </bibdata>
HDR

def strip_guid(xml)
  xml.gsub(%r{ id="_[^"]+"}, ' id="_"')
    .gsub(%r{ target="_[^"]+"}, ' target="_"')
end
