#!/usr/bin/ruby
# CSVFile.rb - script to read flat csv files and write normalised data to load into SQL
# Usage: ruby CSVFile.rb testdata.csv > testdata.sql

## Pseudocode'ish
# open ARGV for reading
# read in header line
# open outfile for writing
# for each additional line
#  read in line
#  parse into hash with keys from header
#    convert QDATE value to Date object
#  for each of 12 quarterly data groups
#    write out sql insert line with normalised data

require 'date' # if date values are to be parsed

class CSVFile

  attr_reader :data

  def initialize(filename)
    @filename = filename
    file = File.open(@filename) 
    header = file.readline.chomp!.split(',') # first line is special
    @data = file.collect do |line| # array of CSVLine objects
      NormData.new(header, line)    # NormData is a special case of CSVLine
    end
    ensure file.close unless file.nil?
    @data.compact! # remove unsuccessful lines
  end
  
  def to_s
    "Filename: #{@filename}\n" + @data.join("\n")
  end
  
  def to_sql # output an sql input file to stdout
    "# Outputting to sql from #{@filename}...\n\n" + (@data.collect { |line| if line.valid? then line.to_sql end }).join("\n")
  end
end

class CSVLine

  # create @data - hash with keys from keys array and values from csv line str
  def initialize(keys, csv_line)
    @data = {}
    values = csv_line.chomp!.split(',')
    values.each_with_index { |v, i| @data[keys[i]] = v }
  end
  
  def valid?
    !(@data.nil? || @data.empty?)
  end

  def to_sql
    "No generic sql statement supplied."
  end

end

class NormData < CSVLine # this sub-class is data specific
  
  def initialize(keys, csv_line) # create normalised data structure from CSV data hash
    super(keys, csv_line) # hash of key/value pairs for this line
    @code = @data["CODE"]
    @name = @data["NAME"]
    date = Date.parse(@data["QDATE"],true) # parses an excel type date
    @reports = []
    @reports << ReportData.new(date, @data["SALQ"], @data["COSTQ"], @data["CPTQ"])
    1.upto(11) do |q| # for each quarter in the data
      @reports << ReportData.new(date << q * 3, @data["SALQ" + q.to_s], @data["COSTQ" + q.to_s], @data["CPTQ" + q.to_s]) 
    end
    @reports.compact!
    rescue: puts "# Unable to parse record for code #{@data["CODE"]}..."; return nil
  end
  
  def valid? 
    !(@reports.nil? || @reports.empty?)
  end
  
  def to_s
    "\nCode: #{@code} Name: #{@name}\n" + (
      if @reports.to_a != [] then
        @reports.join("\n")
      else
        "No reports."
      end
    )
  end
  
  def to_sql
    sql_data = "# (#{@code}): #{@name}\n"; prefix = "REPLACE INTO `history` (`code`,`name`,`result_date`,`sales`,`gross_profit`,`diluted_shares`)\n"
    @reports.each { |r| 
      if r.valid? then sql_data << prefix << "  VALUES ('#{@code}', '#{@name}', #{r.to_sql});\n" end
    }
    sql_data
  end

end

class ReportData

  attr_reader :date, :sales, :cogs, :shares

  def initialize(date, sales, cogs, shares)
    @date = date; @sales = (sales.to_f * 1e6); @cogs = cogs.to_f * 1e6; @shares = shares.to_i * 1e3
    if @shares == 0: @shares = nil end
  end
  
  def valid?
    !(@shares.nil? || @shares == 0 || @sales == 0)
  end
  
  def to_s
    "Date: #{@date.to_s} Sales: #{@sales.to_s} COGS: #{@cogs.to_s} Shares: #{@shares.to_s}"
  end
  
  def to_sql
    "'#{@date}', '#{@sales}', '#{@sales - @cogs}', '#{@shares}'"
  end

end

## Command line operation

if $0 == __FILE__ # command line
  unless ARGV.length == 1 then puts "Usage: ruby testdata.rb csvfile.csv"; exit; end
  require 'pp'
  ARGV.each { |f| csv = CSVFile.new(f); puts csv.to_sql }
end
