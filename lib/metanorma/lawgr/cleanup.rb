module Metanorma
  module Lawgr
    module Cleanup
      def sections_cleanup(xmldoc)
        super
        heading_to_type(xmldoc)
        lawgr_structured_ids(xmldoc)
        edafio_cleanup(xmldoc)
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

      # ---- Structured clause IDs ----

      # Mapping of clause types to prefix strings for structured IDs.
      CLAUSE_TYPE_PREFIX = {
        "book" => "b",
        "part" => "pt",
        "tmima" => "t",
        "chapter" => "c",
        "article" => "a",
        "paragraph" => "p",
      }.freeze

      # Replace UUID-based clause IDs with human-readable structured IDs
      # derived from each clause's position in the document hierarchy.
      # Article numbering is contiguous across the entire document.
      # Custom and unrecognised types are transparent (they do not
      # contribute a path segment, and their children count at the
      # nearest structural ancestor).  Subarticle extends the article
      # segment with dot notation (a5.1).
      def lawgr_structured_ids(xmldoc)
        id_map = {}
        xmldoc.xpath("//clause[@type]").each do |clause|
          new_id = structured_clause_id(clause)
          next unless new_id
          old_id = clause["id"]
          next unless old_id
          id_map[old_id] = new_id
          clause["id"] = new_id
        end
        replace_id_references(xmldoc, id_map)
      end

      # Compute the structured ID for a clause from its path segments.
      def structured_clause_id(clause)
        return nil unless structural_clause?(clause)
        path = clause_structured_path(clause)
        result = path[:higher] + path[:article] + path[:paragraph]
        result.empty? ? nil : result
      end

      # Compute the structured path segments for a clause.
      # Returns a hash with :higher, :article, :paragraph keys.
      # - :higher — concatenated prefixes for book/part/tmima/chapter
      # - :article — "a{N}" with optional subarticle dot notation
      # - :paragraph — "p{N}" with optional nested paragraph dots
      # Article numbering is contiguous across the entire document.
      # Subarticle extends the article segment with dot notation.
      # Paragraph numbering restarts at each article/subarticle.
      def clause_structured_path(clause)
        chain = clause_ancestor_chain(clause)
        higher = ""
        article_nums = []
        paragraph_nums = []
        chain.each do |node|
          type = node["type"]
          case type
          when "book", "part", "tmima", "chapter"
            higher += "#{CLAUSE_TYPE_PREFIX[type]}#{clause_position_among_type(node)}"
          when "article"
            article_nums << article_document_position(node)
          when "subarticle"
            article_nums << clause_position_among_type(node)
          when "paragraph"
            paragraph_nums << clause_position_among_type(node)
          end
        end
        { higher: higher,
          article: article_nums.empty? ? "" : "a#{article_nums.join('.')}",
          paragraph: paragraph_nums.empty? ? "" : "p#{paragraph_nums.join('.')}" }
      end

      # 1-based position of an article among ALL articles in the
      # document (contiguous numbering regardless of parent
      # part/chapter/book).
      def article_document_position(node)
        node.document.xpath("//clause[@type='article']").each_with_index do |c, i|
          return i + 1 if c == node
        end
        nil
      end

      # Ancestor chain from root to clause (top-down), including the
      # clause itself.  Only clause elements are collected.
      def clause_ancestor_chain(clause)
        chain = []
        current = clause
        while current&.name == "clause"
          chain.unshift(current)
          current = current.parent
        end
        chain
      end

      # Nearest ancestor of a clause that is NOT a transparent
      # (custom / unrecognised) clause.
      def effective_clause_parent(clause)
        parent = clause.parent
        while parent&.name == "clause" && !structural_clause?(parent)
          parent = parent.parent
        end
        parent
      end

      # True when the clause has a type that occupies a structural
      # position in the hierarchy (i.e. it is NOT transparent).
      def structural_clause?(clause)
        type = clause["type"]
        CLAUSE_TYPE_PREFIX.key?(type) || type == "subarticle"
      end

      # 1-based position of a clause among all clauses of the same
      # type within its effective parent, flattening transparent
      # (custom / unrecognised) intermediate clauses.
      def clause_position_among_type(clause)
        parent = effective_clause_parent(clause)
        siblings = direct_typed_children(parent, clause["type"])
        (siblings.index { |c| c == clause } || 0) + 1
      end

      # Collect all clause children of a given type under +parent+,
      # flattening transparent intermediate clauses so that their
      # children are counted at the parent level.
      def direct_typed_children(parent, type)
        result = []
        parent.xpath("./clause").each do |child|
          if child["type"] == type
            result << child
          elsif !structural_clause?(child)
            result.concat(direct_typed_children(child, type))
          end
        end
        result
      end

      # Replace all attribute values in the document that match a key
      # in +id_map+ with the corresponding new value.
      def replace_id_references(xmldoc, id_map)
        return if id_map.empty?
        xmldoc.traverse do |node|
          next unless node.element?
          node.attributes.each do |name, attr|
            new_val = id_map[attr.value]
            node[name] = new_val if new_val
          end
        end
      end

      # ---- εδάφιο cleanup pipeline ----

      def edafio_cleanup(xmldoc)
        edafio_convert_ed_spans(xmldoc)
        edafio_strip_out_of_scope(xmldoc)
        edafio_merge_contiguous_lists(xmldoc)
        edafio_number_and_id(xmldoc)
        edafio_unwrap_groups(xmldoc)
      end

      # Convert explicit `<span class="ed">text</span>` pairs into
      # unwrapped text separated by `<eb/>` boundary elements.
      def edafio_convert_ed_spans(xmldoc)
        xmldoc.xpath('//p[span[@class="ed"]]').each do |p|
          spans = p.xpath('span[@class="ed"]')
          spans.each_with_index do |span, i|
            # Insert <eb/> boundary before this span (marks start of
            # a new εδάφιο).  Skip the first — the numbering phase
            # adds the initial marker.
            span.before(xmldoc.create_element("eb")) if i > 0
            # Replace span with its children (unwrap).
            span.children.each { |child| span.before(child) }
            span.remove
          end
        end
      end

      # True when +clause+ is eligible for εδάφιο processing:
      # either a paragraph clause, or an article/subarticle that
      # has no paragraph children (implicit p1).
      def edafio_eligible_clause?(clause)
        return false unless clause.name == "clause"

        return true if clause["type"] == "paragraph"
        %w[article subarticle].include?(clause["type"]) &&
          !clause.at("./clause[@type='paragraph']")
      end

      # Remove `<eb/>` elements that are NOT inside an eligible
      # clause body `<p>` or inside a list-item `<p>` within one.
      def edafio_strip_out_of_scope(xmldoc)
        xmldoc.xpath("//eb").each do |eb|
          parent_p = eb.parent
          next unless parent_p&.name == "p"

          # Check: is this <p> a direct child of an eligible clause?
          clause_parent = parent_p.parent
          if edafio_eligible_clause?(clause_parent)
            next # in-scope: clause body
          end

          # Check: is this <p> inside an <edafio-group> within an
          # eligible clause?
          if clause_parent&.name == "edafio-group"
            group_parent = clause_parent.parent
            if edafio_eligible_clause?(group_parent)
              next # in-scope: explicit εδάφιο group
            end
          end

          # Check: is this <p> inside an <li> within an eligible clause?
          if clause_parent&.name == "li"
            eligible = edafio_ancestor_eligible_clause(clause_parent)
            next if eligible # in-scope: list item
          end

          # Out of scope — remove.
          eb.remove
        end
      end

      # Walk up from a node to find an enclosing eligible clause
      # (paragraph, or article/subarticle without paragraphs).
      def edafio_ancestor_eligible_clause(node)
        cursor = node.parent
        while cursor
          return cursor if edafio_eligible_clause?(cursor)
          cursor = cursor.parent
        end
        nil
      end

      # When two consecutive <ol> elements within the same eligible
      # clause have contiguous numbering, treat them as a single
      # logical list.  Mark the second list with merged-list="true"
      # so that xref can treat its items as continuing from the first.
      def edafio_merge_contiguous_lists(xmldoc)
        edafio_eligible_clauses(xmldoc).each do |clause|
          ols = clause.xpath("./ol | ./edafio-group/ol")
          (1...ols.size).each do |i|
            prev_ol = ols[i - 1]
            curr_ol = ols[i]
            prev_count = prev_ol.xpath("./li").size
            start_val = curr_ol["start"]&.to_i
            if start_val && start_val == prev_count + 1
              curr_ol["merged-list"] = "true"
              curr_ol["merged-start"] = prev_count.to_s
            end
          end
        end
      end

      # Return all clauses eligible for εδάφιο processing.
      def edafio_eligible_clauses(xmldoc)
        xmldoc.xpath('//clause[@type]').select do |c|
          edafio_eligible_clause?(c)
        end
      end

      # Number εδάφια and assign stable IDs.
      # Paragraph body: contiguous across all direct <p> children.
      # List items: scoped to each <li>.
      def edafio_number_and_id(xmldoc)
        edafio_eligible_clauses(xmldoc).each do |clause|
          edafio_number_paragraph_body(clause)
          edafio_number_list_items(clause)
        end
      end

      # Number εδάφια across the direct <p> children and
      # <edafio-group> children of a paragraph clause (body text,
      # excluding <p> inside <li>).
      def edafio_number_paragraph_body(clause)
        prefix = edafio_para_prefix(clause)
        counter = 0
        clause.element_children.each do |child|
          case child.name
          when "p"
            counter = edafio_number_within_p(child, counter, prefix)
          when "edafio-group"
            counter = edafio_number_group(child, counter, prefix)
          end
        end
      end

      # Treat the entire <edafio-group> as a single εδάφιο.
      # Only the first <p> receives the <eb/> marker; subsequent
      # <p> elements inside the group are continuations.
      def edafio_number_group(group, counter, parent_id)
        first_p = group.at("./p")
        return counter unless first_p

        counter += 1
        if parent_id
          eb = group.document.create_element("eb")
          eb["edafio-n"] = counter.to_s
          eb["id"] = "#{parent_id}e#{counter}"
          if first_p.children.first
            first_p.children.first.before(eb)
          else
            first_p.add_child(eb)
          end
        end
        counter
      end

      # Number εδάφια within each <li> in the eligible clause.
      # Skip list items that belong to a nested eligible clause.
      def edafio_number_list_items(clause)
        clause.xpath(".//li").each do |li|
          next if edafio_ancestor_eligible_clause(li) != clause

          prefix = edafio_li_prefix(clause, li)
          counter = 0
          li.xpath("./p").each do |p|
            counter = edafio_number_within_p(p, counter, prefix)
          end
        end
      end

      # Compute the structured quick-ref prefix for an eligible clause
      # body, e.g. "a3.1p6" (article 3, subarticle 1, paragraph 6).
      # For articles/subarticles without paragraphs, appends implicit
      # "p1", e.g. "a2p1".
      def edafio_para_prefix(clause)
        path = clause_structured_path(clause)
        para_seg = path[:paragraph]
        para_seg = "p1" if para_seg.empty?
        path[:article] + para_seg
      end

      # Compute the structured quick-ref prefix for a list item,
      # e.g. "a9.1p3li3li1" for a nested list item.
      def edafio_li_prefix(clause, li)
        base = edafio_para_prefix(clause)
        li_parts = []
        current = li
        while current&.name == "li"
          idx = current.xpath("preceding-sibling::li").size + 1
          ol = current.parent
          idx += ol["merged-start"].to_i if ol&.name == "ol" && ol["merged-start"]
          li_parts.unshift(idx)
          current = current.ancestors.find { |a| a.name == "li" }
        end
        base + li_parts.map { |i| "li#{i}" }.join
      end

      # Unwrap all <edafio-group> elements after numbering, moving
      # their children into the parent element.
      def edafio_unwrap_groups(xmldoc)
        xmldoc.xpath("//edafio-group").each do |group|
          group.children.each { |child| group.before(child) }
          group.remove
        end
      end

      # Walk through a <p>, counting εδάφια delimited by <eb/> elements.
      # - First εδάφιο: insert <eb id="…e1" edafio-n="1"/> at the
      #   start of the <p> content.
      # - Subsequent εδάφια: set id and edafio-n on existing <eb/>.
      # Returns the updated counter.
      def edafio_number_within_p(p_elem, counter, parent_id)
        ebs = p_elem.xpath("./eb")
        # No markers → the whole <p> is one εδάφιο.
        counter += 1
        if parent_id
          eb1 = p_elem.document.create_element("eb")
          eb1["edafio-n"] = counter.to_s
          eb1["id"] = "#{parent_id}e#{counter}"
          if p_elem.children.first
            p_elem.children.first.before(eb1)
          else
            p_elem.add_child(eb1)
          end
        end
        ebs.each do |eb|
          counter += 1
          eb["edafio-n"] = counter.to_s
          eb["id"] = "#{parent_id}e#{counter}" if parent_id
        end
        p_elem["edafio-count"] = counter.to_s if counter > 0
        counter
      end
    end
  end
end
