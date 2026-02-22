module Metanorma
  module Lawgr
    module Section
      HEADING_TYPES = %w[book part section tmima chapter article
                         subarticle paragraph].freeze

      SEMANTIC_TYPES = %w[general-provisions substantive-provisions
                          organisational-provisions sanctions
                          delegating-provisions transitional-provisions
                          repealed-provisions entry-into-force].freeze

      # Greek law does not use standard StanDoc preface/main clause names.
      # Suppress automatic recognition of "foreword", "scope", etc.
      PREFACE_CLAUSE_NAMES = %w[donotrecognise-foreword
                                acknowledgements].freeze

      def sectiontype_streamline(ret)
        case ret
        when "foreword", "introduction" then "donotrecognise-foreword"
        else
          super
        end
      end

      # Override section_attributes to map heading= to type=.
      # The base standoc reads type= directly, but Greek law adoc
      # uses heading= for structural hierarchy (article, paragraph, etc.).
      def section_attributes(node)
        attrs = super
        heading = node.attr("heading")
        if heading && HEADING_TYPES.include?(heading)
          if attrs[:type] && attrs[:type] != heading
            attrs[:"semantic-type"] = attrs[:type]
          end
          attrs[:type] = heading
        end
        attrs
      end

      def title_validate(_root)
        nil
      end
    end
  end
end
