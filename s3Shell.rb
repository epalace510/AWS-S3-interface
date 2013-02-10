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
  #if there aren't enough values in gets, then the unused params are left nil. (But are put to nil just in case)
  #flag is for reduced redundancy. May have other functions in the future.
  flag=nil
  command, param1, param2, flag = gets.split
  command.chomp!
  file=nil
  dbucket=nil
  expireDate=nil
  #Uploads the given file to the currently selected bucket.
  if(command=="upload")
    file=param1
    unless(file==nil)
      file.chomp!
      expireDate=param2
      unless(expireDate==nil)
        expireDate.chomp!
      end
      unless(flag==nil)
        flag.chomp!
      end
      if(expireDate==nil)
        bucket.objects[file].write(Pathname.new(file))
        puts "File " + file + " successfully uploaded!"
        puts file + " can be accessed at "
        puts bucket.objects[file].url_for(:read)
      elsif(expireDate=="-rr")
        bucket.objects[file].write(Pathname.new(file), :reduced_redundancy => true)
        puts "File " + file + " successfully uploaded!"
        puts file + " can be accessed at "
        puts bucket.objects[file].url_for(:read)
      elsif(expireDate.to_i>1 and flag==nil)
        begin
          bucket.objects[file].write(Pathname.new(file))
          puts "File " + file + " successfully uploaded!"
          puts file + " can be accessed at "
          puts bucket.objects[file].url_for(:read)
          bucket.lifecycle_configuration.replace do
            add_rule(file, :expiration_time => expireDate.to_i)
          end
        rescue AWS::S3::Errors::InvalidBucketState
          puts 'File cannot have a set expiration date because the bucket is versioned.'
        end
      elsif(expireDate.to_i>1 and flag=="-rr")
        begin
          bucket.objects[file].write(Pathname.new(file), :reduced_redundancy => true)
          puts "File " + file + " successfully uploaded!"
          puts file + " can be accessed at "
          puts bucket.objects[file].url_for(:read)
          bucket.lifecycle_configuration.replace do
            add_rule(file, :expiration_time => expireDate.to_i)
          end
        rescue AWS::S3::Errors::InvalidBucketState
          puts 'File cannot have a set expiration date because the bucket is versioned.'
        end
      else
        puts 'Expiration Date must be greater than 0.'
      end
    end
  #deletes (removes) the given file from the currently selected bucket.
  elsif(command=="rm")
    file=param1
    #dbucket isn't actually the destination bucket. I just used it for simplicity and efficiency.
    #In this case, dbucket is actually the version to be deleted.
    dbucket=param2
    unless(file==nil)
      file.chomp!
      if(dbucket==nil)
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
      elsif(flag!=nil)
        flag.chomp!
        dbucket.chomp!
        if(bucket.versioning_enabled?)
          if(flag=="-v")
            puts "Are you sure you want to remove \"" + file + "\" from " + bucket.name + "? (y/n)"
            #double checking to make sure. Unlike Unix, I didn't implement the -f flag.
            while true
              check=gets
              check.chomp!
              if(check=="y")
                bucket.objects[file].versions[dbucket].delete
                puts file +" version " + dbucket + " removed."
                break
              elsif(check=="n")
                puts "Operation aborted."
                break
              else
                puts "Command not recognized"
              end
            end
          else
            puts 'Flag not recognized.'
          end
        else
          puts 'Versioning is not enabled on this bucket.'
        end
      end
    end
  #lists the objects in the current bucket.
  elsif(command=="ls")
    bucket.objects.each do |obj|
      puts obj.key
    end
  elsif(command=="cp")
    file=param1
    unless(file==nil)
      file.chomp!
      dbucket=param2
      if(dbucket!=nil)
        dbucket.chomp!
      end
      if(dbucket==nil and bucket.objects[file].exists?)
        File.open(file, 'w') do |filename|
          bucket.objects[file].read do |chunk|
            filename.write(chunk)
          end
        end
        puts "File " +file+ " written."
      elsif(!bucket_check(dbucket))
        puts 'The destination bucket does not exits.'
      elsif(!bucket.objects[file].exists?)
        puts "The file does not exist."
      else
        dbucket.chomp!
        bucket.objects[file].copy_to(file,{:bucket=>@s3.buckets[dbucket]})
        puts 'File ' + file + ' copied to ' + dbucket
      end
    end
  elsif(command=="pwd")
    puts bucket.name
  elsif(command=="cd")
    dbucket=param1
    unless(dbucket==nil)
      dbucket.chomp!
      if(bucket_check(dbucket))
        bucket=@s3.buckets[dbucket]
      else
        puts 'No such bucket.'
      end
    end
  elsif(command=="mkdir")
    dbucket=param1
    unless(dbucket==nil)
      dbucket.chomp!
      dbucket.downcase
      if(!bucket_check(dbucket))
        @s3.buckets.create(dbucket)
        puts 'Bucket ' + dbucket + ' created.'
      else
        puts 'Bucket already exists. Cannot create duplicate buckets.'
      end
    end
  elsif(command=="lsbkt")
    @s3.buckets.each do |dbucket|
      puts dbucket.name
    end
  elsif(command=="rmdir")
    dbucket=param1
    unless(dbucket==nil)
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
  elsif(command=="exists?")
    dbucket=param1
    unless(dbucket==nil)
      dbucket.chomp!
      puts bucket_check(dbucket)
    end
  elsif(command=="permission?")
    dbucket=param1
    unless(dbucket==nil)
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
  elsif(command=="SetExpire")
    file = param1
    expireDate = param2
    begin
      unless(file==nil or expireDate==nil)
        file.chomp!
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
            ex_id = bucket.objects[file].expiration_rule_id
            bucket.lifecycle_configuration.replace do
              add_rule(file, :expiration_time => expireDate.to_i)
            end
          else
            puts 'File does not exist.'
          end
        end
      end
    rescue AWS::S3::Errors::InvalidBucketState
      puts 'File cannot have a set expiration date because the bucket is versioned.'
    end
  elsif(command=="head")
    file = param1
    unless(file==nil)
      if(bucket.objects[file].exists?)
        puts bucket.objects[file].head
      else
        puts "No such file."
      end
    end
  elsif(command=="version")
    begin
      unless(bucket.versioning_enabled?)
        bucket.enable_versioning
        puts "Current bucket is now versioned."
      else
        puts "Bucket is already versioned."
      end
    rescue AWS::S3::Errors::InvalidBucketState
      puts 'Bucket cannot be versioned because it is configured for expiration.'
    end
  elsif(command=="unversion")
    if(bucket.versioning_enabled?)
      bucket.suspend_versioning
      puts "Bucket is no longer versioned."
    else
      puts "Bucket is already not versioned."
    end
  elsif(command=="lsvrsn")
    file = param1
    unless(file==nil)
      file.chomp!
      if(bucket.objects[file].exists?)
        if(bucket.versioning_enabled?)
          object=bucket.objects[file]
          object.versions.each do |version| puts version.version_id end
          puts "Latest version of the file is "
          puts object.versions.latest.version_id
        else
          puts 'Versioning is not enabled on this bucket.'
        end
      else
        puts 'File does not exist.'
      end
    else
      puts 'No file provided.'
    end
  elsif(command=="versioning?")
    if(bucket.versioning_enabled?)
      puts 'Versioning is enabled for this bucket.'
    else
      puts 'Versioning is not enabled for this bucket.'
    end
  elsif(command=="exit")
    break
  else
    puts command + " is not a recognized command."
  end
end
