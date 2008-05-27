#!/usr/bin/ruby
#CSVFile.rb - script to read flat csv files and write normalised data to load into SQL

## Pseudocode'ish
# open ARGV for reading
# read in header line
# open outfile for writing
# for each additional line
#  read in line
#  parse into hash with keys from header
#    convert QDATE value to Date object
#  for each of 11 data groups
#    write out line with normalised data

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
    file.close
    @data.compact! # remove unsuccessful lines
  end
  
  def to_s
    "Filename: #{@filename}\n" + @data.join("\n")
  end
  
  def to_sql # output an sql input file to stdout
    
  end
end

class CSVLine

  # create @data - hash with keys from keys array and values from csv line str
  def initialize(keys, csv_line)
    @data = {}
    values = csv_line.chomp!.split(',')
    values.each_with_index { |v, i| @data[keys[i]] = v }
  end

end

class NormData < CSVLine # this sub-class is data specific
  
  def initialize(keys, csv_line) # create normalised data structure from CSV data hash
    super(keys, csv_line) # hash of key/value pairs for this line
    print "Parsing code #{@data["CODE"]}..."
    @code = @data["CODE"]
    @name = @data["NAME"]
    date = Date.parse(@data["QDATE"],true) # parses an excel type date
    @report = []
    @report << [ReportData.new(date, @data["SALQ"], @data["COSTQ"], @data["CPTQ"])]
    1.upto(11) do |q| # for each quarter in the data
      @report << ReportData.new(date << q * 3, @data["SALQ" + q.to_s], @data["COSTQ" + q.to_s], @data["CPTQ" + q.to_s]) 
    end
    @report.compact!
    puts "done."
    rescue: puts "Unable to parse record for code #{@data["CODE"]}..."; return nil
  end
  
  def to_s
    "\nCode: #{@code} Name: #{@name}\n" + (
      if @report.nil? || @report.length == 0 then
        "  No reports.\n"
      else
        @report.join("\n")
      end
    )
  end
  
end

class ReportData

  def initialize(date, sales, cogs, shares)
    @date = date; @sales = (sales.to_f * 1e6); @cogs = cogs.to_f * 1e6; @shares = shares.to_i * 1e3
    if @shares == 0: @shares = nil end
  end
  
  def to_s
    "Date: #{@date.to_s} Sales: #{@sales.to_s} COGS: #{@cogs.to_s} Shares: #{@shares.to_s}"
  end

end

## Command line operation

if $0 == __FILE__ # command line
  unless ARGV.length == 1 then puts "Usage: ruby testdata.rb csvfile.csv"; exit; end
  require 'pp'
  ARGV.each { |f| csv = CSVFile.new(f); puts csv }
end
