#!/usr/bin/env ruby
require 'rubygems'
require 'aws-sdk'

AWS.config(
    :access_key_id => ENV['AMAZON_ACCESS_KEY_ID'],
      :secret_access_key => ENV['AMAZON_SECRET_ACCESS_KEY']
)
s3=AWS::S3.new

#file = ARGV.first
bucket = s3.buckets['EP_TEST_BUCKET_1']
bucket.objects.each do |obj|
  puts obj.key
end

while true
  #command is self explanatory. param1 and param2 are used for different things, depending on the command.
  #if there aren't enough values in gets, then the unused params are left nil.
  command, param1, param2 = gets.split
  command.chomp!
  if(command=="upload")
    file=param1
    file.chomp!
    bucket.objects[file].write(Pathname.new(file))
   # AWS::S3::S3Object.write(Pathname.new(file))
    puts "File " + file + " successfully uploaded!"
    puts file + " can be accessed at "
    puts bucket.objects[file].url_for(:read)
  end
  if(command=="rm")
    file=param1
    file.chomp!
    puts "Are you sure you want to remove \"" + file + "\" from " + bucket.name + "? (y/n)"
    while true
      check=gets
      check.chomp!
      if(check=="y")
        bucket.objects[file].delete
        puts file +" removed."
        break
      elsif(check=="n")
        puts "Operation aborted."
        break
      else
        puts "Command not recognized"
      end
    end
  end
  if(command=="exit")
    break
  end
end
