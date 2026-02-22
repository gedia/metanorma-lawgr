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
          pdf: "pdf",
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

      def output(isodoc_node, inname, outname, format, options = {})
        options_preprocess(options)
        case format
        when :html
          IsoDoc::Lawgr::HtmlConvert.new(options)
            .convert(inname, isodoc_node, nil, outname)
        when :pdf
          IsoDoc::Lawgr::PdfConvert.new(options)
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
