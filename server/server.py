import traceback
import http.server
import threading
import os
import io
import hashlib
import logging
import inspect
import re
import functools
import time
import queue
import socketserver
from logger import logger
import commandhandler

##############################
# Helper Classes
##############################

class FixedLengthBufferReader:
	"""
	Wraps a TextIO base and behaves as if there was an EOF after length characters.
	This is meant for reading, not writing.
	"""
	def __init__(self, buffer, length):
		"""
		:param buffer: the buffer to wrap
		:param length: the number of characters in the buffer
		"""
		self.buffer = buffer
		self.characters_left = length

	@staticmethod
	def from_http_request(request):
		length = 0
		for (key, value) in request.headers.items():
			if key.lower() == 'content-length':
				length = int(value)
		return FixedLengthBufferReader(request.rfile, length)

	def read(self, size = -1):
		if size is None or size == -1:
			size = self.characters_left
		elif size > self.characters_left:
			size = self.characters_left
		if size == 0:
			return ""
		self.characters_left -= size
		return self.buffer.read(size).decode('utf-8')

	def readline(self, size = -1):
		if size is None or size == -1:
			size = self.characters_left
		elif size > self.characters_left:
			size = self.characters_left
		if size == 0:
			return ""
		str = self.buffer.readline(size).decode('utf-8')
		self.characters_left -= len(str)
		return str

	def close(self):
		self.buffer.close()

##############################
# Request Handler
##############################

class CommandParserHandler(http.server.BaseHTTPRequestHandler):
	"""
	Parses the input for the SyncyTowne protocol & creates objects to handle the requests.
	"""
	def __init__(self, *args, commandvalidator, **kwargs):
		self._command_validator = commandvalidator
		http.server.BaseHTTPRequestHandler.__init__(self, *args, **kwargs)

	def do_POST(self):
		# If the client is expecting us to send a "continue", do it.
		if self.headers.get("expect", "").lower() == "100-continue":
			self.handle_expect_100()

		# Let the CommandValidator handle the request.
		rfile = FixedLengthBufferReader.from_http_request(self)
		request = rfile.read()
		try:
			response = self._command_validator.handle(request)
		except commandhandler.HttpException as e:
			logger.warning("", exc_info=e)
			traceback.print_exception(e, "", e.__traceback__)
			self.send_error(e.code, e.msg, e.explain)
		except Exception as e:
			logger.error("", exc_info=e)
			traceback.print_exception(e, "", e.__traceback__)
			self.send_error(500)
		else:
			self.send_response(200)
			bytes = response.encode()
			self.send_header("content-length", len(bytes))
			self.end_headers()
			self.wfile.write(bytes)

	def log_message(self, format, *args):
		logger.info(format % args)


class ThreadedHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    """Handle requests in a separate thread."""

class HttpServer(threading.Thread):
	ParseRoot = "."
	def __init__(self, commandvalidator):
		threading.Thread.__init__(self)
		self.setDaemon(True)
		def generateCommandParserHandler(*args, **kwargs):
			return CommandParserHandler(*args, **kwargs, commandvalidator=commandvalidator)
		self.server = ThreadedHTTPServer(("", 605), generateCommandParserHandler)
		self.server.daemon = True

	def run(self):
		self.server.serve_forever(poll_interval=.1)

	def kill(self):
		self.server.shutdown()

