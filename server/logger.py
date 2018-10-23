import os
import logging
import inspect
import traceback

class StyleAdapter(logging.LoggerAdapter):
	def __init__(self, logger):
		self.logger = logger

	def log(self, level, msg, *args, **kwargs):
		if self.isEnabledFor(level):
			log_kwargs = {}
			log_sig = inspect.signature(self.logger._log)
			for name in log_sig.parameters:
				if kwargs.get(name):
					log_kwargs[name] = kwargs[name]
					del kwargs[name]
			try:
				self.logger._log(level, msg.format(*args, **kwargs), (), **log_kwargs)
			except IndexError as e:
				# we want a traceback, but the one this exception holds is uninteresting. We want the one of the caller.
				frame = traceback.extract_stack()[-3]
				self.logger.error("Malformed print statement at {}:{}".format(frame.filename, frame.lineno))

def CreateLogger(debug=False):
	"""
	Creates a logger which emits to the output console (for monitoring the state of the server).
	"""
	logger = logging.getLogger("SyncyTowne")
	logger.setLevel(logging.DEBUG if debug else logging.INFO)
	formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
	log_to_console = logging.StreamHandler()
	log_to_console.setFormatter(formatter)
	log_to_console.setLevel(logging.INFO)
	commands_file = os.path.abspath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "server.log"))
	log_to_file = logging.FileHandler(commands_file)
	log_to_file.setFormatter(formatter)
	logger.addHandler(log_to_console)
	logger.addHandler(log_to_file)
	return StyleAdapter(logger)

logger = CreateLogger(True)
