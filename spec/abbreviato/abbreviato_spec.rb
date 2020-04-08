require "spec_helper"
require "byebug"
require "awesome_print"
require "brakecheck"

describe "Abbreviato" do
  NBSP = Nokogiri::HTML("&nbsp;").text

  describe "normal strings" do
    it "handles nil" do
      result, truncated = Abbreviato.truncate(nil)
      expect(result).to be_nil
      expect(truncated).to be_falsey
    end
    it_does_not_truncate "empty html text with longer length",
      with: { max_length: 99 },
      source: '',
      expected: ''
    it_does_not_truncate "no html text with longer length",
      with: { max_length: 99 },
      source: "This is some text",
      expected: "<p>This is some text</p>"
    it_truncates "no html text with shorter length, no tail",
      with: { max_length: 12, tail: "" },
      source: "some text",
      expected: "<p>some </p>"
    it_truncates "no html text with shorter length, nil tail",
      with: { max_length: 12, tail: nil },
      source: "some text",
      expected: "<p>some </p>"
    it_truncates "no html text with shorter length, with tail",
      with: { max_length: 17 },
      source: "This is some text",
      expected: "<p>Th&hellip;</p>"
  end

  describe "multi-byte strings" do
    # These examples purposely specify a number of bytes which is not divisible by four, to ensure
    # characters don't get brokwn up part-way thorugh their multi-byte representation
    it_does_not_truncate "no html text with longer length",
      with: { max_length: 99, tail: '...' },
      source: "𠲖𠲖𠲖𠲖𠲖𠲖𠲖𠲖",
      expected: "<p>𠲖𠲖𠲖𠲖𠲖𠲖𠲖𠲖</p>"
    it_truncates "no html text with shorter length, no tail",
      with: { max_length: 11, tail: '' },
      source: "𠝹𠝹𠝹𠝹𠝹𠝹𠝹𠝹",
      expected: "<p>𠝹</p>"
    it_truncates "no html text with shorter length, with tail",
      with: { max_length: 14, tail: '...' },
      source: "𠝹𠝹",
      expected: "<p>𠝹...</p>"
  end

  describe "multi-byte tail" do
    # These examples purposely specify a number of bytes which is not divisible by four, to ensure
    # characters don't get brokwn up part-way thorugh their multi-byte representation
    it_does_not_truncate "html text with longer length",
      with: { max_length: 99, tail: '𠴕' },
      source: "<p>𠲖𠲖𠲖𠲖𠲖𠲖𠲖𠲖</p>",
      expected: "<p>𠲖𠲖𠲖𠲖𠲖𠲖𠲖𠲖</p>"
    it_does_not_truncate "html text with equal length",
      with: { max_length: 15, tail: "𠴕" },
      source: "<p>𠝹𠝹</p>",
      expected: "<p>𠝹𠝹</p>"
    it_truncates "html text with shorter length",
      with: { max_length: 15, tail: "𠴕" },
      source: "<p>𠝹𠝹𠝹𠝹</p>",
      expected: "<p>𠝹𠴕</p>"
    it_truncates "html text with shorter length and longer tail",
      with: { max_length: 23, tail: "𠴕𠴕𠴕" },
      source: "<p>𠝹𠝹𠝹𠝹𠝹𠝹</p>",
      expected: "<p>𠝹𠴕𠴕𠴕</p>"
  end

  describe "html entity (ellipsis) tail" do
    it_truncates "html text with ellipsis html entity tail",
      with: { max_length: 27, tail: '&hellip;' },
      source: "<p>This is some text which will be truncated</p>",
      expected: "<p>This is some&hellip;</p>"
  end

  describe "html tags structure" do
    it_truncates "html text with tag",
      with: { max_length: 14, tail: '...' },
      source: "<p>some text</p>",
      expected: "<p>some...</p>"

    it_truncates "html text with nested tags (first node)",
      with: { max_length: 22, tail: '...' },
      source: "<div><p>some text 1</p><p>some text 2</p></div>",
      expected: "<div><p>s...</p></div>"

    it_truncates "html text with nested tags (second node)",
      with: { max_length: 46, tail: '...' },
      source: "<div><p>some text 1</p><p>some text 2</p></div>",
      expected: "<div><p>some text 1</p><p>some te...</p></div>"

    it_truncates "html text with nested tags (empty contents)",
      with: { max_length: 13, tail: '...' },
      source: "<div><p>some text 1</p><p>some text 2</p></div>",
      expected: "<div></div>"

    it_truncates "html text with special html entities",
      with: { max_length: 15, tail: '...' },
      source: "<p>&gt;some text</p>",
      expected: "<p>&gt;s...</p>"

    it_truncates "html text with siblings tags",
      with: { max_length: 64, tail: '...' },
      source: "<div>some text 0</div><div><p>some text 1</p><p>some text 2</p></div>",
      expected: "<div>some text 0</div><div><p>some text 1</p><p>som...</p></div>"

    it_does_not_truncate "html with unclosed tags",
      with: { max_length: 151, tail: '...' },
      source: "<table><tr><td>Hi <br> there</td></tr></table>",
      expected: "<table><tr><td>Hi <br/> there</td></tr></table>"

    it_does_not_truncate "preserve html entities",
      with: { max_length: 99, tail: '...' },
      source: "<o:p>&nbsp;</o:p>",
      expected: "<o:p>&nbsp;</o:p>"

    it_truncates "preserves entire html entities (all or nothing)",
      with: { max_length: 26, tail: '...' }, # Too small to bring all of &nbsp; in
      source: "<o:p>Hello there&nbsp;</o:p>",
      expected: "<o:p>Hello there...</o:p>"
  end

  describe "single html tag elements" do
    it_truncates "html text with <br /> element without adding a closing tag",
      with: { max_length: 30, tail: '...' },
      source: "<div><h1><br/>some text 1</h1><p>some text 2</p></div>",
      expected: "<div><h1><br/>so...</h1></div>"

    it_truncates "html text with <br /> element with a closing tag",
      with: { max_length: 30, tail: '...' },
      source: "<div><h1><br></br>some text 1</h1><p>some text 2</p></div>",
      expected: "<div><h1><br/>so...</h1></div>"

    it_truncates "html text with <img/> element without adding a closing tag",
      with: { max_length: 45, tail: '...' },
      source: "<div><p><img src='some_path'/>some text 1</p><p>some text 2</p></div>",
      expected: "<div><p><img src='some_path'/>so...</p></div>"

    it_truncates "html text with <img/> element with a closing tag",
      with: { max_length: 45, tail: '...' },
      source: "<div><p><img src='some_path'></img>some text 1</p><p>some text 2</p></div>",
      expected: "<div><p><img src='some_path'/>so...</p></div>"
  end

  describe "invalid html" do
    it_truncates "html text with unclosed elements 1",
      with: { max_length: 30, tail: '...' },
      source: "<div><h1><br/>some text 1</h1><p>some text 2",
      expected: "<div><h1><br/>so...</h1></div>"
    it_truncates "html text with unclosed elements 2",
      with: { max_length: 30, tail: '...' },
      source: "<div><h1><br>some text 1<p>some text 2",
      expected: "<div><h1><br/>so...</h1></div>"
    it_truncates "html text with unclosed br element",
      with: { max_length: 30, tail: '...' },
      source: "<div><h1><br>some text 1</h1><p>some text 2",
      expected: "<div><h1><br/>so...</h1></div>"
    it_truncates "html text with mis-matched elements",
      with: { max_length: 30, tail: '...' },
      source: "<div><h1><br/>some text 1</h2><p>some text 2</span></table>",
      expected: "<div><h1><br/>so...</h1></div>"
  end

  describe "comment html element" do
    it_does_not_truncate "retains comments",
      with: { max_length: 35 },
      source: "<div><!--This is a comment--></div>",
      expected: "<div><!--This is a comment--></div>"

    it_truncates "doesn't truncate comments themselves (all or nothing)",
      with: { max_length: 34 },
      source: "<div><!--This is a comment--></div>",
      expected: "<div></div>"
  end

  describe "html attributes" do
    it_truncates "html text with 1 attributes",
      with: { max_length: 23, tail: '...' },
      source: "<p attr1='1'>some text</p>",
      expected: "<p attr1='1'>som...</p>"

    it_truncates "html text with 2 attributes",
      with: { max_length: 33, tail: '...' },
      source: "<p attr1='1' attr2='2'>some text</p>",
      expected: "<p attr1='1' attr2='2'>som...</p>"

    it_truncates "html text with attributes in nested tags",
      with: { max_length: 35, tail: '...' },
      source: "<div><p attr1='1'>some text</p></div>",
      expected: "<div><p attr1='1'>some...</p></div>"
  end

  describe "cdata blocks" do
    # This comes from a real-world example which requires cdata support to bring in the CSS
    let(:cdata_example) { File.read('spec/fixtures/cdata_example.html') }
    it "cdata blocks are preserved" do
      text, truncated = Abbreviato.truncate(cdata_example, max_length: 65535)
      expect(text.length).to eq 3581
      expect(truncated).to be_falsey
    end
  end

  describe "edge-cases: long tags" do
    it_truncates "completely removes tags and contents if the tags will not fit",
      with: { max_length: 33, tail: '...' },
      source: "<really_a_very_long_tag_name>text</really_a_very_long_tag_name>",
      expected: ""
    it_truncates "does not allow closing tags to get added without opening tags",
      with: { max_length: 61, tail: '...' },
      source: "<really_a_very_long_tag_name>text</really_a_very_long_tag_name>",
      expected: "<really_a_very_long_tag_name></really_a_very_long_tag_name>"
    it_truncates "does not allow closing tags to get added without opening tags",
      with: { max_length: 62, tail: '...' },
      source: "<really_a_very_long_tag_name>text</really_a_very_long_tag_name>",
      expected: "<really_a_very_long_tag_name>...</really_a_very_long_tag_name>"
    it_does_not_truncate "does not allow closing tags to get added without opening tags",
      with: { max_length: 63, tail: '...' },
      source: "<really_a_very_long_tag_name>text</really_a_very_long_tag_name>",
      expected: "<really_a_very_long_tag_name>text</really_a_very_long_tag_name>"
  end

  describe "edge-cases:" do
    it_truncates "discard a single element within a longer element and use the following html (assuming it will fit)",
      with: { max_length: 9 },
      source: "<span><input/></span><p>.</p>",
      expected: "<p>.</p>"
    it_truncates "discard a single element within a longer element",
      with: { max_length: 10 },
      source: "<span><p></p></span><h1>.</h1>",
      expected: "<h1>.</h1>"
    it_truncates "some semi-random elements",
      with: { max_length: 10 },
      source: "<span><p><br/><br/><br/><p><br/></span><h1></h2>.</h3><h4><br/>",
      expected: "<h1>.</h1>"
    it_does_not_truncate "junk, including various html chars",
      with: { max_length: 10 },
      source: "<<< /  > < 0)(*&^*&^%${#}><? < /",
      expected: ""
    it_truncates "outer tags fit exactly",
      with: { max_length: 13 },
      source: "<span><p></p></span>",
      expected: "<span></span>"
    it_truncates "outer tags and opening inner tag fit exactly",
      with: { max_length: 16 },
      source: "<span><p></p></span>",
      expected: "<span></span>"
    it_truncates "void tags which do not fit",
      with: { max_length: 5 },
      source: "<command>",
      expected: ""
    it_truncates "void tags within outer tags which do not fit",
      with: { max_length: 15 },
      source: "<p><command/></p>",
      expected: "<p></p>"
    it_does_not_truncate "void tags within outer tags which fit",
      with: { max_length: 17 },
      source: "<p><command/></p>",
      expected: "<p><command/></p>"
    it_truncates "outer tags which fit perfectly within inner content",
      with: { max_length: 7 },
      source: "<p>hello</p>",
      expected: "<p></p>"
  end

  describe "void tags" do
    TruncatedSaxDocument::VOID_TAGS.each do |tag|
      it_does_not_truncate "void tag: #{tag} doesn't get closing element added",
        with: { max_length: 100 },
        source: "<#{tag}/>",
        expected: "<#{tag}/>"

      it_does_not_truncate "void tag: #{tag} has closing element stripped",
        with: { max_length: 100 },
        source: "<#{tag}></#{tag}>",
        expected: "<#{tag}/>"
    end
  end

  describe "fragment mode" do
    it_truncates "doesn't add `head` and `body` tags",
      with: { max_length: 15, tail: '...' },
      source: "<p>hello there</p>",
      expected: "<p>hello...</p>"
  end

  describe "document mode" do
    it_truncates "preserves `html`, `head` and `body` tags",
      with: { max_length: 54, fragment: false, tail: '...' },
      source: "<html><head></head><body><p>hello there</p></body></html>",
      expected: "<html><head></head><body><p>hello...</p></body></html>"

    it_does_not_truncate "preserves html attributes",
      with: { max_length: 999, fragment: false, tail: '...' },
      source: "<html xmlns:v='urn:schemas-microsoft-com:vml' xmlns:o='urn:schemas-microsoft-com:office:office' xmlns:w='urn:schemas-microsoft-com:office:word' xmlns:m='http://schemas.microsoft.com/office/2004/12/omml' xmlns='http://www.w3.org/TR/REC-html40'></html>",
      expected: "<html xmlns:v='urn:schemas-microsoft-com:vml' xmlns:o='urn:schemas-microsoft-com:office:office' xmlns:w='urn:schemas-microsoft-com:office:word' xmlns:m='http://schemas.microsoft.com/office/2004/12/omml' xmlns='http://www.w3.org/TR/REC-html40'></html>"

    it_does_not_truncate "preserves meta tags and their attributes",
      with: { max_length: 999, fragment: false, tail: '...' },
      source: "<html><head><meta http-equiv='Content-Type' content='text/html; charset=utf-8'></head></html>",
      expected: "<html><head><meta http-equiv='Content-Type' content='text/html; charset=utf-8'/></head></html>"

    it_does_not_truncate "preserves comments in the head",
      with: { max_length: 999, fragment: false, tail: '...' },
      source: "<html><head><!--[if !mso]><style>v\\:* {behavior:url(#default#VML);} o\\:* {behavior:url(#default#VML);} w\\:* {behavior:url(#default#VML);} .shape {behavior:url(#default#VML);} </style><![endif]--></head></html>",
      expected: "<html><head><!--[if !mso]><style>v\\:* {behavior:url(#default#VML);} o\\:* {behavior:url(#default#VML);} w\\:* {behavior:url(#default#VML);} .shape {behavior:url(#default#VML);} </style><![endif]--></head></html>"

    it_does_not_truncate "preserves styles",
      with: { max_length: 999, fragment: false, tail: '...' },
      source: "<html><head><style><!-- /* Font Definitions */ @font-face {font-family:Wingdings; panose-1:5 0 0 0 0 0 0 0 0 0;} </style></head></html>",
      expected: "<html><head><style><!-- /* Font Definitions */ @font-face {font-family:Wingdings; panose-1:5 0 0 0 0 0 0 0 0 0;} </style></head></html>"

    it_does_not_truncate "preservers body attributes",
      with: { max_length: 999, fragment: false, tail: '...' },
      source: "<html><body lang='EN-US' link='blue' vlink='purple'></body></html>",
      expected: "<html><body lang='EN-US' link='blue' vlink='purple'></body></html>"
  end

  describe "wbr element support" do
    it_does_not_truncate "preserves <wbr> elements",
      with: { max_length: 100 },
      source: "<p>The quick<wbr>brown fox<wbr>jumped over the lazy dog</p>",
      expected: "<p>The quick<wbr/>brown fox<wbr/>jumped over the lazy dog</p>"
  end

  describe "entity conversion" do
    it_does_not_truncate "converts © character into html entity",
      with: { max_length: 100 },
      source: "<p>© Copyright</p>",
      expected: "<p>&copy; Copyright</p>"
    it_does_not_truncate "converts non-english characters into html entities",
      with: { max_length: 200 },
      source: "<p>Ursäkta det tagit lite tid men jag väntade på krediteringen på 160 kr vilken aldrig kom (som vanligt).</p>",
      expected: "<p>Urs&auml;kta det tagit lite tid men jag v&auml;ntade p&aring; krediteringen p&aring; 160 kr vilken aldrig kom (som vanligt).</p>"
  end

  describe "html encoded entities" do
    it_truncates "html entities",
      with: { max_length: 18, fragment: true, tail: '...' },
      source: '""""',
      expected: "<p>&quot;...</p>"

    it_truncates "text with html entitities",
      with: { max_length: 50, fragment: true, tail: '...' },
      source: 'table  cellpadding="0" cellspacing="0"',
      expected: "<p>table  cellpadding=&quot;0&quot; cellspa...</p>"
  end

  describe "mid-row truncation" do
    describe "and a well-formatted table is absent" do
      it_truncates "does not attempt table truncation",
        with: { max_length: 120, truncate_incomplete_row: true },
        source: "<div>Lorem ipsum dolor sit amet, consectetur adipiscing elit Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor inci ex ea commodo consequat.</div>",
        expected: "<div>Lorem ipsum dolor sit amet, consectetur adipiscing elit Lorem ipsum dolor sit amet, consectetur adipi&hellip;</div>"

      it_truncates "does not attempt table truncation",
        with: { max_length: 120, truncate_incomplete_row: true },
        source: "<table>Lorem ipsum dolor sit amet, consectetur adipiscing elit Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor inci ex ea commodo consequat.</table>",
        expected: "<table>Lorem ipsum dolor sit amet, consectetur adipiscing elit Lorem ipsum dolor sit amet, consectetur a&hellip;</table>"

      it_truncates "does not attempt table truncation",
        with: { max_length: 120, truncate_incomplete_row: true },
        source: "<table><tr>Lorem ipsum dolor sit amet, consectetur adipiscing elit Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor inci ex ea commodo consequat.</tr></table>",
        expected: "<table><tr>Lorem ipsum dolor sit amet, consectetur adipiscing elit Lorem ipsum dolor sit amet, cons&hellip;</tr></table>"
    end

    describe "when truncate_incomplete_row option is provided" do
      it_truncates "drops the last <tr> in the document",
        with: { max_length: 120, truncate_incomplete_row: true },
        source: "<table><tr><td>aaaaaaaaaaaaaaaaaaaaaa</td><td>bbbbbbbbbbbbbbbbbbbbbb</td></tr><tr><td>cccccccccccccccccccccc</td><td>dddddddddddddddddddddd</td></tr></table>",
        expected: "<table><tr>\n<td>aaaaaaaaaaaaaaaaaaaaaa</td>\n<td>bbbbbbbbbbbbbbbbbbbbbb</td>\n</tr></table>"

      describe "and table is not the last element in the document" do
        it_truncates "does not attempt table truncation",
          with: { max_length: 120, truncate_incomplete_row: true },
          source: "<table><tr><td>a</td><td>b</td><td>c</td></tr><tr><td>d</td></tr></table><div>Lorem ipsum dolor sit amet, consectetur adipiscing elit Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor inci ex ea commodo consequat</div>",
          expected: "<table><tr><td>a</td><td>b</td><td>c</td></tr><tr><td>d</td></tr></table><div>Lorem ipsum dolor sit amet, &hellip;</div>"
      end
    end

    describe "when truncate_incomplete_row option is absent" do
      it_truncates "does not drop the last <tr> in the document",
        with: { max_length: 120, truncate_incomplete_row: false },
        source: "<table><tr><td>aaaaaaaaaaaaaaaaaaaaaa</td><td>bbbbbbbbbbbbbbbbbbbbbb</td></tr><tr><td>cccccccccccccccccccccc</td><td>dddddddddddddddddddddd</td></tr></table>",
        expected: "<table><tr><td>aaaaaaaaaaaaaaaaaaaaaa</td><td>bbbbbbbbbbbbbbbbbbbbbb</td></tr><tr><td>cccccccc&hellip;</td></tr></table>"
    end
  end

  # Preserve this code as an example of truncating a real-world (PII-less) example
  # let(:real_world_doc) { File.read('spec/fixtures/real_world_example.html') }
  # it "works with a real-life example" do
  #   truncated = Abbreviato.truncate(real_world_doc,  max_length: 65535)
  #   File.open('spec/fixtures/real_world_example_truncated.html', 'w') { |file| file.write(truncated) }
  # end

  describe "Brakecheck" do
    %w[brakecheck brakeman bundler-audit rubocop flay].each do |gem_name|
      it "#{gem_name} is up to date" do
        expect(Brakecheck.compare(gem_name)).to include(true)
      end
    end
  end
end
