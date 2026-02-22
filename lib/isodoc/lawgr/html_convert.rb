require_relative "base_convert"
require_relative "init"
require "isodoc"

module IsoDoc
  module Lawgr
    class HtmlConvert < IsoDoc::HtmlConvert
      def initialize(options)
        @libdir = File.dirname(__FILE__)
        super
      end

      def default_fonts(options)
        {
          bodyfont: '"Times New Roman", serif',
          headerfont: '"Times New Roman", serif',
          monospacefont: '"Courier New", monospace',
          normalfontsize: "15px",
          footnotefontsize: "0.9em",
        }
      end

      def default_file_locations(_options)
        {
          htmlstylesheet: html_doc_path("htmlstyle.css"),
          htmlcoverpage: html_doc_path("html_lawgr_titlepage.html"),
          htmlintropage: html_doc_path("html_lawgr_intro.html"),
        }
      end

      def googlefonts
        <<~HEAD.freeze
          <link href="https://fonts.googleapis.com/css2?family=GFS+Didot&family=Roboto:wght@300;400;500;700&display=swap" rel="stylesheet">
        HEAD
      end

      def make_body(xml, docxml)
        body_attr = { lang: "EL", link: "blue", vlink: "#954F72",
                      "xml:lang": "EL", class: "container" }
        xml.body **body_attr do |body|
          make_body1(body, docxml)
          make_body2(body, docxml)
          make_body3(body, docxml)
        end
      end

      include BaseConvert
      include Init
    end
  end
end
