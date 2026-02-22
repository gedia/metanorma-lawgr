require "roman-numerals"
require "metanorma/lawgr/greek_numerals"

module IsoDoc
  module Lawgr
    class Xref < IsoDoc::Xref
      STRUCTURAL_TYPES = %w[book part tmima chapter article
                            subarticle paragraph].freeze

      ORGANISATIONAL_TYPES = %w[book part tmima chapter].freeze

      NONTERMINAL =
        "./clause | ./term | ./terms | ./definitions | ./references".freeze

      def clause_order_main(_docxml)
        [{ path: "//sections/clause | //sections/terms | " \
                 "//sections/definitions",
           multi: true }]
      end

      def main_anchor_names(xml)
        @defined_article_count = 0
        super
      end

      # Determine clause type from the `type` attribute.
      def clause_type(clause)
        clause["type"]
      end

      # Walk the Greek law structural hierarchy and assign anchors.
      # Overrides the default section_names to handle:
      # - Book ordinals (ΠΡΩΤΟ, ΔΕΥΤΕΡΟ…)
      # - Part/Chapter Greek letter numbering (Α', Β'…)
      # - Section Roman numbering (I, II…)
      # - Article continuous Arabic numbering
      # - Paragraph dot-separated numbering from article ancestry
      def section_names(clause, num, lvl)
        clause.nil? and return num
        ctype = clause_type(clause)

        case ctype
        when "book"
          label_book(clause, num, lvl)
        when "part"
          label_part(clause, num, lvl)
        when "tmima"
          label_tmima(clause, num, lvl)
        when "chapter"
          label_chapter(clause, num, lvl)
        when "article"
          label_article(clause, num, lvl)
        when "subarticle"
          label_subarticle(clause, num, lvl)
        when "paragraph"
          label_paragraph(clause, num, lvl)
        else
          label_generic(clause, num, lvl)
        end
        num
      end

      def section_names1(clause, num, level)
        ctype = clause_type(clause)
        case ctype
        when "article"
          label_article(clause, nil, level)
        when "subarticle"
          label_subarticle(clause, nil, level)
        when "paragraph"
          label_paragraph(clause, nil, level)
        else
          super
        end
      end

      private

      def label_book(clause, num, lvl)
        n = num.increment(clause).print.to_i
        ordinal = clause["ordinal"] ||
          Metanorma::Lawgr::GreekNumerals.book_ordinal(n) ||
          n.to_s
        lbl = "ΒΙΒΛΙΟ #{ordinal}"
        @anchors[clause["id"]] = {
          label: lbl, level: lvl, type: "clause",
          elem: @labels["book"] || "Βιβλίο",
          xref: lbl,
        }
        traverse_children(clause, lvl)
      end

      def label_part(clause, num, lvl)
        n = num.increment(clause).print.to_i
        letter = Metanorma::Lawgr::GreekNumerals
          .to_greek_letter_keraia(n)
        lbl = "ΜΕΡΟΣ #{letter}"
        @anchors[clause["id"]] = {
          label: lbl, level: lvl, type: "clause",
          elem: @labels["part"] || "Μέρος",
          xref: lbl,
        }
        traverse_children(clause, lvl)
      end

      def label_tmima(clause, num, lvl)
        n = num.increment(clause).print.to_i
        roman = RomanNumerals.to_roman(n)
        lbl = "ΤΜΗΜΑ #{roman}"
        @anchors[clause["id"]] = {
          label: lbl, level: lvl, type: "clause",
          elem: @labels["section"] || "Τμήμα",
          xref: lbl,
        }
        traverse_children(clause, lvl)
      end

      def label_chapter(clause, num, lvl)
        n = num.increment(clause).print.to_i
        letter = Metanorma::Lawgr::GreekNumerals
          .to_greek_letter_keraia(n)
        lbl = "ΚΕΦΑΛΑΙΟ #{letter}"
        @anchors[clause["id"]] = {
          label: lbl, level: lvl, type: "clause",
          elem: @labels["chapter"] || "Κεφάλαιο",
          xref: lbl,
        }
        traverse_children(clause, lvl)
      end

      def label_article(clause, _num, lvl)
        @defined_article_count ||= 0
        @defined_article_count += 1
        n = @defined_article_count
        lbl = "#{@labels['article'] || 'Άρθρο'} #{n}"
        @anchors[clause["id"]] = {
          label: lbl, level: lvl, type: "clause",
          elem: @labels["article"] || "Άρθρο",
          xref: lbl,
          article_number: n,
        }
        @current_article_number = n
        @current_subarticle_counter = 0
        @paragraph_numbering_stack = [n]
        traverse_children(clause, lvl)
      end

      def label_subarticle(clause, _num, lvl)
        @current_subarticle_counter ||= 0
        @current_subarticle_counter += 1
        article_n = @current_article_number || 0
        sub_n = @current_subarticle_counter
        display_num = "#{article_n}.#{sub_n}"
        @anchors[clause["id"]] = {
          label: display_num, level: lvl, type: "clause",
          elem: @labels["subarticle"] || "Υποάρθρο",
          xref: "#{@labels['subarticle'] || 'Υποάρθρο'} #{display_num}",
        }
        @paragraph_numbering_stack = [article_n, sub_n]
        @paragraph_child_counters = {}
        traverse_children(clause, lvl)
      end

      def label_paragraph(clause, _num, lvl)
        parent_id = clause.parent["id"]
        @paragraph_child_counters ||= {}
        @paragraph_child_counters[parent_id] ||= 0
        @paragraph_child_counters[parent_id] += 1

        para_n = @paragraph_child_counters[parent_id]

        # Build display number from ancestry stack
        parent_stack = paragraph_ancestry_stack(clause)
        display_num = (parent_stack + [para_n]).join(".")

        elem_label = @labels["paragraph"] || "Παράγραφος"
        @anchors[clause["id"]] = {
          label: display_num, level: lvl, type: "paragraph",
          elem: elem_label,
          xref: "#{elem_label} #{display_num}",
        }

        # Push for child paragraphs
        saved_stack = @paragraph_numbering_stack
        @paragraph_numbering_stack = parent_stack + [para_n]
        traverse_children(clause, lvl)
        @paragraph_numbering_stack = saved_stack
      end

      def paragraph_ancestry_stack(clause)
        @paragraph_numbering_stack || []
      end

      def label_generic(clause, num, lvl)
        lbl = num.increment(clause).print
        @anchors[clause["id"]] = {
          label: lbl, level: lvl, type: "clause",
          elem: @labels["clause"],
          xref: l10n("#{@labels['clause']} #{lbl}"),
        }
        traverse_children(clause, lvl)
      end

      def traverse_children(clause, lvl)
        counters = {}
        clause.xpath(ns(NONTERMINAL)).each do |c|
          ctype = clause_type(c) || "generic"
          counters[ctype] ||= ::IsoDoc::XrefGen::Counter.new
          section_names(c, counters[ctype], lvl + 1)
        end
      end
    end
  end
end
