require "roman-numerals"
require "metanorma/lawgr/greek_numerals"

module IsoDoc
  module Lawgr
    class Xref < IsoDoc::Xref
      STRUCTURAL_TYPES = %w[book part tmima chapter article
                            subarticle paragraph custom].freeze

      def clause_order_main(_docxml)
        [{ path: "//sections/clause | //sections/terms | " \
                 "//sections/definitions",
           multi: true }]
      end

      # Override main_anchor_names to implement Greek law numbering:
      # articles are numbered sequentially across the whole law,
      # paragraphs are numbered within each article.
      def main_anchor_names(xml)
        @inheritnumbering = xml.at(
          ns("//bibdata/ext/inheritnumbering")
        )&.text&.strip == "true"
        n = clause_counter
        clause_order_main(xml).each do |a|
          xml.xpath(ns(a[:path])).each do |c|
            lawgr_section_names(c, n, 1)
            a[:multi] or break
          end
        end
      end

      def lawgr_section_names(clause, num, lvl)
        unnumbered_section_name?(clause) and return num
        ctype = clause["type"]
        case ctype
        when "book", "part", "tmima", "chapter"
          lawgr_structural_names(clause, num, lvl)
        when "article"
          lawgr_article_names(clause, num, lvl)
        else
          section_names(clause, num, lvl)
        end
        num
      end

      # Structural containers (parts, books, etc.) are transparent
      # for article numbering: they get their own anchor but do not
      # consume a number from the article counter.
      def lawgr_structural_names(clause, article_num, lvl)
        c = clause_title(clause)
        title = c ? semx(clause, c, "title") : nil
        @anchors[clause["id"]] =
          { label: nil, xref: title, title: title,
            level: lvl, type: "clause",
            elem: @labels["clause"] }
        clause.xpath(ns(subclauses)).each do |child|
          lawgr_section_names(child, article_num, lvl + 1)
        end
      end

      def lawgr_article_names(clause, num, lvl)
        num.increment(clause)
        article_num_str = num.print
        lbl = labelled_autonum(@labels["article"], semx(clause, article_num_str))
        lawgr_article_anchor(clause, lbl, article_num_str, lvl)
        sub_num = clause_counter(0)
        clause.xpath(ns(subclauses)).each do |c|
          lawgr_child_of_article(c, sub_num, lvl + 1, article_num_str)
        end
      end

      def lawgr_article_anchor(clause, lbl, value, level)
        c = clause_title(clause)
        title = c ? semx(clause, c, "title") : nil
        @anchors[clause["id"]] =
          { label: lbl, xref: lbl, title: title,
            level: level, type: "clause",
            elem: @labels["article"], value: value }
      end

      # Children of an article can be subarticles or direct paragraphs.
      def lawgr_child_of_article(clause, num, lvl, prefix)
        unnumbered_section_name?(clause) and return
        ctype = clause["type"]
        case ctype
        when "subarticle"
          lawgr_subarticle_names(clause, num, lvl, prefix)
        when "custom"
          lawgr_custom_names(clause, num, lvl, prefix)
        when "paragraph", nil
          lawgr_paragraph_names(clause, num, lvl, prefix)
        else
          section_names(clause, num, lvl)
        end
      end

      def lawgr_subarticle_names(clause, num, lvl, prefix)
        num.increment(clause)
        display = @inheritnumbering ? "#{prefix}.#{num.print}" : num.print
        lbl = semx(clause, display)
        lawgr_subarticle_anchor(clause, lbl, lvl)
        para_num = clause_counter(0)
        custom_num = clause_counter(0)
        clause.xpath(ns(subclauses)).each do |c|
          if c["type"] == "custom"
            lawgr_custom_names(c, para_num, lvl + 1, display,
                               custom_num)
          else
            lawgr_paragraph_names(c, para_num, lvl + 1, display)
          end
        end
      end

      def lawgr_subarticle_anchor(clause, lbl, level)
        c = clause_title(clause)
        title = c ? semx(clause, c, "title") : nil
        @anchors[clause["id"]] =
          { label: lbl, xref: labelled_autonum(@labels["clause"], lbl),
            title: title, level: level, type: "clause",
            elem: @labels["clause"] }
      end

      # In Greek-law AsciiDoc, deep paragraphs (level=6/7) can end up
      # inside <p> elements in the XML.  Standard subclauses (./clause)
      # misses them, so we also look inside <p>.
      PARAGRAPH_SUBCLAUSES =
        "./clause | ./p/clause | ./references | ./term | " \
        "./terms | ./definitions".freeze

      # Custom clauses (e.g. "Α. Φυσική Πρόσβαση") get uppercase-Greek
      # numbering that is NOT inherited by children.  The parent's
      # paragraph counter is passed through so child paragraphs
      # continue the parent numbering sequence.
      def lawgr_custom_names(clause, para_num, lvl, prefix,
                             custom_num = nil)
        custom_num ||= clause_counter(0)
        custom_num.increment(clause)
        idx = custom_num.print.to_i
        greek = Metanorma::Lawgr::GreekNumerals::GREEK_UPPER_LETTERS[idx - 1] || idx.to_s
        lbl = semx(clause, greek)
        lawgr_custom_anchor(clause, lbl, lvl)
        clause.xpath(ns(PARAGRAPH_SUBCLAUSES)).each do |c|
          if c["type"] == "custom"
            lawgr_custom_names(c, para_num, lvl + 1, prefix)
          else
            lawgr_paragraph_names(c, para_num, lvl + 1, prefix)
          end
        end
      end

      def lawgr_custom_anchor(clause, lbl, level)
        c = clause_title(clause)
        title = c ? semx(clause, c, "title") : nil
        @anchors[clause["id"]] =
          { label: lbl, xref: lbl, title: title,
            level: level, type: "clause",
            elem: @labels["clause"] }
      end

      # Paragraphs and their sub-paragraphs (recursive).
      # prefix carries the inherited numbering chain (e.g. "3.1").
      def lawgr_paragraph_names(clause, num, lvl, prefix)
        unnumbered_section_name?(clause) and return
        ctype = clause["type"]
        if ctype == "paragraph" || ctype.nil?
          num.increment(clause)
          display = @inheritnumbering ? "#{prefix}.#{num.print}" : num.print
          lbl = semx(clause, display)
          lawgr_paragraph_anchor(clause, lbl, lvl)
          sub_num = clause_counter(0)
          clause.xpath(ns(PARAGRAPH_SUBCLAUSES)).each do |c|
            if c["type"] == "custom"
              lawgr_custom_names(c, sub_num, lvl + 1, display)
            else
              lawgr_paragraph_names(c, sub_num, lvl + 1, display)
            end
          end
        else
          section_names(clause, num, lvl)
        end
      end

      def lawgr_paragraph_anchor(clause, lbl, level)
        c = clause_title(clause)
        title = c ? semx(clause, c, "title") : nil
        @anchors[clause["id"]] =
          { label: lbl, xref: labelled_autonum(@labels["paragraph"], lbl),
            title: title, level: level, type: "clause",
            elem: @labels["paragraph"] }
      end
    end
  end
end
