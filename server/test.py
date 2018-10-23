import http
import http.client
import os
import server
import traceback
import unittest
import collections
import logging
import filewatch
import time
import commandhandler

VERSION_MAP = {
	10: "HTTP/1.0",
	11: "HTTP/1.1",
}

class HttpResponse:
	def __init__(self, http):
		self.Version = VERSION_MAP[http.version]
		self.StatusCode = http.status
		self.StatusPhrase = http.reason
		self.Headers = collections.OrderedDict()
		for (key, value) in http.getheaders():
			self.Headers[key.lower()] = value
		self.Content = ""
		if self.Headers.get("content-length"):
			self.Content = http.read(int(self.Headers['content-length']))
			self.Content = self.Content.decode('utf-8')

	def __str__(self):
		s = []
		s.append("{} {} {}".format(self.Version, self.StatusCode, self.StatusPhrase))
		for (key, value) in self.Headers.items():
			s.append("{}: {}".format(key, value))
		s.append("")
		s.append(self.Content)
		return "\n".join(s)

class TestServer(unittest.TestCase):
	def setUpClass():
		commandHandler = commandhandler.create_command_handler(os.path.realpath(os.path.join(os.path.dirname(__file__), "testdir")))
		TestServer.webman = server.HttpServer(commandHandler)
		TestServer.webman.start()

	def tearDownClass():
		TestServer.webman.kill()

	def setUp(self):
		self.cxn = http.client.HTTPConnection("127.0.0.1", 605)

	def tearDown(self):
		self.cxn.close()

	def get_response(self, body, headers={}):
		self.cxn.request("POST", "/", body, headers)
		response = HttpResponse(self.cxn.getresponse())
		return response

	def test_parse_with_md5(self):
		response = self.get_response("parse\nmorefiles\n0\nTrue")
		self.assertEqual(response.Content, """morefiles/file2.txt 0
morefiles/file3.txt 0
""")

	def test_parse(self):
		response = self.get_response("parse\n\n1\nFalse")
		self.assertEqual(response.Content, "file1.txt\n")

	def test_parse_with_hidden(self):
		response = self.get_response("parse\n\n0\nFalse")
		self.assertEqual(response.Content, "file1.txt\nmorefiles/file2.txt\nmorefiles/file3.txt\nsubdir1/subdir2/file4.txt\n")

	def test_write_read(self):
		response = self.get_response("write\nfile1.txt\nfoobar")
		response = self.get_response("read\nfile1.txt")
		self.assertEqual(response.Content, "foobar")

	def test_md5(self):
		self.get_response("write\nfile1.txt\n")
		response = self.get_response("parse\n\n1\nTrue")
		self.assertEqual(response.Content, "file1.txt 0\n")
		self.get_response("write\nfile1.txt\nfoobar")
		response = self.get_response("parse\n\n1\nTrue")
		self.assertEqual(response.Content, "file1.txt 6\n")

	def test_read_with_leading_slash(self):
		response = self.get_response("read\n/morefiles/file2.txt")
		self.assertEqual(response.Content, "")

	def test_parse_with_nested_subdirs(self):
		response = self.get_response("parse\nsubdir1\n0\nFalse")
		self.assertEqual(response.Content, "subdir1/subdir2/file4.txt\n")

	def test_file_watch(self):
		response = self.get_response("watch_start\n")
		id = int(response.Content)
		f = open("testdir/file1.txt", "w")
		f.write("foobar")
		f.close()
		response = self.get_response("watch_poll\n{}".format(id))
		self.assertEqual(response.Content, "modify file1.txt 6")
		f = open("testdir/morefiles/file2.txt", "w")
		f.write("")
		f.close()
		response = self.get_response("watch_poll\n{}".format(id))
		self.assertEqual(response.Content, "modify morefiles/file2.txt 0")
		response = self.get_response("watch_stop\n{}".format(id))
		self.assertEqual(response.StatusCode, 200)

	def test_proper_speed(self):
		"""
		Tests that invocations to the server are handled at the correct clip and don't have
		second-long delays.
		Also validates the md5 command.
		"""
		tick = time.perf_counter()
		response = self.get_response("hash\n")
		self.assertEqual(response.Content, "0")
		response = self.get_response("hash\nfoobar")
		self.assertEqual(response.Content, "6")
		response = self.get_response("hash\nThe quick brown fox jumps over the lazy dog")
		self.assertEqual(response.Content, "43")
		self.assertLess(time.perf_counter() - tick, 1)

	def test_expect_continue(self):
		response = self.get_response("hash\n", {"Expect": "100-continue"})
		# This doesn't really test much except that the server doesn't crash and burn.

class FileWatch(unittest.TestCase):
	class LogCallbacks(filewatch.Callbacks):
		List = []
		def __init__(self):
			self.List = []
		def onAdd(self, filename):
			self.List.append(("onAdd", filename))
		def onDelete(self, filename):
			self.List.append(("onDelete", filename))
		def onModify(self, filename):
			self.List.append(("onModify", filename))
		def onRename(self, filename):
			self.List.append(("onRename", filename))

	def test_straight_api(self):
		callbacks = FileWatch.LogCallbacks()
		watcher = filewatch.WatchForChanges("testdir", callbacks)
		f = open("testdir/file5.txt", "w")
		f.write("foobar")
		f.close()
		os.remove("testdir/file5.txt")
		time.sleep(.1)
		self.assertEqual(len(callbacks.List), 1)
		self.assertEqual(callbacks.List[0][0], "onModify")
		self.assertEqual(callbacks.List[0][1], "testdir\\file5.txt")
