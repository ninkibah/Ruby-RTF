require 'spec_helper'

describe RubyRTF::Document do
  it 'provides a font table' do
    doc = RubyRTF::Document.new
    table = nil
    expect(lambda { table = doc.font_table }).not_to raise_error
    expect(table).not_to be_nil
  end

  context 'colour table' do
    it 'provides a colour table' do
      doc = RubyRTF::Document.new
      tbl = nil
      expect(lambda { tbl = doc.colour_table }).not_to raise_error
      expect(tbl).not_to be_nil
    end

    it 'provdies access as color table' do
      doc = RubyRTF::Document.new
      tbl = nil
      expect(lambda { tbl = doc.color_table }).not_to raise_error
      expect(tbl).to eq doc.colour_table
    end
  end

  it 'provides a stylesheet'

  context 'defaults to' do
    it 'character set ansi' do
      expect(RubyRTF::Document.new.character_set).to eq :ansi
    end

    it 'font 0' do
      expect(RubyRTF::Document.new.default_font).to eq 0
    end
  end
end