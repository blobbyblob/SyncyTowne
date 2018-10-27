import os
import unittest
import filewatch
import time
import queue
import commandhandler.helpers as helpers
from logger import logger


class SessionTracker:
	"""
	A class which creates sessions which have unique IDs. Accessing the session keeps it alive. Any
	session which hasn't been accessed in a period of time can be cleaned up.

	Cleanup logic hasn't been implemented, yet.
	"""
	ExpiryTime = 60 * 30   # Sessions expire after being neglected for thirty minutes.
	def __init__(self, cleanup = lambda x: None):
		self._Sessions = dict()
		self._LastIndex = -1
		self._Cleanup = cleanup

	def __getitem__(self, i):
		self._Sessions[i][1] = time.monotonic()
		return self._Sessions[i][0]

	def __contains__(self, i):
		return i in self._Sessions

	def clean(self):
		"""
		Iterates through all sessions and cleans up ones which haven't been accessed in a while.
		"""
		for (index, t) in list(self._Sessions.items()):
			if t[1] + self.ExpiryTime < time.monotonic():
				logger.warning("file tracking session with ID {} expired", index)
				self.remove(index)

	def add(self, value):
		"""
		Adds a new session to this object and returns its ID.
		"""
		self._LastIndex+=1
		self._Sessions[self._LastIndex] = [value, time.monotonic()]
		return self._LastIndex

	def remove(self, index):
		self._Cleanup(self._Sessions[index][0])
		del self._Sessions[index]

class FileWatchCommandHandler:
	POLL_TIMEOUT = 5

	def __init__(self, root):
		self._FileWatchST = SessionTracker(lambda t: t[0].kill())
		self._Root = root

	def watch_start(self, directory):
		queue = filewatch.QueueCallbacks()
		watcher = filewatch.WatchForChanges(directory, queue)
		id = self._FileWatchST.add((watcher, queue))
		return {"ID": id}

	def watch_poll(self, id):
		end_time = time.monotonic() + self.POLL_TIMEOUT
		if id not in self._FileWatchST:
			return {
				"FileChange": "error ID_NO_LONGER_VALID",
			}

		try:
			while True:
				self._FileWatchST[id][1].Deduplicate()
				(mode, filepath) = self._FileWatchST[id][1].get(timeout=end_time - time.monotonic())
				relativeFilepath = helpers.AbsoluteToRelativeFilePath(filepath, self._Root)

				# if the file has any hidden directories in it, don't continue.
				logger.debug("relativeFilepath: {} (hidden directories: {})", relativeFilepath, [dir for dir in relativeFilepath.split("/") if dir[0] == "."])
				if len([dir for dir in relativeFilepath.split("/") if dir[0] == "."]):
					logger.debug("Not sharing {} because it contains hidden directory/file", relativeFilepath)
					continue

				# Get the hash; failure to do so should cause us to ignore this result.
				try:
					with open(filepath, 'rb') as file:
						time.sleep(.1)
						hash = helpers.Hash(file.read())
						logger.debug("Hash of {}: {}", filepath, hash)
				except Exception as e:
					continue

				# Inform the user of the change.
				return {
					"FileChange": mode + " '" + relativeFilepath + "' " + hash
				}
		except queue.Empty as e:
			return {
				"FileChange": ""
			}

	def watch_stop(self, id):
		if id in self._FileWatchST:
			self._FileWatchST.remove(id)
		else:
			logger.warning("watch_stop called on non-existent ID {}", id)
		return {}
			
class FileWatchCommandHandlerTestCase(unittest.TestCase):
	testdir = os.path.join(os.path.dirname(__file__), "..", "testdir")
	def setUp(self):
		import commandhandler
		self.handler = commandhandler.create_command_handler(self.testdir)

	def writeFileOnDelay(self, delay, file, source):
		import threading
		def delayAndWriteFile():
			time.sleep(delay)
			with open(os.path.join(self.testdir, file), "w") as f:
				f.write(source)
		t = threading.Thread(target=delayAndWriteFile)
		t.daemon = True
		t.start()

	def test_process(self):
		id = self.handler.handle("watch_start\n.")
		self.writeFileOnDelay(.1, "file1.txt", "foobar")
		self.assertEqual(
			"modify file1.txt 6",
			self.handler.handle("watch_poll\n{}".format(id))
		)
		self.handler.handle("watch_stop\n{}".format(id))

	def test_update_hidden_file(self):
		id = self.handler.handle("watch_start\n.")
		self.writeFileOnDelay(.1, ".git\\secretfile.txt", "foobar")
		self.writeFileOnDelay(.2, "file1.txt", "foobar")
		self.assertEqual(
			"modify file1.txt 6",
			self.handler.handle("watch_poll\n{}".format(id))
		)
		self.handler.handle("watch_stop\n{}".format(id))