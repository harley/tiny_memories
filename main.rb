require 'json'

class FileReader
  attr_reader :data
  def initialize(file = 'data/cheers.json')
    @data = JSON.parse(File.read(file), object_class: OpenStruct)
  end
end

class Main
  attr_reader :data

  def initialize(data)
    @data = data
  end

  def cheers
    @data.cheers
  end

  def top_cheers
    cheers[0..4]
  end
end

@main = Main.new(FileReader.new.data).top_cheers
