require 'json'
require 'bundler/setup'
require 'open-uri'
require 'pathname'
require 'shellwords'

Bundler.require(:default)

class FileReader
  attr_reader :data
  def initialize(file = 'data/cheers.json')
    @data = JSON.parse(File.read(file), object_class: OpenStruct)
  end
end

class CheerProcessor
  attr_reader :cheer, :index
  def initialize(cheer:, index:)
    @cheer = cheer
    @index = index
  end

  def filename
    cheer.media.split('/').last
  end

  def ext
    Pathname.new(filename).extname
  end

  def local_media
    # local_name = "#{index}_#{cheer.id}_#{filename}"
    "#{index}#{ext}"
  end

  def local_media_path
    "downloads/#{local_media}"
  end

  def download_media
    if File.exist?(local_media_path)
      puts "[SKIPPED] #{cheer.media} --> #{local_media}"
    else
      File.write local_media_path, open(cheer.media).read
      puts "--------> #{cheer.media} --> #{local_media}"
    end
  end

  def local_video_path
    "videos/#{index}.mp4"
  end

  def local_text_video_path
    "text_videos/#{index}.mp4"
  end

  def convert_to_video
    if File.exist?(local_video_path)
      puts "[SKIPPED] #{local_video_path}"
    else
      case ext
      when '.gif'
        Gif2Video.new(gif_file: local_media_path, output: local_video_path)
      when '.jpg', '.jpeg'
        Image2Video.new(image_file: local_media_path, output: local_video_path)
      else
        raise "Invalid format: #{ext}"
      end
    end
  end

  def local_text_path
    "videos/#{index}.txt"
  end

  def line_wrap(s, width: 40)
    s.gsub(/(.{1,#{width}})(\s+|\Z)/, "\\1\n")
  end

  def multiline_text
    line_wrap(cheer.praise)
  end

  def text_on_video
    File.write(local_text_path, multiline_text) #unless File.exist?(local_text_path)
    Text4Video.new(textfile: local_text_path, video_file: local_video_path, output: local_text_video_path, duration: 2)
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
      CheerProcessor.new(cheer: cheer, index: index).download_media
    end
  end

  def convert_videos(limit: 4)
    puts 'Converting Video'
    top_cheers(limit: limit).each_with_index do |cheer, index|
      CheerProcessor.new(cheer: cheer, index: index).convert_to_video
    end
  end

  def add_text_to_video(limit: 4)
    puts 'Add Text to Videos'
    top_cheers(limit: limit).each_with_index do |cheer, index|
      CheerProcessor.new(cheer: cheer, index: index).text_on_video
    end
  end

  def combine_videos(limit: 4)
    puts 'Combine Videos'
    VideoMerger.new(limit: limit).execute
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

  def insert_audio(video: 'final/video_only.mp4', audio: 'sounds/default.m4a', output: 'final/video.mp4')
    if File.exist?(audio)
      `ffmpeg -i #{video} -i #{audio} -c:v libx264 -c:a copy -shortest #{output}`
    else
      raise "Audio file not found: #{audio}"
    end
  end

  def execute(limit: 4)
    download(limit: limit)
    convert_videos(limit: limit)
    add_text_to_video(limit: limit)
    combine_videos(limit: limit)
    insert_audio
  end
end

class VideoMerger
  def initialize(limit:)
    File.open('merge.txt', 'w') do |f|
      limit.times do |index|
        f.puts("file 'text_videos/#{index}.mp4'")
      end
    end
  end

  def execute(output: 'final/video_only.mp4')
    `ffmpeg -f concat -i merge.txt #{output}`
  end
end

class Image2Video
  def initialize(image_file:, duration: 2, output: nil)
    basename = Pathname.new(image_file).basename
    output ||= "videos/#{rand(100)}.mp4"
    cmd = "
      ffmpeg -framerate 1 -t #{duration} -i #{image_file} -vf scale=1280:-2 -c:v libx264 \ -r 30 -pix_fmt yuv420p #{output}
    "

    system(cmd)
  end
end

# Turn Gif to keep 10 seconds video
class Gif2Video
  def initialize(gif_file:, output: nil, duration: 2)
    basename = Pathname.new(gif_file).basename
    output ||= "videos/#{basename}.mp4"
    `ffmpeg -stream_loop -1 -i #{gif_file} -vf scale=1280:-2 -loop 4 \ -movflags faststart -pix_fmt yuv420p  \-t #{duration} #{output}`
  end
end

class Text4Video
  def initialize(textfile:, video_file:, output: 'out.mp4', duration: 2)
    cmd = %{ffmpeg -i #{video_file} -vf \ drawtext="fontfile=fonts/Chalkboard.ttf: \ textfile='#{textfile}': fontcolor=white: fontsize=24: box=1: boxcolor=black@0.5: \ boxborderw=2: x=(w-text_w)/2: y=(h-text_h)/2" -t #{duration} #{output}}

    system(cmd)
  end
end

@main = Main.new(FileReader.new.data)
