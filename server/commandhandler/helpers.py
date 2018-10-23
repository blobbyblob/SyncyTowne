import os
from logger import logger

def Hash(s):
	l = len([c for c in s if c != 10])
	other = len([c for c in s if c == 10])
	logger.debug("length: {} (excluded {} bytes)", l, other)
	return str(l)


def RelativeToAbsoluteFilePath(rel_path, root):
	"""
	Converts a relative filepath (based on the root, using "/" as the path separator)
	into an absolute filepath (OS dependent)
	"""
	pass

def AbsoluteToRelativeFilePath(filepath, root):
	"""
	Converts an absolute filepath into a relative filepath based on the ParseRoot & changes the
	path separators to "/".
	"""
	relative = filepath[len(root):]
	if len(relative) > 0 and relative[0] == os.sep:
		relative = relative[1:]
	relative = '/'.join(relative.split(os.sep))
	logger.debug("Filepath {} relative to root {} is {}", filepath, root, relative)
	return relative
