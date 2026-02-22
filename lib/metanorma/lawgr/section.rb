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

      def clause_attrs(node)
        attrs = super
        heading = node.attr("heading")
        if heading && HEADING_TYPES.include?(heading)
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
