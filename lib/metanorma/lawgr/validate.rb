module Metanorma
  module Lawgr
    module Validate
      def content_validate(doc)
        super
        bibdata_validate(doc.root)
        edafio_validate(doc.root)
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

      def edafio_validate(xmldoc)
        edafio_validate_hardbreaks(xmldoc)
        edafio_validate_verse(xmldoc)
      end

      def edafio_validate_hardbreaks(xmldoc)
        if xmldoc.at("//presentation-metadata " \
                      "[name[text()='hardbreaks-option']]" \
                      "[value[text()='true']]") ||
            xmldoc.at("//*[@hardbreaks='true']")
          @log.add("Document Attributes", nil,
                   "`:hardbreaks-option:` / `[%hardbreaks]` is " \
                   "incompatible with εδάφιο detection in lawgr")
        end
      end

      def edafio_validate_verse(xmldoc)
        xmldoc.xpath('//clause[@type="paragraph"]//quote[@type="verse"]')
          .each do |node|
          @log.add("Style", node,
                   "`[verse]` blocks inside paragraph clauses " \
                   "conflict with εδάφιο detection in lawgr")
        end
      end

      def style(_node, _text)
        nil
      end
    end
  end
end
