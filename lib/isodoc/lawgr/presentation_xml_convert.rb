require_relative "init"
require_relative "presentation_xref"
require "isodoc"
require "metanorma/lawgr/greek_numerals"

module IsoDoc
  module Lawgr
    class PresentationXMLConvert < IsoDoc::PresentationXMLConvert
      def initialize(options)
        super
      end

      def middle_title(docxml); end

      # Override clause presentation to inject structural labels.
      # The label (ΒΙΒΛΙΟ ΠΡΩΤΟ, ΜΕΡΟΣ Α', Άρθρο 1, etc.) is derived
      # from document structure, never from authored titles.
      def clause1(elem)
        ctype = elem["type"]
        level = @xrefs.anchor(elem["id"], :level, false) ||
          (elem.ancestors("clause, annex").size + 1)
        lbl = @xrefs.anchor(elem["id"], :label, false)
        case ctype
        when "book", "part", "tmima", "chapter"
          prefix_structural_label(elem, lbl, level)
        when "article"
          prefix_article_label(elem, lbl, level)
        when "subarticle"
          prefix_subarticle_label(elem, lbl, level)
        when "paragraph"
          prefix_paragraph_label(elem, lbl, level)
        else
          super
        end
      end

      def prefix_structural_label(elem, lbl, level)
        if lbl
          t = elem.at(ns("./title"))
          if t && !t.text.strip.empty?
            prefix_name(elem, { caption: "<br/>" },
                        "<strong>#{lbl}</strong>", "title")
          else
            prefix_name(elem, {}, "<strong>#{lbl}</strong>", "title")
          end
        else
          prefix_name(elem, {}, nil, "title")
        end
        t = elem.at(ns("./fmt-title")) and t["depth"] = level
      end

      def prefix_article_label(elem, lbl, level)
        if lbl
          t = elem.at(ns("./title"))
          if t && !t.text.strip.empty?
            prefix_name(elem, { caption: "<span class='fmt-caption-delim'>: </span>" },
                        lbl, "title")
          else
            prefix_name(elem, {}, lbl, "title")
          end
        else
          prefix_name(elem, {}, nil, "title")
        end
        t = elem.at(ns("./fmt-title")) and t["depth"] = level
      end

      def prefix_subarticle_label(elem, lbl, level)
        if lbl
          t = elem.at(ns("./title"))
          if t && !t.text.strip.empty?
            prefix_name(elem, { caption: "<span class='fmt-caption-delim'>. </span>" },
                        lbl, "title")
          else
            prefix_name(elem, {}, lbl, "title")
          end
        else
          prefix_name(elem, {}, nil, "title")
        end
        t = elem.at(ns("./fmt-title")) and t["depth"] = level
      end

      def prefix_paragraph_label(elem, lbl, level)
        if lbl && elem["unnumbered"] != "true"
          t = elem.at(ns("./title"))
          if t && !t.text.strip.empty?
            prefix_name(elem, { caption: "<span class='fmt-caption-delim'>. </span>" },
                        lbl, "title")
          else
            prefix_name(elem, { label: "." }, lbl, "title")
          end
        else
          prefix_name(elem, {}, nil, "title")
        end
        t = elem.at(ns("./fmt-title")) and t["depth"] = level
      end

      # Use standard list types for now.
      # TODO: proper Greek numeral list support requires extending
      # IsoDoc::XrefGen::Counter#listlabel with custom types.
      # For MVP, depth 1 = alphabet (a,b,c), depth 2+ = roman (i,ii,iii).
      def ol_depth(node)
        depth = node.ancestors("ul, ol").size + 1
        case depth
        when 1 then :alphabet
        when 2 then :alphabet
        else :roman
        end
      end

      def move_norm_ref_to_sections(docxml); end

      include Init
    end
  end
end
