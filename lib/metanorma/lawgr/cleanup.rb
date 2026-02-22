module Metanorma
  module Lawgr
    module Cleanup
      def sections_cleanup(xmldoc)
        super
        heading_to_type(xmldoc)
      end

      # Convert heading attributes to clause types in the XML.
      # The `heading` attribute from AsciiDoc source becomes the
      # `type` attribute on `<clause>` elements.
      def heading_to_type(xmldoc)
        xmldoc.xpath("//clause").each do |c|
          heading = c["heading"]
          next unless heading

          c["type"] = heading
          c.delete("heading")
        end
      end
    end
  end
end
