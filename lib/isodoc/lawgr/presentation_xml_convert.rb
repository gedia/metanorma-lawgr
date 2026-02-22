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
        lbl = @xrefs.anchor(elem["id"], :label)
        case ctype
        when "book", "part", "tmima", "chapter"
          prefix_structural_label(elem, lbl, ctype)
        when "article"
          prefix_article_label(elem, lbl)
        when "subarticle"
          prefix_subarticle_label(elem, lbl)
        when "paragraph"
          prefix_paragraph_label(elem, lbl)
        else
          super
        end
      end

      def prefix_structural_label(elem, lbl, _ctype)
        return unless lbl

        t = elem.at(ns("./title"))
        if t && !t.text.strip.empty?
          prefix_name(elem, "<br/>",
                      "<strong>#{lbl}</strong>", "title")
        else
          prefix_name(elem, "", "<strong>#{lbl}</strong>", "title")
        end
      end

      def prefix_article_label(elem, lbl)
        return unless lbl

        t = elem.at(ns("./title"))
        if t && !t.text.strip.empty?
          prefix_name(elem, ": ", lbl, "title")
        else
          prefix_name(elem, "", lbl, "title")
        end
      end

      def prefix_subarticle_label(elem, lbl)
        return unless lbl

        t = elem.at(ns("./title"))
        if t && !t.text.strip.empty?
          prefix_name(elem, ". ", lbl, "title")
        else
          prefix_name(elem, "", lbl, "title")
        end
      end

      def prefix_paragraph_label(elem, lbl)
        return unless lbl

        # Check if this paragraph should be unnumbered
        # (single paragraph in article)
        return if elem["unnumbered"] == "true"

        t = elem.at(ns("./title"))
        if t && !t.text.strip.empty?
          prefix_name(elem, ". ", lbl, "title")
        else
          prefix_name(elem, "", "#{lbl}.", "title")
        end
      end

      # Select ordered list type based on nesting depth within
      # a paragraph context:
      # Depth 1 → lowergreek (proper Greek numerals: α, β… στ…)
      # Depth 2 → double Greek (αα, αβ… βα, ββ…)
      # Depth 3+ → lowerroman (i, ii, iii…)
      def ol_depth(node)
        depth = node.ancestors("ol").size + 1
        case depth
        when 1 then :lowergreek
        when 2 then :lowergreek_double
        else :lowerroman
        end
      end

      def ol_label(node, idx)
        depth = node.ancestors("ol").size + 1
        case depth
        when 1
          Metanorma::Lawgr::GreekNumerals.to_greek_lower(idx + 1)
        when 2
          parent_idx = node.parent.parent.xpath(ns("./li"))
            .index(node.parent) + 1
          Metanorma::Lawgr::GreekNumerals
            .to_greek_double(parent_idx, idx + 1)
        else
          RomanNumerals.to_roman(idx + 1).downcase
        end
      end

      def move_norm_ref_to_sections(docxml); end

      include Init
    end
  end
end
