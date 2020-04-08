require 'byebug';

module Abbreviato
  DEFAULT_OPTIONS = {
      max_length: 30,
      tail: '&hellip;',
      fragment: true
  }.freeze

  # Truncates the source XML string and returns the truncated XML and a boolean flag indicating
  # whether any truncation took place. It will keep a valid XML structure
  # and insert a _tail_ text indicating the position where content was removed (...).
  #
  # @param [String] source the XML source to truncate
  # @param [Hash] user_options truncation options
  # @option user_options [Integer] :max_length Maximum length
  # @option user_options [Boolean] :truncate_incomplete_row Indicates whether or
  #     not to truncate the last row in a table if truncation due to max_length
  #     occurs in the middle of a row.
  # @option user_options [String] :tail Text to append when the truncation happens
  # @option user_options [Boolean] :fragment Indicates whether the document to be truncated is an HTML fragment
  #     or an entire document (with `HTML`, `HEAD` & `BODY` tags). Setting to true prevents automatic addition of
  #     these tags if they are missing. Defaults to `true`.
  # @return [[String] the truncated string, [boolean] whether the string was truncated]
  def self.truncate(source = '', user_options = {})
    return [nil, false] if source.nil?

    truncated_sax_document = TruncatedSaxDocument.new(DEFAULT_OPTIONS.merge(user_options))
    parser = Nokogiri::HTML::SAX::Parser.new(truncated_sax_document)
    parser.parse(source) { |context| context.replace_entities = false }

    puts "================================================================================================"
    puts "truncated_sax_document.truncated: #{truncated_sax_document.truncated}"
    puts "truncated_sax_document.truncated_at_table: #{truncated_sax_document.truncated_at_table}"
    puts "user_options[:truncate_incomplete_row]: #{user_options[:truncate_incomplete_row]}"
    puts "================================================================================================"

    return truncate_incomplete_row(truncated_sax_document) if user_options[:truncate_incomplete_row]

    [truncated_sax_document.truncated_string.strip, truncated_sax_document.truncated]
  end

  def self.truncate_incomplete_row(truncated_sax_document)
    parsed_results = [truncated_sax_document.truncated_string.strip, truncated_sax_document.truncated]

    return parsed_results unless truncated_sax_document.truncated && truncated_sax_document.truncated_at_table

    parsed_results = [truncated_sax_document.truncated_string.strip, truncated_sax_document.truncated]

    html_fragment = Nokogiri::HTML.fragment(truncated_sax_document.truncated_string.strip)
    return parsed_results if html_fragment.nil?

    # Get the last table in the document that is not nested in another table
    last_table_in_doc = html_fragment.xpath('.//table[not(ancestor::table)]').last

    return parsed_results unless last_table_in_doc

    table_rows = last_table_in_doc.xpath('.//tr')

    return parsed_results unless table_rows.length

    # It's possible for column cells to have tables in them, so there's no good
    # way to figure out this value...
    columns_per_row = table_rows.map { |row| row.xpath('.//td').length }

    # It is not uncommon for tables to have headers that contain fewer columns
    # than the rest of the table. To account for this, the estimated columns per
    # row is the number of columns that appears most frequently for each row
    # in the table.
    estimated_columns_per_row = columns_per_row.max_by {|i| columns_per_row.count(i)}

    table_rows.reverse.each do |row|
      break if row.xpath('.//td').length == estimated_columns_per_row

      row.remove
    end

    [html_fragment.to_html, truncated_sax_document.truncated]
  end

  private_class_method :truncate_incomplete_row
end
