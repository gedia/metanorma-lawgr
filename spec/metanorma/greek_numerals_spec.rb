require "spec_helper"
require "metanorma/lawgr/greek_numerals"

RSpec.describe Metanorma::Lawgr::GreekNumerals do
  describe ".to_greek_lower" do
    it "converts 1-5 to basic letters" do
      expect(described_class.to_greek_lower(1)).to eq "α"
      expect(described_class.to_greek_lower(2)).to eq "β"
      expect(described_class.to_greek_lower(3)).to eq "γ"
      expect(described_class.to_greek_lower(4)).to eq "δ"
      expect(described_class.to_greek_lower(5)).to eq "ε"
    end

    it "converts 6 to στ (digraph, not ζ)" do
      expect(described_class.to_greek_lower(6)).to eq "στ"
    end

    it "converts 7-9 correctly" do
      expect(described_class.to_greek_lower(7)).to eq "ζ"
      expect(described_class.to_greek_lower(8)).to eq "η"
      expect(described_class.to_greek_lower(9)).to eq "θ"
    end

    it "converts 10 to ι" do
      expect(described_class.to_greek_lower(10)).to eq "ι"
    end

    it "converts teens correctly" do
      expect(described_class.to_greek_lower(11)).to eq "ια"
      expect(described_class.to_greek_lower(16)).to eq "ιστ"
      expect(described_class.to_greek_lower(19)).to eq "ιθ"
    end

    it "converts 20+ correctly" do
      expect(described_class.to_greek_lower(20)).to eq "κ"
      expect(described_class.to_greek_lower(21)).to eq "κα"
      expect(described_class.to_greek_lower(23)).to eq "κγ"
    end

    it "returns empty string for 0 or negative" do
      expect(described_class.to_greek_lower(0)).to eq ""
      expect(described_class.to_greek_lower(-1)).to eq ""
    end
  end

  describe ".to_greek_upper" do
    it "returns uppercase" do
      expect(described_class.to_greek_upper(1)).to eq "Α"
      expect(described_class.to_greek_upper(6)).to eq "ΣΤ"
      expect(described_class.to_greek_upper(16)).to eq "ΙΣΤ"
    end
  end

  describe ".to_greek_double" do
    it "produces double Greek for υποπερίπτωση" do
      expect(described_class.to_greek_double(1, 1)).to eq "αα"
      expect(described_class.to_greek_double(1, 2)).to eq "αβ"
      expect(described_class.to_greek_double(2, 1)).to eq "βα"
      expect(described_class.to_greek_double(6, 3)).to eq "στγ"
    end
  end

  describe ".to_greek_letter_keraia" do
    it "produces uppercase Greek letter with keraia" do
      expect(described_class.to_greek_letter_keraia(1)).to eq "Α'"
      expect(described_class.to_greek_letter_keraia(2)).to eq "Β'"
      expect(described_class.to_greek_letter_keraia(3)).to eq "Γ'"
    end

    it "returns empty for out of range" do
      expect(described_class.to_greek_letter_keraia(0)).to eq ""
      expect(described_class.to_greek_letter_keraia(26)).to eq ""
    end
  end

  describe ".book_ordinal" do
    it "returns Greek ordinal words" do
      expect(described_class.book_ordinal(1)).to eq "ΠΡΩΤΟ"
      expect(described_class.book_ordinal(2)).to eq "ΔΕΥΤΕΡΟ"
      expect(described_class.book_ordinal(5)).to eq "ΠΕΜΠΤΟ"
      expect(described_class.book_ordinal(10)).to eq "ΔΕΚΑΤΟ"
    end

    it "returns nil for out of range" do
      expect(described_class.book_ordinal(0)).to be_nil
      expect(described_class.book_ordinal(11)).to be_nil
    end
  end
end
