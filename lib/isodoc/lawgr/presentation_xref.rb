module IsoDoc
  module Lawgr
    class PresentationXMLConvert < IsoDoc::PresentationXMLConvert
      # Greek law cross-reference label rendering.
      # Generates display text for xref targets based on their
      # structural type (Article, Paragraph, etc.)

      def anchor_struct_label(lbl, elem)
        case elem
        when "article"
          @i18n.article + " " + lbl.to_s
        when "paragraph"
          @i18n.paragraph + " " + lbl.to_s
        when "book"
          lbl.to_s
        when "part"
          lbl.to_s
        when "tmima"
          lbl.to_s
        when "chapter"
          lbl.to_s
        else
          lbl.to_s
        end
      end

      def eref_localities1(target, type, from, upto, node)
        case type
        when "clause"
          if a = @xrefs.anchor(from, :elem)
            return "#{a} #{@xrefs.anchor(from, :label)}"
          end
        end
        super
      end
    end
  end
end
