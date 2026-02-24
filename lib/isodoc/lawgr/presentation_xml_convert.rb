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
        when "custom"
          prefix_custom_label(elem, lbl, level)
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
            prefix_name(elem, { caption: "<span class='fmt-caption-delim'> — </span>" },
                        lbl, "title")
          else
            prefix_name(elem, {}, lbl, "title")
          end
          add_toc_variant_title(elem, lbl)
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
            add_toc_variant_title(elem, lbl)
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

      # Custom clause: "Α. Title" — label + period + space + title inline.
      def prefix_custom_label(elem, lbl, level)
        if lbl
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

      def prefix_paragraph_label(elem, lbl, level)
        if lbl && elem["unnumbered"] != "true"
          t = elem.at(ns("./title"))
          if t && !t.text.strip.empty?
            # Titled paragraph: number goes in heading, title rendered
            # as paragraph-style body text (not as part of the heading).
            title_xml = to_xml(t.children)
            t.children.each(&:remove)
            prefix_name(elem, { label: "." }, lbl, "title")
            t.inner_html = title_xml
            fmt_t = elem.at(ns("./fmt-title"))
            if fmt_t
              p_node = Nokogiri::XML::Node.new("p", elem.document)
              p_node["class"] = "paragraph-title"
              p_node.inner_html = "<strong>#{title_xml}</strong>"
              fmt_t.add_next_sibling(p_node)
            end
            toc_lbl = @xrefs.anchor(elem["id"], :xref, false)
            add_toc_variant_title(elem, toc_lbl) if toc_lbl
          else
            prefix_name(elem, { label: "." }, lbl, "title")
            toc_lbl = @xrefs.anchor(elem["id"], :xref, false)
            add_toc_variant_title(elem, toc_lbl) if toc_lbl
          end
        else
          prefix_name(elem, {}, nil, "title")
        end
        t = elem.at(ns("./fmt-title")) and t["depth"] = level
      end

      # Label format templates — add Greek types with closing paren.
      def ol_label_template(_elem)
        super.merge(
          lowergreek: %{%<span class="fmt-label-delim">)</span>},
          uppergreek: %{%<span class="fmt-label-delim">)</span>},
        )
      end

      def add_toc_variant_title(elem, label_text)
        fmt = elem.at(ns("./fmt-title")) or return
        vt = Nokogiri::XML::Node.new("variant-title", elem.document)
        vt["type"] = "toc"
        vt.inner_html = label_text.to_s
        fmt.add_next_sibling(vt)
      end

      def move_norm_ref_to_sections(docxml); end

      include Init
    end
  end
end
