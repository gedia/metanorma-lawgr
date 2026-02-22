require "spec_helper"

RSpec.describe "Section processing" do
  it "processes structural hierarchy with heading attributes" do
    input = <<~INPUT
      #{ASCIIDOC_BLANK_HDR}

      [heading=book]
      == Γενικές διατάξεις

      [heading=part]
      === Πεδίο εφαρμογής

      [heading=chapter]
      ==== Βασικοί ορισμοί

      [heading=article]
      ===== Σκοπός

      Σκοπός του παρόντος είναι...
    INPUT
    output = Asciidoctor.convert(input, *OPTIONS)
    expect(output).to include('type="book"')
    expect(output).to include('type="part"')
    expect(output).to include('type="chapter"')
    expect(output).to include('type="article"')
  end

  it "processes articles with paragraphs" do
    input = <<~INPUT
      #{ASCIIDOC_BLANK_HDR}

      [heading=article]
      == Υποχρεώσεις τρίτων

      [heading=paragraph]
      === {empty}

      Η παρ. 1 του άρθρου 54Α αντικαθίσταται...

      [heading=paragraph]
      === {empty}

      Οι τυχόν παραλείψεις ή σφάλματα...
    INPUT
    output = Asciidoctor.convert(input, *OPTIONS)
    expect(output).to include('type="article"')
    expect(output).to include('type="paragraph"')
  end

  it "processes subarticles" do
    input = <<~INPUT
      #{ASCIIDOC_BLANK_HDR}

      [heading=article]
      == {empty}

      [heading=subarticle]
      === Λογική πρόσβαση

      [heading=paragraph]
      ==== {empty}

      Ο πάροχος διατηρεί και εφαρμόζει τις παρακάτω διαδικασίες.
    INPUT
    output = Asciidoctor.convert(input, *OPTIONS)
    expect(output).to include('type="subarticle"')
    expect(output).to include('type="paragraph"')
  end

  it "processes parts-only structure (no books, no chapters)" do
    input = <<~INPUT
      #{ASCIIDOC_BLANK_HDR}

      [heading=part]
      == Γενικές διατάξεις

      [heading=article]
      === Σκοπός

      Σκοπός...

      [heading=part]
      == Ειδικές διατάξεις

      [heading=article]
      === Φορολογικές ρυθμίσεις

      Ρυθμίσεις...
    INPUT
    output = Asciidoctor.convert(input, *OPTIONS)
    # Two parts, two articles
    expect(output.scan('type="part"').length).to eq 2
    expect(output.scan('type="article"').length).to eq 2
  end

  it "processes semantic text body sections" do
    input = <<~INPUT
      #{ASCIIDOC_BLANK_HDR}

      [type=general-provisions]
      == Γενικές διατάξεις

      [heading=article]
      === Σκοπός

      Test.

      [type=entry-into-force]
      == Έναρξη ισχύος

      [heading=article]
      === {empty}

      Η ισχύς αρχίζει...
    INPUT
    output = Asciidoctor.convert(input, *OPTIONS)
    expect(output).to include('type="general-provisions"')
    expect(output).to include('type="entry-into-force"')
  end

  it "processes single unnumbered paragraph" do
    input = <<~INPUT
      #{ASCIIDOC_BLANK_HDR}

      [heading=article]
      == {empty}

      [%unnumbered,heading=paragraph]
      === {blank}

      Υπόχρεος για την απόδοση...
    INPUT
    output = Asciidoctor.convert(input, *OPTIONS)
    expect(output).to include('type="paragraph"')
    expect(output).to include('unnumbered="true"')
  end
end
