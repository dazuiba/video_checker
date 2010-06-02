require 'video_checker'
urls = File.read("ok_urls.txt").split
checker = VideoChecker.new("video_check.log")
checker.check_urls(urls)