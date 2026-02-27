require "metanorma/processor"

module Metanorma
  module Lawgr
    class Processor < Metanorma::Processor
      def initialize # rubocop:disable Lint/MissingSuper
        @short = :lawgr
        @input_format = :asciidoc
        @asciidoctor_backend = :lawgr
      end

      def output_formats
        super.merge(
          html: "html",
          html_alt: "alt.html",
        )
      end

      def fonts_manifest
        {
          "Times New Roman" => nil,
          "Courier New" => nil,
        }
      end

      def version
        "Metanorma::Lawgr #{Metanorma::Lawgr::VERSION}"
      end

      def use_presentation_xml(ext)
        return true if ext == :html_alt

        super
      end

      def output(isodoc_node, inname, outname, format, options = {})
        options_preprocess(options)
        case format
        when :html
          IsoDoc::Lawgr::HtmlConvert.new(options)
            .convert(inname, isodoc_node, nil, outname)
        when :html_alt
          IsoDoc::Lawgr::HtmlConvert.new(options.merge(alt: true))
            .convert(inname, isodoc_node, nil, outname)
        when :presentation
          IsoDoc::Lawgr::PresentationXMLConvert.new(options)
            .convert(inname, isodoc_node, nil, outname)
        else
          super
        end
      end
    end
  end
end
