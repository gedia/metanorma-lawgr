module Metanorma
  module Lawgr
    module Front
      def title(node, xml)
        ["el"].each do |lang|
          xml.title type: "main", language: lang,
                    format: "text/plain" do |t|
            t << (Metanorma::Utils.asciidoc_sub(node.attr("title")) ||
                  node.title)
          end
        end
      end

      def metadata_id(node, xml)
        dn = node.attr("docnumber")
        id = node.attr("docidentifier") and dn = id
        xml.docidentifier primary: "true" do |i|
          i << dn
        end
      end

      def metadata_ext(node, xml)
        super
        metadata_fek(node, xml)
      end

      def metadata_fek(node, xml)
        fek_number = node.attr("fek-number")
        fek_series = node.attr("fek-series")
        fek_year = node.attr("fek-year")
        return unless fek_number || fek_series || fek_year

        xml.fek do |fek|
          fek.number fek_number if fek_number
          fek.series fek_series if fek_series
          fek.year fek_year if fek_year
        end
      end

      def metadata_language(node, xml)
        languages = node&.attr("language")&.split(/, */) || %w[el]
        languages.each { |l| xml.language l }
      end

      def metadata_script(node, xml)
        scripts = node&.attr("script")&.split(/, */) || %w[Grek]
        scripts.each { |s| xml.script s }
      end
    end
  end
end
