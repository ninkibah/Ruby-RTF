# encoding: utf-8

require 'spec_helper'

describe RubyRTF::Parser do
  let(:parser) { RubyRTF::Parser.new }
  let(:doc) { parser.doc }

  it 'parses hello world' do
    src = '{\rtf1\ansi\deff0 {\fonttbl {\f0 Times New Roman;}}\f0 \fs60 Hello, World!}'
    expect(lambda { parser.parse(src) }).not_to raise_error
  end

  it 'returns a RTF::Document' do
    src = '{\rtf1\ansi\deff0 {\fonttbl {\f0 Times New Roman;}}\f0 \fs60 Hello, World!}'
    d = parser.parse(src)
    expect(d.is_a?(RubyRTF::Document)).to be true
  end

  it 'parses a default font (\deffN)' do
    src = '{\rtf1\ansi\deff10 {\fonttbl {\f10 Times New Roman;}}\f0 \fs60 Hello, World!}'
    d = parser.parse(src)
    expect(d.default_font).to eq 10
  end

  context 'invalid document' do
    it 'raises exception if \rtf is missing' do
      src = '{\ansi\deff0 {\fonttbl {\f0 Times New Roman;}}\f0 \fs60 Hello, World!}'
      expect(lambda { parser.parse(src) }).to raise_error(RubyRTF::InvalidDocument)
    end

    it 'raises exception if the document does not start with \rtf' do
      src = '{\ansi\deff0\rtf1 {\fonttbl {\f0 Times New Roman;}}\f0 \fs60 Hello, World!}'
      expect(lambda { parser.parse(src) }).to raise_error(RubyRTF::InvalidDocument)
    end

    it 'raises exception if the {}s are unbalanced' do
      src = '{\rtf1\ansi\deff0 {\fonttbl {\f0 Times New Roman;}\f0 \fs60 Hello, World!}'
      expect(lambda { parser.parse(src) }).to raise_error(RubyRTF::InvalidDocument)
    end
  end

  context '#parse' do
    it 'parses text into the current section' do
      src = '{\rtf1\ansi\deff10 {\fonttbl {\f10 Times New Roman;}}\f0 \fs60 Hello, World!}'
      d = parser.parse(src)
      expect(d.sections.first[:text]).to eq 'Hello, World!'
    end

    it 'adds a new section on {' do
      src = '{\rtf1 \fs60 Hello {\fs30 World}}'
      d = parser.parse(src)
      expect(d.sections.first[:modifiers][:font_size]).to eq 30
      expect(d.sections.first[:text]).to eq 'Hello '

      expect(d.sections.last[:modifiers][:font_size]).to eq 15
      expect(d.sections.last[:text]).to eq 'World'
    end

    it 'adds a new section on }' do
      src = '{\rtf1 \fs60 Hello {\fs30 World}\fs12 Goodbye, cruel world.}'

      section = parser.parse(src).sections
      expect(section[0][:modifiers][:font_size]).to eq 30
      expect(section[0][:text]).to eq 'Hello '

      expect(section[1][:modifiers][:font_size]).to eq 15
      expect(section[1][:text]).to eq 'World'

      expect(section[2][:modifiers][:font_size]).to eq 6
      expect(section[2][:text]).to eq 'Goodbye, cruel world.'
    end

    it 'inherits properly over {} groups' do
      src = '{\rtf1 \b\fs60 Hello {\i\fs30 World}\ul Goodbye, cruel world.}'

      section = parser.parse(src).sections
      expect(section[0][:modifiers][:font_size]).to eq 30
      expect(section[0][:modifiers][:bold]).to be true
      expect(section[0][:modifiers].has_key?(:italic)).to be false
      expect(section[0][:modifiers].has_key?(:underline)).to be false
      expect(section[0][:text]).to eq 'Hello '

      expect(section[1][:modifiers][:font_size]).to eq 15
      expect(section[1][:modifiers][:italic]).to be true
      expect(section[1][:modifiers][:bold]).to be true
      expect(section[1][:modifiers].has_key?(:underline)).to be false
      expect(section[1][:text]).to eq 'World'

      expect(section[2][:modifiers][:font_size]).to eq 30
      expect(section[2][:modifiers][:bold]).to be true
      expect(section[2][:modifiers][:underline]).to be true
      expect(section[2][:modifiers].has_key?(:italic)).to be false
      expect(section[2][:text]).to eq 'Goodbye, cruel world.'
    end

    it 'clears ul with ul0' do
      src = '{\rtf1 \ul\b Hello\b0\ul0 World}'
      section = parser.parse(src).sections
      expect(section[0][:modifiers][:bold]).to be true
      expect(section[0][:modifiers][:underline]).to be true
      expect(section[0][:text]).to eq 'Hello'

      expect(section[1][:modifiers][:bold]).to be_falsey
      expect(section[1][:modifiers][:underline]).to be_falsey
      expect(section[1][:text]).to eq 'World'
    end
  end

  context '#parse_control' do
    it 'parses a normal control' do
      expect(parser.parse_control("rtf")[0, 2]).to eq [:rtf, nil]
    end

    it 'parses a control with a value' do
      expect(parser.parse_control("f2")[0, 2]).to eq [:f, 2]
    end

    context 'unicode' do
      %w(u21487* u21487).each do |code|
        it "parses #{code}" do
          expect(parser.parse_control(code)[0, 2]).to eq [:u, 21487]
        end
      end

      %w(u-21487* u-21487).each do |code|
        it "parses #{code}" do
          expect(parser.parse_control(code)[0, 2]).to eq [:u, -21487]
        end
      end
    end

    it 'parses a hex control' do
      expect(parser.parse_control("'7e")[0, 2]).to eq [:hex, '~']
    end

    it 'parses a hex control with a string after it' do
      ctrl, val, current_pos = parser.parse_control("'7e25")
      expect(ctrl).to eq :hex
      expect(val).to eq '~'
      expect(current_pos).to eq 3
    end

    context "encoding is windows-1252" do
      it 'parses a hex control' do
        parser.encoding = 'windows-1252'
        expect(parser.parse_control("'93")[0, 2]).to eq [:hex, '“']
      end
    end

    [' ', '{', '}', '\\', "\r", "\n"].each do |stop|
      it "stops at a #{stop}" do
        expect(parser.parse_control("rtf#{stop}test")[0, 2]).to eq [:rtf, nil]
      end
    end

    it 'handles a non-zero current position' do
      expect(parser.parse_control('Test ansi test', 5)[0, 2]).to eq [:ansi, nil]
    end

    it 'advances the current positon' do
      expect(parser.parse_control('Test ansi{test', 5).last).to eq 9
    end

    it 'advances the current positon past the optional space' do
      expect(parser.parse_control('Test ansi test', 5).last).to eq 10
    end
  end

  context 'character set' do
    %w(ansi mac pc pca).each do |type|
      it "accepts #{type}" do
        src = "{\\rtf1\\#{type}\\deff0 {\\fonttbl {\\f0 Times New Roman;}}\\f0 \\fs60 Hello, World!}"
        doc = parser.parse(src)
        expect(doc.character_set).to eq type.to_sym
      end
    end
  end

  context 'font table' do
    it 'sets the font table into the document' do
      src = '{\rtf1{\fonttbl{\f0\froman Times;}{\f1\fnil Arial;}}}'
      doc = parser.parse(src)

      font = doc.font_table[0]
      expect(font.family_command).to eq :roman
      expect(font.name).to eq 'Times'
    end

    it 'parses an empty font table' do
      src = "{\\rtf1\\ansi\\ansicpg1252\\cocoartf1187\n{\\fonttbl}\n{\\colortbl;\\red255\\green255\\blue255;}\n}"
      doc = parser.parse(src)

      expect(doc.font_table).to eq []
    end

    context '#parse_font_table' do
      it 'parses a font table' do
        src = '{\f0\froman Times New Roman;}{\f1\fnil Arial;}}}'
        parser.parse_font_table(src, 0)
        tbl = doc.font_table

        expect(tbl.length).to eq 2
        expect(tbl[0].family_command).to eq :roman
        expect(tbl[0].name).to eq 'Times New Roman'

        expect(tbl[1].family_command).to eq :nil
        expect(tbl[1].name).to eq 'Arial'
      end

      it 'parses a font table without braces' do
        src = '\f0\froman\fcharset0 TimesNewRomanPSMT;}}'
        parser.parse_font_table(src, 0)
        tbl = doc.font_table
        expect(tbl[0].name).to eq 'TimesNewRomanPSMT'
      end

      it 'handles \r and \n in the font table' do
        src = "{\\f0\\froman Times New Roman;}\r{\\f1\\fnil Arial;}\n}}"
        parser.parse_font_table(src, 0)
        tbl = doc.font_table

        expect(tbl.length).to eq 2
        expect(tbl[0].family_command).to eq :roman
        expect(tbl[0].name).to eq 'Times New Roman'

        expect(tbl[1].family_command).to eq :nil
        expect(tbl[1].name).to eq 'Arial'
      end

      it 'the family command is optional' do
        src = '{\f0 Times New Roman;}}}'
        parser.parse_font_table(src, 0)
        tbl = doc.font_table
        expect(tbl[0].family_command).to eq :nil
        expect(tbl[0].name).to eq 'Times New Roman'
      end

      it 'does not require the numbering to be incremental' do
        src = '{\f77\froman Times New Roman;}{\f3\fnil Arial;}}}'
        parser.parse_font_table(src, 0)
        tbl = doc.font_table

        expect(tbl[77].family_command).to eq :roman
        expect(tbl[77].name).to eq 'Times New Roman'

        expect(tbl[3].family_command).to eq :nil
        expect(tbl[3].name).to eq 'Arial'
      end

      it 'accepts the \falt command' do
        src = '{\f0\froman Times New Roman{\*\falt Courier New};}}'
        parser.parse_font_table(src, 0)
        tbl = doc.font_table
        expect(tbl[0].name).to eq 'Times New Roman'
        expect(tbl[0].alternate_name).to eq 'Courier New'
      end

      it 'sets current pos to the closing }' do
        src = '{\f0\froman Times New Roman{\*\falt Courier New};}}'
        expect(parser.parse_font_table(src, 0)).to eq (src.length - 1)
      end

      it 'accepts the panose command' do
        src = '{\f0\froman\fcharset0\fprq2{\*\panose 02020603050405020304}Times New Roman{\*\falt Courier New};}}'
        parser.parse_font_table(src, 0)
        tbl = doc.font_table
        expect(tbl[0].panose).to eq '02020603050405020304'
        expect(tbl[0].name).to eq 'Times New Roman'
        expect(tbl[0].alternate_name).to eq 'Courier New'
      end

      %w(flomajor fhimajor fdbmajor fbimajor flominor fhiminor fdbminor fbiminor).each do |type|
        it "handles theme font type: #{type}" do
          src = "{\\f0\\#{type} Times New Roman;}}"
          parser.parse_font_table(src, 0)
          tbl = doc.font_table
          expect(tbl[0].name).to eq 'Times New Roman'
          expect(tbl[0].theme).to eq type[1..-1].to_sym
        end
      end

      [[0, :default], [1, :fixed], [2, :variable]].each do |pitch|
        it 'parses pitch information' do
          src = "{\\f0\\fprq#{pitch.first} Times New Roman;}}"
          parser.parse_font_table(src, 0)
          tbl = doc.font_table
          expect(tbl[0].name).to eq 'Times New Roman'
          expect(tbl[0].pitch).to eq pitch.last
        end
      end

      it 'parses the non-tagged font name' do
        src = '{\f0{\*\fname Arial;}Times New Roman;}}'
        parser.parse_font_table(src, 0)
        tbl = doc.font_table
        expect(tbl[0].name).to eq 'Times New Roman'
        expect(tbl[0].non_tagged_name).to eq 'Arial'
      end

      it 'parses the charset' do
        src = '{\f0\fcharset87 Times New Roman;}}'
        parser.parse_font_table(src, 0)
        tbl = doc.font_table
        expect(tbl[0].name).to eq 'Times New Roman'
        expect(tbl[0].character_set).to eq 87
      end
    end
  end

  context 'colour table' do
    it 'sets the colour table into the document' do
      src = '{\rtf1{\colortbl\red0\green0\blue0;\red127\green2\blue255;}}'
      doc = parser.parse(src)

      clr = doc.colour_table[0]
      expect(clr.red).to eq 0
      expect(clr.green).to eq 0
      expect(clr.blue).to eq 0

      clr = doc.colour_table[1]
      expect(clr.red).to eq 127
      expect(clr.green).to eq 2
      expect(clr.blue).to eq 255
    end

    it 'sets the first colour if missing' do
      src = '{\rtf1{\colortbl;\red255\green0\blue0;\red0\green0\blue255;}}'
      doc = parser.parse(src)

      clr = doc.colour_table[0]
      expect(clr.use_default?).to be true

      clr = doc.colour_table[1]
      expect(clr.red).to eq 255
      expect(clr.green).to eq 0
      expect(clr.blue).to eq 0
    end

    context '#parse_colour_table' do
      it 'parses \red \green \blue' do
        src = '\red2\green55\blue23;}'
        parser.parse_colour_table(src, 0)
        tbl = doc.colour_table
        expect(tbl[0].red).to eq 2
        expect(tbl[0].green).to eq 55
        expect(tbl[0].blue).to eq 23
      end

      it 'handles ctintN' do
        src = '\ctint22\red2\green55\blue23;}'
        parser.parse_colour_table(src, 0)
        tbl = doc.colour_table
        expect(tbl[0].tint).to eq 22
      end

      it 'handles cshadeN' do
        src = '\cshade11\red2\green55\blue23;}'
        parser.parse_colour_table(src, 0)
        tbl = doc.colour_table
        expect(tbl[0].shade).to eq 11
      end

      %w(cmaindarkone cmainlightone cmaindarktwo cmainlighttwo caccentone
         caccenttwo caccentthree caccentfour caccentfive caccentsix
         chyperlink cfollowedhyperlink cbackgroundone ctextone
         cbackgroundtwo ctexttwo).each do |theme|
        it "it allows theme item #{theme}" do
          src = "\\#{theme}\\red11\\green22\\blue33;}"
          parser.parse_colour_table(src, 0)
          tbl = doc.colour_table
          expect(tbl[0].theme).to eq theme[1..-1].to_sym
        end
      end

      it 'handles \r and \n' do
        src = "\\cshade11\\red2\\green55\r\n\\blue23;}"
        parser.parse_colour_table(src, 0)
        tbl = doc.colour_table
        expect(tbl[0].shade).to eq 11
        expect(tbl[0].red).to eq 2
        expect(tbl[0].green).to eq 55
        expect(tbl[0].blue).to eq 23
      end
    end
  end

  context 'stylesheet' do
    it 'parses a stylesheet'
  end

  context 'document info' do
    it 'parse the doocument info'
  end

  context '#handle_control' do
     it 'sets the font' do
      font = RubyRTF::Font.new('Times New Roman')
      doc.font_table[0] = font

      parser.handle_control(:f, 0, nil, 0)
      expect(parser.current_section[:modifiers][:font]).to eq font
    end

    it 'sets the font size' do
      parser.handle_control(:fs, 61, nil, 0)
      expect(parser.current_section[:modifiers][:font_size]).to eq 30.5
    end

    it 'sets bold' do
      parser.handle_control(:b, nil, nil, 0)
      expect(parser.current_section[:modifiers][:bold]).to be true
    end

     it 'unsets bold' do
       parser.current_section[:modifiers][:bold] = true
       parser.handle_control(:b, '0', nil, 0)
       expect(parser.current_section[:modifiers][:bold]).to be_falsey
     end

     it 'sets underline' do
      parser.handle_control(:ul, nil, nil, 0)
      expect(parser.current_section[:modifiers][:underline]).to be true
    end

    it 'sets italic' do
      parser.handle_control(:i, nil, nil, 0)
      expect(parser.current_section[:modifiers][:italic]).to be true
    end

     it 'unsets bold' do
       parser.current_section[:modifiers][:italic] = true
       parser.handle_control(:i, '0', nil, 0)
       expect(parser.current_section[:modifiers][:italic]).to be_falsey
     end

     %w(rquote lquote).each do |quote|
      it "sets a #{quote}" do
        parser.current_section[:text] = 'My code'
        parser.handle_control(quote.to_sym, nil, nil, 0)
        expect(doc.sections.last[:text]).to eq "'"
        expect(doc.sections.last[:modifiers][quote.to_sym]).to be true
      end
    end

    %w(rdblquote ldblquote).each do |quote|
      it "sets a #{quote}" do
        parser.current_section[:text] = 'My code'
        parser.handle_control(quote.to_sym, nil, nil, 0)
        expect(doc.sections.last[:text]).to eq '"'
        expect(doc.sections.last[:modifiers][quote.to_sym]).to be true
      end
    end

    it 'sets a hex character' do
      parser.current_section[:text] = 'My code'
      parser.handle_control(:hex, '~', nil, 0)
      expect(parser.current_section[:text]).to eq 'My code~'
    end

    it 'sets a unicode character < 1000 (char 643)' do
      parser.current_section[:text] = 'My code'
      parser.handle_control(:u, 643, nil, 0)
      expect(parser.current_section[:text]).to eq 'My codeك'
    end

    it 'sets a unicode character < 32768 (char 2603)' do
      parser.current_section[:text] = 'My code'
      parser.handle_control(:u, 2603, nil, 0)
      expect(parser.current_section[:text]).to eq 'My code☃'
    end

    it 'sets a unicode character < 32768 (char 21340)' do
      parser.current_section[:text] = 'My code'
      parser.handle_control(:u, 21340, nil, 0)
      expect(parser.current_section[:text]).to eq 'My code卜'
    end


    it 'sets a unicode character > 32767 (char 36,947)' do
      parser.current_section[:text] = 'My code'
      parser.handle_control(:u, -28589, nil, 0)
      expect(parser.current_section[:text]).to eq 'My code道'
    end

    context "uc0 skips a byte in the next unicode char" do
      it "u8278" do
        parser.current_section[:text] = 'My code '
        parser.handle_control(:uc, 0, nil, 0)
        parser.handle_control(:u, 8278, nil, 0)
        expect(parser.current_section[:text]).to eq 'My code x'
      end

      it "u8232 - does newline" do
        parser.current_section[:text] = "end."
        parser.handle_control(:uc, 0, nil, 0)
        parser.handle_control(:u, 8232, nil, 0)
        expect(doc.sections.last[:modifiers][:newline]).to be true
        expect(doc.sections.last[:text]).to eq "\n"
      end
    end

    context 'new line' do
      ['line', "\n"].each do |type|
        it "sets from #{type}" do
          parser.current_section[:text] = "end."
          parser.handle_control(type.to_sym, nil, nil, 0)
          expect(doc.sections.last[:modifiers][:newline]).to be true
          expect(doc.sections.last[:text]).to eq "\n"
        end
      end

      it 'ignores \r' do
        parser.current_section[:text] = "end."
        parser.handle_control(:"\r", nil, nil, 0)
        expect(parser.current_section[:text]).to eq "end."
      end
    end

    it 'inserts a \tab' do
      parser.current_section[:text] = "end."
      parser.handle_control(:tab, nil, nil, 0)
      expect(doc.sections.last[:modifiers][:tab]).to be true
      expect(doc.sections.last[:text]).to eq "\t"
    end

    it 'inserts a \super' do
      parser.current_section[:text] = "end."
      parser.handle_control(:super, nil, nil, 0)

      expect(parser.current_section[:modifiers][:superscript]).to be true
      expect(parser.current_section[:text]).to eq ""
    end

    it 'inserts a \sub' do
      parser.current_section[:text] = "end."
      parser.handle_control(:sub, nil, nil, 0)

      expect(parser.current_section[:modifiers][:subscript]).to be true
      expect(parser.current_section[:text]).to eq ""
    end

    it 'inserts a \strike' do
      parser.current_section[:text] = "end."
      parser.handle_control(:strike, nil, nil, 0)

      expect(parser.current_section[:modifiers][:strikethrough]).to be true
      expect(parser.current_section[:text]).to eq ""
    end

    it 'inserts a \scaps' do
      parser.current_section[:text] = "end."
      parser.handle_control(:scaps, nil, nil, 0)

      expect(parser.current_section[:modifiers][:smallcaps]).to be true
      expect(parser.current_section[:text]).to eq ""
    end

    it 'inserts an \emdash' do
      parser.current_section[:text] = "end."
      parser.handle_control(:emdash, nil, nil, 0)
      expect(doc.sections.last[:modifiers][:emdash]).to be true
      expect(doc.sections.last[:text]).to eq "--"
    end

    it 'inserts an \endash' do
      parser.current_section[:text] = "end."
      parser.handle_control(:endash, nil, nil, 0)
      expect(doc.sections.last[:modifiers][:endash]).to be true
      expect(doc.sections.last[:text]).to eq "-"
    end

    context 'escapes' do
      ['{', '}', '\\'].each do |escape|
        it "inserts an escaped #{escape}" do
          parser.current_section[:text] = "end."
          parser.handle_control(escape.to_sym, nil, nil, 0)
          expect(parser.current_section[:text]).to eq "end.#{escape}"
        end
      end
    end

    it 'adds a new section for a par command' do
      parser.current_section[:text] = 'end.'
      parser.handle_control(:par, nil, nil, 0)
      expect(parser.current_section[:text]).to eq ""
    end

    %w(pard plain).each do |type|
      it "resets the current sections information to default for #{type}" do
        parser.current_section[:modifiers][:bold] = true
        parser.current_section[:modifiers][:italic] = true
        parser.handle_control(type.to_sym, nil, nil, 0)

        expect(parser.current_section[:modifiers].has_key?(:bold)).to be false
        expect(parser.current_section[:modifiers].has_key?(:italic)).to be false
      end
    end

    context 'colour' do
      it 'sets the foreground colour' do
        doc.colour_table << RubyRTF::Colour.new(255, 0, 255)
        parser.handle_control(:cf, 0, nil, 0)
        expect(parser.current_section[:modifiers][:foreground_colour].to_s).to eq "[255, 0, 255]"
      end

      it 'sets the background colour' do
        doc.colour_table << RubyRTF::Colour.new(255, 0, 255)
        parser.handle_control(:cb, 0, nil, 0)
        expect(parser.current_section[:modifiers][:background_colour].to_s).to eq "[255, 0, 255]"
      end
    end

    context 'justification' do
      it 'handles left justify' do
        parser.handle_control(:ql, nil, nil, 0)
        expect(parser.current_section[:modifiers][:justification]).to eq :left
      end

      it 'handles right justify' do
        parser.handle_control(:qr, nil, nil, 0)
        expect(parser.current_section[:modifiers][:justification]).to eq :right
      end

      it 'handles full justify' do
        parser.handle_control(:qj, nil, nil, 0)
        expect(parser.current_section[:modifiers][:justification]).to eq :full
      end

      it 'handles centered' do
        parser.handle_control(:qc, nil, nil, 0)
        expect(parser.current_section[:modifiers][:justification]).to eq :center
      end
    end

    context 'indenting' do
      it 'handles first line indent' do
        parser.handle_control(:fi, 1000, nil, 0)
        expect(parser.current_section[:modifiers][:first_line_indent]).to eq 50
      end

      it 'handles left indent' do
        parser.handle_control(:li, 1000, nil, 0)
        expect(parser.current_section[:modifiers][:left_indent]).to eq 50
      end

      it 'handles right indent' do
        parser.handle_control(:ri, 1000, nil, 0)
        expect(parser.current_section[:modifiers][:right_indent]).to eq 50
      end
    end

    context 'margins' do
      it 'handles left margin' do
        parser.handle_control(:margl, 1000, nil, 0)
        expect(parser.current_section[:modifiers][:left_margin]).to eq 50
      end

      it 'handles right margin' do
        parser.handle_control(:margr, 1000, nil, 0)
        expect(parser.current_section[:modifiers][:right_margin]).to eq 50
      end

      it 'handles top margin' do
        parser.handle_control(:margt, 1000, nil, 0)
        expect(parser.current_section[:modifiers][:top_margin]).to eq 50
      end

      it 'handles bottom margin' do
        parser.handle_control(:margb, 1000, nil, 0)
        expect(parser.current_section[:modifiers][:bottom_margin]).to eq 50
      end
    end

    context 'paragraph spacing' do
      it 'handles space before' do
        parser.handle_control(:sb, 1000, nil, 0)
        expect(parser.current_section[:modifiers][:space_before]).to eq 50
      end

      it 'handles space after' do
        parser.handle_control(:sa, 1000, nil, 0)
        expect(parser.current_section[:modifiers][:space_after]).to eq 50
      end
    end

    context 'non breaking space' do
      it 'handles :~' do
        parser.current_section[:text] = "end."
        parser.handle_control(:~, nil, nil, 0)
        expect(doc.sections.last[:modifiers][:nbsp]).to be true
        expect(doc.sections.last[:text]).to eq " "
      end
    end
  end

  context 'sections' do
    it 'has sections' do
      expect(doc.sections).not_to be_nil
    end

    it 'sets an initial section' do
      expect(parser.current_section).not_to be_nil
    end

    context 'parsing full doc' do
      it 'parses changes to bold' do
        src = '{\rtf1\ansi\ansicpg1252\deff0\deflang1031{\fonttbl{\f0\fnil\fcharset0 MS Sans Serif;}}\viewkind4\uc1\par\pard Second paragraph with \b bold\b0  and \ul underline\ulnone  and \i italics\i0 , and now back to normal.}'
        d = parser.parse(src)

        sect = d.sections

        expect(sect.length).to eq 9
      end

      it 'parses font size changes' do
        src = '{\rtf1\ansi\ansicpg1252\deff0\deflang1031{\fonttbl{\f0\fnil\fcharset0 MS Sans Serif;}}\viewkind4\uc1\par\pard\f0\fs24 Heading\fs16 smaller }'
        d = parser.parse(src)

        sect = d.sections

        expect(sect.length).to eq 4
        expect(sect[-2][:modifiers][:font_size]).to eq 12.0
        expect(sect[-1][:modifiers][:font_size]).to eq 8.0
      end
    end

    context '#add_section!' do
      it 'does not add a section if the current :text is empty' do
        d = parser
        d.add_section!
        expect(doc.sections.length).to eq 0
      end

      it 'adds a section of the current section has text' do
        d = parser
        d.current_section[:text] = "Test"
        d.add_section!
        expect(doc.sections.length).to eq 1
      end

      it 'inherits the modifiers from the parent section' do
        d = parser
        d.current_section[:modifiers][:bold] = true
        d.current_section[:modifiers][:italics] = true
        d.current_section[:text] = "New text"

        d.add_section!

        d.current_section[:modifiers][:underline] = true

        sections = doc.sections
        expect(sections.first[:modifiers]).to eq({:bold => true, :italics => true})
        expect(d.current_section[:modifiers]).to eq({:bold => true, :italics => true, :underline => true})
      end
    end

    context '#reset_current_section!' do
      it 'resets the current sections modifiers' do
        d = parser
        d.current_section[:modifiers] = {:bold => true, :italics => true}
        d.current_section[:text] = "New text"

        d.add_section!
        d.reset_current_section!
        d.current_section[:modifiers][:underline] = true

        sections = doc.sections
        expect(sections.first[:modifiers]).to eq({:bold => true, :italics => true})
        expect(d.current_section[:modifiers]).to eq({:underline => true})
      end
    end

    context '#remove_last_section!' do
      it 'removes the last section' do
        d = parser
        d.current_section[:modifiers] = {:bold => true, :italics => true}
        d.current_section[:text] = "New text"

        d.add_section!

        d.current_section[:modifiers][:underline] = true

        expect(doc.sections.length).to eq 1
        expect(doc.sections.first[:text]).to eq 'New text'
      end
    end

    context 'tables' do
      def compare_table_results(table, data)
        expect(table.rows.length).to eq data.length

        data.each_with_index do |row, idx|
          end_positions = table.rows[idx].end_positions
          row[:end_positions].each_with_index do |size, cidx|
            expect(end_positions[cidx]).to eq size
          end

          cells = table.rows[idx].cells
          expect(cells.length).to eq row[:values].length

          row[:values].each_with_index do |items, vidx|
            sects = cells[vidx].sections
            items.each_with_index do |val, iidx|
              expect(sects[iidx][:text]).to eq val
            end
          end
        end
      end

      it 'parses a single row/column table' do
        src = '{\rtf1 Before Table' +
                '\trowd\trgaph180\cellx1440' +
                '\pard\intbl fee.\cell\row ' +
                'After table}'
        d = parser.parse(src)

        sect = d.sections
        expect(sect.length).to eq 3
        expect(sect[0][:text]).to eq 'Before Table'
        expect(sect[2][:text]).to eq 'After table'

        expect(sect[1][:modifiers][:table]).not_to be_nil
        table = sect[1][:modifiers][:table]

        compare_table_results(table, [{:end_positions => [72], :values => [['fee.']]}])
      end

      it 'parses a \trgaph180' do
        src = '{\rtf1 Before Table' +
                '\trowd\trgaph180\cellx1440' +
                '\pard\intbl fee.\cell\row ' +
                'After table}'
        d = parser.parse(src)

        table = d.sections[1][:modifiers][:table]
        expect(table.half_gap).to eq 9
      end

      it 'parses a \trleft240' do
        src = '{\rtf1 Before Table' +
                '\trowd\trgaph180\trleft240\cellx1440' +
                '\pard\intbl fee.\cell\row ' +
                'After table}'
        d = parser.parse(src)

        table = d.sections[1][:modifiers][:table]
        expect(table.left_margin).to eq 12
      end

      it 'parses a single row with multiple columns' do
        src = '{\rtf1 Before Table' +
                '\trowd\trgaph180\cellx1440\cellx2880\cellx1000' +
                '\pard\intbl fee.\cell' +
                '\pard\intbl fie.\cell' +
                '\pard\intbl foe.\cell\row ' +
                'After table}'
        d = parser.parse(src)

        sect = d.sections

        expect(sect.length).to eq 3
        expect(sect[0][:text]).to eq 'Before Table'
        expect(sect[2][:text]).to eq 'After table'

        expect(sect[1][:modifiers][:table]).not_to be_nil
        table = sect[1][:modifiers][:table]

        compare_table_results(table, [{:end_positions => [72, 144, 50], :values => [['fee.'], ['fie.'], ['foe.']]}])
      end

      it 'parses multiple rows and multiple columns' do
        src = '{\rtf1 \strike Before Table' +
                '\trowd\trgaph180\cellx1440\cellx2880\cellx1000' +
                '\pard\intbl\ul fee.\cell' +
                '\pard\intbl\i fie.\cell' +
                '\pard\intbl\b foe.\cell\row ' +
                '\trowd\trgaph180\cellx1000\cellx1440\cellx2880' +
                '\pard\intbl\i foo.\cell' +
                '\pard\intbl\b bar.\cell' +
                '\pard\intbl\ul baz.\cell\row ' +
                'After table}'
        d = parser.parse(src)

        sect = d.sections
        expect(sect.length).to eq 3
        expect(sect[0][:text]).to eq 'Before Table'
        expect(sect[2][:text]).to eq 'After table'

        expect(sect[1][:modifiers][:table]).not_to be_nil
        table = sect[1][:modifiers][:table]

        compare_table_results(table, [{:end_positions => [72, 144, 50], :values => [['fee.'], ['fie.'], ['foe.']]},
                                      {:end_positions => [50, 72, 144], :values => [['foo.'], ['bar.'], ['baz.']]}])
      end

      it 'parses a grouped table' do
        src = '{\rtf1 \strike Before Table' +
                '{\trowd\trgaph180\cellx1440\cellx2880\cellx1000' +
                  '\pard\intbl\ul fee.\cell' +
                  '\pard\intbl\i fie.\cell' +
                  '\pard\intbl\b foe.\cell\row}' +
                '{\trowd\trgaph180\cellx1000\cellx1440\cellx2880' +
                  '\pard\intbl\i foo.\cell' +
                  '\pard\intbl\b bar.\cell' +
                  '\pard\intbl\ul baz.\cell\row}' +
                'After table}'
        d = parser.parse(src)

        sect = d.sections
        expect(sect.length).to eq 3
        expect(sect[0][:text]).to eq 'Before Table'
        expect(sect[2][:text]).to eq 'After table'

        expect(sect[1][:modifiers][:table]).not_to be_nil
        table = sect[1][:modifiers][:table]

        compare_table_results(table, [{:end_positions => [72, 144, 50], :values => [['fee.'], ['fie.'], ['foe.']]},
                                      {:end_positions => [50, 72, 144], :values => [['foo.'], ['bar.'], ['baz.']]}])
      end

      it 'parses a new line inside a table cell' do
        src = '{\rtf1 Before Table' +
                '\trowd\trgaph180\cellx1440' +
                '\pard\intbl fee.\line fie.\cell\row ' +
                'After table}'
        d = parser.parse(src)

        sect = d.sections
        expect(sect.length).to eq 3
        expect(sect[0][:text]).to eq 'Before Table'
        expect(sect[2][:text]).to eq 'After table'
        table = sect[1][:modifiers][:table]

        compare_table_results(table, [{:end_positions => [72], :values => [["fee.", "\n", "fie."]]}])
      end

      it 'parses a new line inside a table cell' do
        src = '{\rtf1 Before Table' +
                '\trowd\trgaph180\cellx1440\cellx2880\cellx1000' +
                '\pard\intbl fee.\cell' +
                '\pard\intbl\cell' +
                '\pard\intbl fie.\cell\row ' +
                'After table}'
        d = parser.parse(src)

        sect = d.sections
        expect(sect.length).to eq 3
        expect(sect[0][:text]).to eq 'Before Table'
        expect(sect[2][:text]).to eq 'After table'
        table = sect[1][:modifiers][:table]

        compare_table_results(table, [{:end_positions => [72, 144, 50], :values => [["fee."], [""], ["fie."]]}])
      end

      it 'parses a grouped cell' do
        src = '{\rtf1 Before Table\trowd\cellx1440\cellx2880\cellx1000 \pard ' +
                '{\fs20 Familiar }{\cell }' +
                '{\fs20 Alignment }{\cell }' +
                '\pard \intbl {\fs20 Arcane Spellcaster Level}{\cell }' +
                '\pard {\b\fs18 \trowd \trgaph108\trleft-108\cellx1000\row }After table}'
        d = parser.parse(src)

        sect = d.sections

        expect(sect.length).to eq 3
        expect(sect[0][:text]).to eq 'Before Table'
        expect(sect[2][:text]).to eq 'After table'
        table = sect[1][:modifiers][:table]

        compare_table_results(table, [{:end_positions => [72, 144, 50],
                                       :values => [["Familiar "], ["Alignment "], ['Arcane Spellcaster Level']]}])
      end

      it 'parses cells' do
        src = '{\rtf1\trowd\trgaph108\trleft-108\cellx1440\cellx2880' +
                '\intbl{\fs20 Familiar }{\cell }' +
                '{\fs20 Alignment }{\cell }}'

        d = parser.parse(src)
        table = d.sections[0][:modifiers][:table]

        compare_table_results(table, [{:end_positions => [72, 144], :values => [['Familiar '], ['Alignment ']]}])
      end

      it 'parses blank rows' do
        src = '{\rtf1\trowd \trgaph108\trleft-108\cellx1440' +
                '\intbl{\fs20 Familiar }{\cell }' +
                '\pard\plain \intbl {\trowd \trgaph108\trleft-108\cellx1440\row } ' +
                'Improved animal}'
        d = parser.parse(src)

        sect = d.sections
        expect(sect.length).to eq 2
        expect(sect[1][:text]).to eq ' Improved animal'
        expect(sect[1][:modifiers]).to eq({})

        table = sect[0][:modifiers][:table]
        compare_table_results(table, [{:end_positions => [72], :values => [['Familiar ']]}])
      end
    end
  end
end
