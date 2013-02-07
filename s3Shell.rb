#!/usr/bin/env ruby
require 'rubygems'
require 'aws-sdk'

AWS.config(
    :access_key_id => ENV['AMAZON_ACCESS_KEY_ID'],
      :secret_access_key => ENV['AMAZON_SECRET_ACCESS_KEY']
)
@s3=AWS::S3.new

bucket = @s3.buckets['EP_TEST_BUCKET_1']
dbucket=nil
def bucket_check(bucket)
  test_bucket=@s3.buckets[bucket]
  return test_bucket.exists?
end
#file = ARGV.first
while true
  #command is self explanatory. param1 and param2 are used for different things, depending on the command.
  #if there aren't enough values in gets, then the unused params are left nil.
  command, param1, param2 = gets.split
  command.chomp!
  file=nil
  dbucket=nil
  expireDate=nil
  #Uploads the given file to the currently selected bucket.
  if(command=="upload")
    file=param1
    file.chomp!
    expireDate=param2
    expireDate.chomp!
    if(expireDate==nil)
      bucket.objects[file].write(Pathname.new(file))
      puts "File " + file + " successfully uploaded!"
      puts file + " can be accessed at "
      puts bucket.objects[file].url_for(:read)
    elsif(expireDate.to_i>1)
      bucket.objects[file].write(Pathname.new(file))
      puts "File " + file + " successfully uploaded!"
      puts file + " can be accessed at "
      puts bucket.objects[file].url_for(:read)
      bucket.lifecycle_configuration.replace do
        add_rule(file, :expiration_time => expireDate.to_i)
      end
    else
      puts 'Expiration Date must be greater than 0.'
    end
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
    elsif(bucket_check(dbucket))
      puts 'The destination bucket does not exits.'
    elsif(!bucket.objects[file].exists?)
      puts "The file does not exist."
    else
      dbucket.chomp!
      bucket.objects[file].copy_to(file,{:bucket=>@s3.buckets[dbucket]})
      puts 'File ' + file + ' copied to ' + dbucket
    end
  end
  if(command=="pwd")
    puts bucket.name
  end
  if(command=="cd")
    dbucket=param1
    dbucket.chomp!
    unless(bucket_check(dbucket))
      bucket=@s3.buckets[dbucket]
    else
      puts 'No such bucket.'
    end
  end
  if(command=="mkdir")
    dbucket=param1
    dbucket.chomp!
    dbucket.downcase
    unless(bucket_check(dbucket))
      @s3.buckets.create(dbucket)
      puts 'Bucket ' + dbucket + ' created.'
    else
      puts 'Bucket already exists. Cannot create duplicate buckets.'
    end
  end
  if(command=="lsbkt")
    @s3.buckets.each do |dbucket|
      puts dbucket.name
    end
  end
  if(command=="rmdir")
    dbucket=param1
    dbucket.chomp!
    if(bucket_check(dbucket))
      puts 'Are you sure you want to delete the bucket' + dbucket  + ' and all its contents? (y/n)'
      while true
        check=gets
        check.chomp!
        if(check=="y")
          dbucket = @s3.buckets[dbucket]
          dbucket.clear!
          dbucket.delete
          puts "Bucket deleted."
          break
        elsif(check=="n")
          puts "Operation aborted."
          break
        else
          puts "Command not recognized"
        end
      end
    else
      puts 'Bucket does not exist, so cannot be deleted.'
    end
  end
  if(command=="exists?")
    dbucket=param1
    dbucket.chomp!
    puts bucket_check(dbucket)
  end
  if(command=="permission?")
    dbucket=param1
    dbucket.chomp!
    unless(bucket_check(dbucket))
      puts 'Bucket does not exist.'
    else
      begin
        aclTest=@s3.buckets[dbucket].acl
        puts 'You have permissions for this bucket.'
      rescue AWS::S3::Errors::AccessDenied => e
        puts 'You do not have access to this bucket.'
      end
    end
  end
  if(command=="SetExpire")
    file = param1
    file.chomp!
    expireDate = param2
    expireDate.chomp!
    begin
      if(bucket.objects[file].exists?)
        if(expireDate.to_i>1)
          bucket.lifecycle_configuration.update do
            add_rule(file, :expiration_time => expireDate.to_i)
          end
        else
          puts 'Expiration date cannot be less than 1.'
        end
      else
        puts 'File does not exist.'
      end
    rescue AWS::S3::Errors::InvalidRequest => e
      if(bucket.objects[file].exists?)
        bucket.lifecycle_configuration.replace do
          add_rule(file, :expiration_time => expireDate.to_i)
        end
      else
        puts 'File does not exist.'
      end
    end
  end
  if(command=="exit")
    break
  end
end
