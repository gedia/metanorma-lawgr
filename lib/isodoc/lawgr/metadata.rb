require "isodoc"

module IsoDoc
  module Lawgr
    class Metadata < IsoDoc::Metadata
      def initialize(lang, script, locale, labels)
        super
        here = File.dirname(__FILE__)
      end

      def title(isoxml, _out)
        main = isoxml.at(ns("//bibdata/title[@language='el' and @type='main']"))
          &.children&.to_xml
        main ||= isoxml.at(ns("//bibdata/title[@type='main']"))
          &.children&.to_xml
        set(:doctitle, main)
      end

      def subtitle(isoxml, _out)
        main = isoxml.at(ns("//bibdata/title[@language='el' and @type='subtitle']"))
          &.children&.to_xml
        set(:docsubtitle, main)
      end

      def author(isoxml, _out)
        set(:publisher,
            isoxml.at(ns("//bibdata/contributor[role/@type='publisher']" \
                         "/organization/name"))&.text)
        fek(isoxml)
        super
      end

      def fek(isoxml)
        set(:fek_number, isoxml.at(ns("//bibdata/ext/fek/number"))&.text)
        set(:fek_series, isoxml.at(ns("//bibdata/ext/fek/series"))&.text)
        set(:fek_year, isoxml.at(ns("//bibdata/ext/fek/year"))&.text)
      end

      DOCTYPE_LABELS = {
        "act" => "Αριθμός Νόμου",
        "pd"  => "Αριθμός Π.Δ.",
        "ap"  => "Αριθμός Απόφασης",
        "egk" => "Αριθμός Εγκυκλίου",
      }.freeze

      def doctype(isoxml, _out)
        super
        dt = isoxml.at(ns("//bibdata/ext/doctype"))&.text
        lbl = isoxml.at(ns("//bibdata/ext/doctype-label"))&.text
        lbl ||= DOCTYPE_LABELS[dt] || dt
        set(:doctype_label, lbl)
      end

      def docid(isoxml, _out)
        dn = isoxml.at(ns("//bibdata/docidentifier"))&.text
        set(:docnumber, dn)
      end

      def unpublished(status)
        !%w[published withdrawn].include? status.downcase
      end
    end
  end
end
