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
dbucket=nil
while true
  #command is self explanatory. param1 and param2 are used for different things, depending on the command.
  #if there aren't enough values in gets, then the unused params are left nil.
  command, param1, param2 = gets.split
  command.chomp!
  #Uploads the given file to the currently selected bucket.
  if(command=="upload")
    file=param1
    file.chomp!
    bucket.objects[file].write(Pathname.new(file))
   # AWS::S3::S3Object.write(Pathname.new(file))
    puts "File " + file + " successfully uploaded!"
    puts file + " can be accessed at "
    puts bucket.objects[file].url_for(:read)
  end
  #deletes (removes) the given file from the currently selected bucket.
  if(command=="rm")
    file=param1
    file.chomp!
    puts "Are you sure you want to remove \"" + file + "\" from " + bucket.name + "? (y/n)"
    #double checking to make sure. Unlike Unix, I didn't implement the -f flag.
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
  #lists the objects in the current bucket.
  if(command=="ls")
    bucket.objects.each do |obj|
      puts obj.key
    end
  end
  if(command=="cp")
    file=param1
    file.chomp!
    dbucket=param2
    if(dbucket==nil and bucket.objects[file].exists?)
      File.open(file, 'w') do |filename|
        bucket.objects[file].read do |chunk|
          filename.write(chunk)
        end
      end
      puts "File " +file+ " written."
    elsif(!bucket.objects[file].exists?)
      puts "The file does not exist."
    else
      dbucket.chomp!
      puts "I hope this doesn't show up."
    end
  end
  if(command=="exit")
    break
  end
end
