module Metanorma
  module Lawgr
    module GreekNumerals
      ONES = ["", "α", "β", "γ", "δ", "ε", "στ", "ζ", "η", "θ"].freeze
      TENS = ["", "ι", "κ", "λ", "μ", "ν", "ξ", "ο", "π", "ϟ"].freeze

      BOOK_ORDINALS = [
        "", "ΠΡΩΤΟ", "ΔΕΥΤΕΡΟ", "ΤΡΙΤΟ", "ΤΕΤΑΡΤΟ", "ΠΕΜΠΤΟ",
        "ΕΚΤΟ", "ΕΒΔΟΜΟ", "ΟΓΔΟΟ", "ΕΝΑΤΟ", "ΔΕΚΑΤΟ"
      ].freeze

      EDAFIO_ORDINALS = [
        "", "πρώτο", "δεύτερο", "τρίτο", "τέταρτο", "πέμπτο",
        "έκτο", "έβδομο", "όγδοο", "ένατο", "δέκατο"
      ].freeze

      GREEK_UPPER_LETTERS = %w[
        Α Β Γ Δ Ε Ζ Η Θ Ι Κ Λ Μ Ν Ξ Ο Π Ρ Σ Τ Υ Φ Χ Ψ Ω
      ].freeze

      # Proper Greek lowercase numeral (for περίπτωση numbering).
      # 1→α, 5→ε, 6→στ, 10→ι, 16→ιστ, 23→κγ
      def self.to_greek_lower(n)
        return "" if n <= 0

        tens = n / 10
        ones = n % 10
        "#{TENS[tens]}#{ONES[ones]}"
      end

      def self.to_greek_upper(n)
        to_greek_lower(n).upcase
      end

      # Double Greek (for υποπερίπτωση numbering).
      # Parent α, child 1 → αα; parent στ, child 3 → στγ
      def self.to_greek_double(parent_n, child_n)
        "#{to_greek_lower(parent_n)}#{to_greek_lower(child_n)}"
      end

      # Uppercase Greek letter with keraia for Part/Chapter numbering.
      # 1→Α', 2→Β', 24→Ω'
      def self.to_greek_letter_keraia(n)
        return "" if n <= 0 || n > GREEK_UPPER_LETTERS.length

        "#{GREEK_UPPER_LETTERS[n - 1]}'"
      end

      # Εδάφιο ordinal word (neuter gender, lowercase).
      # 1→πρώτο, 2→δεύτερο, etc.
      # Falls back to Arabic numeral string for n > 10.
      def self.edafio_ordinal(n)
        return n.to_s if n <= 0
        return EDAFIO_ORDINALS[n] if n < EDAFIO_ORDINALS.length

        n.to_s
      end

      # Book ordinal word (neuter gender, uppercase).
      # 1→ΠΡΩΤΟ, 2→ΔΕΥΤΕΡΟ, etc.
      # Returns nil if beyond the built-in table.
      def self.book_ordinal(n)
        return nil if n <= 0 || n >= BOOK_ORDINALS.length

        BOOK_ORDINALS[n]
      end
    end
  end
end
