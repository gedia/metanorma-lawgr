require "spec_helper"
require "nokogiri"

RSpec.describe "Εδάφιο processing" do
  # ── TreeProcessor: automatic eb:[] insertion ──────────────────

  it "inserts eb:[] markers between source lines in a paragraph" do
    input = <<~INPUT
      #{ASCIIDOC_BLANK_HDR}

      [heading=article]
      == {empty}

      [heading=paragraph]
      === {empty}

      Πρώτη πρόταση.
      Δεύτερη πρόταση.
      Τρίτη πρόταση.
    INPUT
    output = Asciidoctor.convert(input, *OPTIONS)
    xml = Nokogiri::XML(output)
    para_clause = xml.at('//xmlns:clause[@type="paragraph"]',
                         "xmlns" => "https://www.metanorma.org/ns/lawgr")
    ebs = para_clause.xpath(".//xmlns:eb",
                            "xmlns" => "https://www.metanorma.org/ns/lawgr")
    expect(ebs.size).to eq 2
  end

  it "does not insert markers when paragraph has only one line" do
    input = <<~INPUT
      #{ASCIIDOC_BLANK_HDR}

      [heading=article]
      == {empty}

      [heading=paragraph]
      === {empty}

      Μόνο μία πρόταση.
    INPUT
    output = Asciidoctor.convert(input, *OPTIONS)
    expect(output).not_to include("<eb")
  end

  it "skips automatic markers when [.ed] spans are present" do
    input = <<~INPUT
      #{ASCIIDOC_BLANK_HDR}

      [heading=article]
      == {empty}

      [heading=paragraph]
      === {empty}

      [.ed]#Πρώτη πρόταση.# [.ed]#Δεύτερη πρόταση.#
    INPUT
    output = Asciidoctor.convert(input, *OPTIONS)
    # [.ed] blocks should produce <eb/> via cleanup, not TreeProcessor
    xml = Nokogiri::XML(output)
    para_clause = xml.at('//xmlns:clause[@type="paragraph"]',
                         "xmlns" => "https://www.metanorma.org/ns/lawgr")
    ebs = para_clause.xpath(".//xmlns:eb",
                            "xmlns" => "https://www.metanorma.org/ns/lawgr")
    expect(ebs.size).to eq 1
  end

  # ── Cleanup: out-of-scope stripping ──────────────────────────

  it "strips <eb/> outside paragraph clauses" do
    input = <<~INPUT
      #{ASCIIDOC_BLANK_HDR}

      [heading=article]
      == Τίτλος

      Γραμμή ένα.
      Γραμμή δύο.
    INPUT
    output = Asciidoctor.convert(input, *OPTIONS)
    xml = Nokogiri::XML(output)
    # The article-level paragraph is NOT inside a [heading=paragraph]
    # clause, so <eb/> should have been stripped.
    article = xml.at('//xmlns:clause[@type="article"]',
                     "xmlns" => "https://www.metanorma.org/ns/lawgr")
    ebs = article.xpath(".//xmlns:eb",
                        "xmlns" => "https://www.metanorma.org/ns/lawgr")
    expect(ebs.size).to eq 0
  end

  # ── Cleanup: numbering and IDs ───────────────────────────────

  it "numbers εδάφια and assigns IDs in paragraph body" do
    input = <<~INPUT
      #{ASCIIDOC_BLANK_HDR}

      [heading=article]
      == {empty}

      [heading=paragraph]
      === {empty}

      Πρώτη πρόταση.
      Δεύτερη πρόταση.
      Τρίτη πρόταση.
    INPUT
    output = Asciidoctor.convert(input, *OPTIONS)
    xml = Nokogiri::XML(output)
    ns = { "xmlns" => "https://www.metanorma.org/ns/lawgr" }
    para_clause = xml.at('//xmlns:clause[@type="paragraph"]', ns)

    # Should have a bookmark for εδάφιο 1
    bm = para_clause.at(".//xmlns:bookmark", ns)
    expect(bm).not_to be_nil
    expect(bm["id"]).to match(/_e1$/)

    # Should have 2 <eb/> for εδάφια 2 and 3
    ebs = para_clause.xpath(".//xmlns:eb", ns)
    expect(ebs.size).to eq 2
    expect(ebs[0]["edafio-n"]).to eq "2"
    expect(ebs[0]["id"]).to match(/_e2$/)
    expect(ebs[1]["edafio-n"]).to eq "3"
    expect(ebs[1]["id"]).to match(/_e3$/)

    # edafio-count on <p>
    p_elem = para_clause.at("./xmlns:p", ns)
    expect(p_elem["edafio-count"]).to eq "3"
  end

  it "numbers εδάφια within list items" do
    input = <<~INPUT
      #{ASCIIDOC_BLANK_HDR}

      [heading=article]
      == {empty}

      [heading=paragraph]
      === {empty}

      Εισαγωγική πρόταση:

      . Πρώτο στοιχείο.
      . Δεύτερο στοιχείο.
    INPUT
    output = Asciidoctor.convert(input, *OPTIONS)
    xml = Nokogiri::XML(output)
    ns = { "xmlns" => "https://www.metanorma.org/ns/lawgr" }

    # Each single-line li should have edafio-count="1"
    lis = xml.xpath('//xmlns:clause[@type="paragraph"]//xmlns:li', ns)
    expect(lis.size).to eq 2
    lis.each do |li|
      p = li.at("./xmlns:p", ns)
      expect(p["edafio-count"]).to eq "1"
    end
  end

  # ── GreekNumerals.edafio_ordinal ─────────────────────────────

  it "returns correct ordinal words for εδάφια 1-10" do
    gn = Metanorma::Lawgr::GreekNumerals
    expect(gn.edafio_ordinal(1)).to eq "πρώτο"
    expect(gn.edafio_ordinal(2)).to eq "δεύτερο"
    expect(gn.edafio_ordinal(3)).to eq "τρίτο"
    expect(gn.edafio_ordinal(5)).to eq "πέμπτο"
    expect(gn.edafio_ordinal(8)).to eq "όγδοο"
    expect(gn.edafio_ordinal(10)).to eq "δέκατο"
  end

  it "falls back to Arabic numeral for εδάφιο > 10" do
    gn = Metanorma::Lawgr::GreekNumerals
    expect(gn.edafio_ordinal(11)).to eq "11"
    expect(gn.edafio_ordinal(99)).to eq "99"
  end

  it "returns string representation for zero or negative" do
    gn = Metanorma::Lawgr::GreekNumerals
    expect(gn.edafio_ordinal(0)).to eq "0"
    expect(gn.edafio_ordinal(-1)).to eq "-1"
  end
end
