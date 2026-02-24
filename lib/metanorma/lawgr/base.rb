module Metanorma
  module Lawgr
    module Base
      def default_publisher
        "ΕΘΝΙΚΟ ΤΥΠΟΓΡΑΦΕΙΟ"
      end

      def init_misc(node)
        super
        @default_doctype = "act"
      end

      def doctype(node)
        d = super
        unless %w[act pd ap egk other].include?(d)
          @log.add("Document Attributes", nil,
                   "#{d} is not a legal document type: " \
                   "reverting to '#{@default_doctype}'")
          d = @default_doctype
        end
        d
      end

      def outputs(node, ret)
        File.open("#{@filename}.xml", "w:UTF-8") { |f| f.write(ret) }
        presentation_xml_converter(node).convert("#{@filename}.xml")
        html_converter(node).convert("#{@filename}.presentation.xml",
                                     nil, false, "#{@filename}.html")
      end

      def presentation_xml_converter(node)
        IsoDoc::Lawgr::PresentationXMLConvert
          .new(html_extract_attributes(node)
          .merge(output_formats:
                   ::Metanorma::Lawgr::Processor.new.output_formats))
      end

      def html_converter(node)
        IsoDoc::Lawgr::HtmlConvert.new(html_extract_attributes(node))
      end

    end
  end
end
