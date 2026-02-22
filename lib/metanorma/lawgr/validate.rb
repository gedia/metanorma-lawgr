module Metanorma
  module Lawgr
    module Validate
      def content_validate(doc)
        super
        bibdata_validate(doc.root)
      end

      def bibdata_validate(doc)
        doctype_validate(doc)
      end

      def doctype_validate(xmldoc)
        doctype = xmldoc&.at("//bibdata/ext/doctype")&.text
        %w[act pd ap egk other].include?(doctype) or
          @log.add("Document Attributes", nil,
                   "#{doctype} is not a recognised document type")
      end

      def validate(doc)
        content_validate(doc)
        schema_validate(formattedstr_strip(doc.dup),
                        File.join(File.dirname(__FILE__), "lawgr.rng"))
      end

      def style(_node, _text)
        nil
      end
    end
  end
end
