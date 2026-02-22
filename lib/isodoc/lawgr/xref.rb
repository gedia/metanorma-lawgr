require "roman-numerals"
require "metanorma/lawgr/greek_numerals"

module IsoDoc
  module Lawgr
    class Xref < IsoDoc::Xref
      STRUCTURAL_TYPES = %w[book part tmima chapter article
                            subarticle paragraph].freeze

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
        when "article"
          lawgr_article_names(clause, num, lvl)
        when "paragraph"
          # paragraphs at top level treated as plain clauses
          section_names(clause, num, lvl)
        else
          section_names(clause, num, lvl)
        end
        num
      end

      def lawgr_article_names(clause, num, lvl)
        num.increment(clause)
        article_num_str = num.print
        lbl = labelled_autonum(@labels["article"], semx(clause, article_num_str))
        lawgr_article_anchor(clause, lbl, article_num_str, lvl)
        i = clause_counter(0)
        clause.xpath(ns(subclauses)).each do |c|
          lawgr_paragraph_names(c, i, lvl + 1, clause, article_num_str)
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

      def lawgr_paragraph_names(clause, num, lvl, parent, article_num_str)
        unnumbered_section_name?(clause) and return
        ctype = clause["type"]
        if ctype == "paragraph" || ctype.nil?
          num.increment(clause)
          if @inheritnumbering
            display = "#{article_num_str}.#{num.print}"
          else
            display = num.print
          end
          lbl = semx(clause, display)
          lawgr_paragraph_anchor(clause, lbl, lvl)
          j = clause_counter(0)
          clause.xpath(ns(subclauses)).each do |c|
            section_names1(c, lbl, j.increment(c).print, lvl + 1)
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
