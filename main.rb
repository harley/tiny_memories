require 'json'
require 'bundler/setup'
require 'open-uri'

Bundler.require(:default)

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

  def top_cheers(limit: 4)
    media_cheers[0..limit]
  end

  def media_cheers
    cheers.select(&:media)
  end

  def download(limit: 4)
    puts 'Downloading Media'
    top_cheers(limit: limit).each_with_index do |cheer, index|
      filename = cheer.media.split('/').last
      local_name = "#{index}_#{cheer.id}_#{filename}"
      local_path = "downloads/#{local_name}"
      if File.exist?(local_path)
        puts "[SKIPPED] #{cheer.media} --> #{local_name}"
      else
        File.write local_path, open(cheer.media).read
        puts "--------> #{cheer.media} --> #{local_name}"
      end
    end
  end

  def to_slideshow
    FFMPEG::Transcoder.new(
      '',
      'slideshow.mp4',
      { resolution: '320x240' },
      input: 'downloads/item%d.jpg',
      input_options: { framerate: '1/5' }
    )
  end

  def insert_audio(video: 'slideshow', audio: 'sounds/default.m4a')
    if File.exists?(audio)
      `ffmpeg -i #{video}.mp4 -i #{audio} -c:v libx264 -c:a copy -shortest #{video}_audio.mp4`
    else
      raise "Audio file not found: #{audio}"
    end
  end
end

class VideoMaker
  def initialize(text:, image_file:, duration: 5, output: 'out.mp4')
    cmd = %{ffmpeg -i #{image_file} -vf \
      drawtext="fontfile=fonts/Chalkboard.ttf: \
      text='#{text}': fontcolor=white: fontsize=24: box=1: boxcolor=black@0.5: \
      boxborderw=5: x=(w-text_w)/2: y=(h-text_h)/2" -t #{duration} #{output}}

    system(cmd)
  end
end

# Turn Gif to keep 10 seconds video
class Gif2Video
  def initialize(gif_file:, output: nil)
    output ||= "#{gif_file}.mp4"
    `ffmpeg -stream_loop -1 -i #{gif_file}.gif -loop 4 \
    -movflags faststart -pix_fmt yuv420p -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" \
    -t 10 #{output}`
  end
end

class Text4Video
  def initialize(text:, video_file:, output: 'out.mp4', duration: 10)
    cmd = %{ffmpeg -i #{video_file} -vf \
      drawtext="fontfile=fonts/Chalkboard.ttf: \
      text='#{text}': fontcolor=white: fontsize=24: box=1: boxcolor=black@0.5: \
      boxborderw=5: x=(w-text_w)/2: y=(h-text_h)/2" -t #{duration} #{output}}

    system(cmd)

  end
end

@main = Main.new(FileReader.new.data)
