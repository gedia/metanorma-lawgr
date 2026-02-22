require "fileutils"

module IsoDoc
  module Lawgr
    module BaseConvert
      def middle_clause(_docxml)
        "//clause[parent::sections]"
      end

      def norm_ref_xpath
        "//null"
      end

      def bibliography_xpath
        "//bibliography/clause[.//references] | " \
          "//bibliography/references"
      end

      def convert_i18n_init1(docxml)
        super
        @lang = "el" if docxml.xpath(ns("//bibdata/language")).empty?
      end
    end
  end
end
