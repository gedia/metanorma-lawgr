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
        @structural_counters = {}
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
      # Each structural type has its own sequential counter; parts
      # are labelled ΜΕΡΟΣ Α, Β, Γ… (uppercase Greek letters).
      def lawgr_structural_names(clause, article_num, lvl)
        ctype = clause["type"]
        @structural_counters[ctype] ||= clause_counter(0)
        @structural_counters[ctype].increment(clause)
        idx = @structural_counters[ctype].print.to_i
        lbl = structural_label(ctype, idx, clause)
        c = clause_title(clause)
        title = c ? semx(clause, c, "title") : nil
        @anchors[clause["id"]] =
          { label: lbl, xref: lbl, title: title,
            level: lvl, type: "clause",
            elem: @labels[ctype] || @labels["clause"] }
        clause.xpath(ns(subclauses)).each do |child|
          lawgr_section_names(child, article_num, lvl + 1)
        end
      end

      # Greek uppercase without accents (accents are dropped in
      # all-caps Greek text per typographic convention).
      def greek_upcase(str)
        str.upcase
          .unicode_normalize(:nfd)
          .gsub(/\p{Mn}/, "")
          .unicode_normalize(:nfc)
      end

      # Build the label for a structural section.
      # Parts:    ΜΕΡΟΣ Α, ΜΕΡΟΣ Β   (uppercase Greek letters)
      # Chapters: ΚΕΦΑΛΑΙΟ Α, Β      (uppercase Greek letters)
      # Books:    ΒΙΒΛΙΟ ΠΡΩΤΟ       (ordinal words)
      # Tmima:    ΤΜΗΜΑ Α            (uppercase Greek letters)
      def structural_label(ctype, idx, clause)
        type_label = greek_upcase(@labels[ctype] || ctype)
        if ctype == "book"
          ordinal = Metanorma::Lawgr::GreekNumerals.book_ordinal(idx)
          num = ordinal || Metanorma::Lawgr::GreekNumerals::GREEK_UPPER_LETTERS[idx - 1] || idx.to_s
        else
          num = Metanorma::Lawgr::GreekNumerals::GREEK_UPPER_LETTERS[idx - 1] || idx.to_s
        end
        labelled_autonum(type_label, semx(clause, num))
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
        # Article without paragraph children → implicit p1 εδάφια
        unless clause.at(ns("./clause[@type='paragraph']"))
          lawgr_edafio_anchors(clause, lvl + 1)
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
        # Subarticle without paragraph children → implicit p1 εδάφια
        unless clause.at(ns("./clause[@type='paragraph']"))
          lawgr_edafio_anchors(clause, lvl + 1)
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

      # Override list_item_value to produce proper Greek
      # numerals for :lowergreek (α, β… στ, ζ… ι, ια…) and
      # :uppergreek (Α, Β… ΣΤ, Ζ… Ι, ΙΑ…) lists, bypassing
      # Counter#listlabel which doesn't know these types.
      def list_item_value(entry, counter, depth, opts)
        type = entry.parent["type"]
        if type == "lowergreek" || type == "uppergreek"
          counter.increment(entry)
          idx = counter.print&.to_i
          return [nil, nil] if idx.nil? || idx <= 0
          label = if type == "uppergreek"
                    Metanorma::Lawgr::GreekNumerals.to_greek_upper(idx)
                  else
                    Metanorma::Lawgr::GreekNumerals.to_greek_lower(idx)
                  end
          s = semx(entry, label)
          [label,
           list_item_anchor_label(s, opts[:list_anchor], opts[:prev_label],
                                  opts[:refer_list])]
        else
          super
        end
      end

      def lawgr_paragraph_anchor(clause, lbl, level)
        c = clause_title(clause)
        title = c ? semx(clause, c, "title") : nil
        @anchors[clause["id"]] =
          { label: lbl, xref: labelled_autonum(@labels["paragraph"], lbl),
            title: title, level: level, type: "clause",
            elem: @labels["paragraph"] }
        lawgr_edafio_anchors(clause, level + 1)
      end

      EDAFIO_LABEL = "εδάφιο".freeze

      # Register xref anchors for every εδάφιο inside an eligible
      # clause (paragraph, or article/subarticle without paragraphs).
      # IDs were assigned during cleanup:
      #   - <eb id="…e1" edafio-n="1"/> at the start of each <p>
      #   - <eb id="…eN" edafio-n="N"/> between sentences for N > 1
      def lawgr_edafio_anchors(clause, level)
        # Body εδάφια (direct <p> children of the clause)
        edafio_register_p_group(clause.xpath(ns("./p")), level)
        # List-item εδάφια
        clause.xpath(ns(".//li")).each do |li|
          edafio_register_p_group(li.xpath(ns("./p")), level)
        end
      end

      # Given a NodeSet of <p> elements, register anchors for every
      # <eb id="..."/> within them.
      def edafio_register_p_group(p_nodes, level)
        p_nodes.each do |p|
          count = p["edafio-count"]&.to_i
          next unless count && count > 0
          p.xpath(ns("./eb[@id]")).each do |eb|
            n = eb["edafio-n"]&.to_i
            next unless n && n > 0
            edafio_register_anchor(eb["id"], n, level)
          end
        end
      end

      def edafio_register_anchor(id, n, level)
        return unless id

        ordinal = Metanorma::Lawgr::GreekNumerals.edafio_ordinal(n)
        lbl = "<semx element='autonum' source='#{id}'>#{ordinal}</semx>"
        @anchors[id] =
          { label: lbl,
            xref: labelled_autonum(EDAFIO_LABEL, lbl),
            level: level, type: "edafio",
            elem: EDAFIO_LABEL }
      end
    end
  end
end
