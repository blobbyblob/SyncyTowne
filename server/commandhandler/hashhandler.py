import commandhandler.helpers as helpers
import os
import unittest
from logger import logger

class HashCommandHandler:
	def __init__(self, root):
		self.root = root
		self.Hash = lambda s: helpers.Hash(s)

	def parse(self, filepath, depth, hash):
		returnValue = []
		for subdir, dirs, files in os.walk(filepath):
			assert(filepath == subdir[:len(filepath)])
			trimmed = subdir[len(filepath):]
			if trimmed and trimmed[0] == os.sep:
				trimmed = trimmed[1:]
			dirname = os.path.basename(subdir)
			if dirname[0:1] == '.' or trimmed.count('/') == depth - 1:
				for i in range(len(dirs) - 1, -1, -1):
					del dirs[i]
			if dirname[0:1] != '.':
				for file in files:
					if file[0:1] != '.':
						logger.debug("Parse - found file at {}, {}, {}", filepath, trimmed, file)
						path = helpers.AbsoluteToRelativeFilePath(os.path.join(filepath, trimmed, file), self.root)
						lineContents = [path]
						if hash:
							with open(os.path.join(subdir, file),'rb') as file:
								lineContents.append(self.Hash(file.read()))
						returnValue.append(" ".join(lineContents) + "\n")
		return {"Tree": "".join(returnValue)}

	def hash(self, contents):
		logger.info("Hashing string of length {}", len(contents))
		#import hashlib
		#return {"Hash": hashlib.md5(contents.encode('utf-8')).hexdigest()}  # md5
		return {"Hash": self.Hash(contents)}
		
class HashCommandHandlerTestCase(unittest.TestCase):
	testdir = os.path.join(os.path.dirname(__file__), "..", "testdir")

	def setUp(self):
		import commandhandler
		self.handler = commandhandler.create_command_handler(self.testdir)

	def test_parse(self):
		self.assertEqual(
			"file1.txt 6\nmorefiles/file2.txt 0\nmorefiles/file3.txt 0\nsubdir1/subdir2/file4.txt 0\n",
			self.handler.handle("parse\n.\n0\nTrue"))

	def test_parse_subdir(self):
		self.assertEqual(
			"subdir1/subdir2/file4.txt 0\n",
			self.handler.handle("parse\nsubdir1/subdir2\n0\nTrue"))

	def test_parse_subdir_with_trailing_slash(self):
		self.assertEqual(
			"subdir1/subdir2/file4.txt 0\n",
			self.handler.handle("parse\nsubdir1/subdir2/\n0\nTrue"))

	def test_hash(self):
		self.assertEqual("6", self.handler.handle("hash\nfoobar"))
