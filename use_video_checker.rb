require 'video_checker'
urls = File.read("ok_urls.txt").split
checker = VideoChecker::Checker.new("video_check.log")
checker.check_urls(urls)