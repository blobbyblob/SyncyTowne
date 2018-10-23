"""
File that contains logic related to watching a directory for code changes.
"""

import os
import threading
import queue

import win32file
import win32con

ACTIONS = {
	1 : "Created",
	2 : "Deleted",
	3 : "Updated",
	4 : "Renamed from something",
	5 : "Renamed to something"
}
FILE_LIST_DIRECTORY = 0x0001

def _split_path(path):
	"""
	Splits a path into all its pieces (e.g., drive, folder list, file name).
	:param path: a string representing a file path.
	:return: a list of components of the path.
	"""
	drive, path_and_file = os.path.splitdrive(path)
	path, file = os.path.split(path_and_file)
	folders = [file]
	while 1:
		path, folder = os.path.split(path)
		if folder != "":
			folders.append(folder)
		else:
			if path != "":
				folders.append(path)
			break
	if drive:
		folders.append(drive)
	folders.reverse()
	return folders


class Callbacks:
	onAdd = lambda *args: None
	onDelete = lambda *args: None
	onModify = lambda *args: None
	onRename = lambda *args: None

class PrintCallbacks(Callbacks):
	def onAdd(self, filename):
		print("onAdd: {}".format(filename))
	def onDelete(self, filename):
		print("onDelete: {}".format(filename))
	def onModify(self, filename):
		print("onModify: {}".format(filename))
	def onRename(self, filename):
		print("onRename: {}".format(filename))

class QueueCallbacks(queue.Queue):
	"""
	Callbacks which put all file change notifications into a synchronized queue.
	"""
	def __init__(self):
		queue.Queue.__init__(self, 0)

	def onAdd(self, filename):
		self.put(("add", filename))
	def onDelete(self, filename):
		self.put(("delete", filename))
	def onModify(self, filename):
		self.put(("modify", filename))
	def onRename(self, old, new):
		self.put(("delete", old))
		self.put(("add", new))
	def Deduplicate(self):
		"""
		Removes duplicate entries from the list.
		"""
		# suck everything into a non-synchronized list.
		l = []
		try:
			while True:
				l.append(self.get_nowait())
		except queue.Empty as e:
			pass
		# Iterate through the list & put each tuple into a set. If the object is already in the set,
		# then remove it from the list.
		i = 0
		s = set()
		while i < len(l):
			if l[i] not in s:
				s.add(l[i])
				i += 1
			else:
				del l[i]
		# Push everything from our list back into the synchronized queue.
		for x in l:
			self.put(x)

class Filter:
	def __call__(self, filename):
		return True

class FilterDotFiles(Filter):
	def __call__(self, filename):
		for dir in _split_path(filename):
			if len(dir) > 1 and dir[0] == ".":
				return False
		return True

class WatchForChanges(threading.Thread):
	"""
	A thread which will watch for changes to files within a specific directory.
	"""

	def __init__(self, dir, callbacks = Callbacks(), filter = Filter(), **kwargs):
		threading.Thread.__init__(self, **kwargs)
		self.Directory = dir
		self.Callbacks = callbacks
		self.Filter = filter
		self.Terminate = threading.Event()
		self.setDaemon(True)
		self.start()

	def kill(self):
		self.Terminate.set()

	def run(self):
		#
		# ReadDirectoryChangesW takes a previously-created
		# handle to a directory, a buffer size for results,
		# a flag to indicate whether to watch subtrees and
		# a filter of what changes to notify.
		#
		# NB Tim Juchcinski reports that he needed to up
		# the buffer size to be sure of picking up all
		# events when a large number of files were
		# deleted at once.
		#
		hDir = win32file.CreateFile(
			self.Directory,
			FILE_LIST_DIRECTORY,
			win32con.FILE_SHARE_READ | win32con.FILE_SHARE_WRITE | win32con.FILE_SHARE_DELETE,
			None,
			win32con.OPEN_EXISTING,
			win32con.FILE_FLAG_BACKUP_SEMANTICS,
			None
		)
		while not self.Terminate.is_set():
			results = win32file.ReadDirectoryChangesW(
				hDir,
				1024,
				True,
				win32con.FILE_NOTIFY_CHANGE_LAST_WRITE,
				None,
				None
			)
			if self.Terminate.is_set():
				break
			for action, file in results:
				full_filename = os.path.join(self.Directory, file)
				if self.Filter(full_filename):
					if action == 1:
						self.Callbacks.onAdd(full_filename)
					elif action == 2:
						self.Callbacks.onDelete(full_filename)
					elif action == 3:
						self.Callbacks.onModify(full_filename)
					elif action == 4:
						pass#self.Callbacks.onRename(full_filename)

