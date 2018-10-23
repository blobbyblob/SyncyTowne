import json
import os
import unittest
import logging
from logger import logger

class HttpException(Exception):
	def __init__(self, code, msg = None, explanation = None):
		self.code = code
		self.msg = msg
		self.explain = explanation

	def __str__(self):
		return "HTTP " + str(self.code) + "; " + str(self.msg) + "; " + str(self.explain)


STRING_TO_BOOL = {
	'true': True, 'TRUE': True, 'True': True, '1': True,
	'false': False, 'FALSE': False, 'False': False, '0': False}


def validate_incoming_string(value):
	return value # all values come in as a string.
def validate_incoming_number(value):
	try:
		return int(value)
	except:
		raise HttpException(400, None, "Failed to convert {} to int".format(value))
def validate_incoming_bool(value):
	try:
		return STRING_TO_BOOL[value]
	except:
		raise HttpException(400, None, "Failed to convert {} to bool".format(value))
def validate_incoming_file(value, root):
	# ensure we have a legit relative file path, regardless of whether there is a directory at the end of it.
	# Convert this to an absolute path.
	v = value.strip()
	raw = v
	if v and v != ".":
		s = v.split('/')
		for i, x in enumerate(s):
			if not x:
				del s[i]
			elif x[0:2] == "..":
				raise HttpException(400, None, "Parent directory operator forbidden")
			elif x[0:1] == ".":
				raise HttpException(400, None, "Cannot access hidden files/directories")
		v = os.path.join(root, *s)
	else:
		v = root
	return v
def validate_incoming_extant_file(value, root):
	# ensure we have a reference to a file which exists.
	absolute_path = validate_incoming_file(value, root)
	if os.path.isfile(absolute_path):
		return absolute_path
	else:
		raise HttpException(400, None, "File {} doesn't exist".format(absolute_path))

def validate_outgoing_string(value):
	return value
def validate_outgoing_number(value):
	if not isinstance(value, (int, float)):
		raise HttpException(500, None, "Bad outgoing number: {}".format(number))
	return str(value)
def validate_outgoing_file(value):
	pass  # TODO
def validate_outgoing_extant_file(value):
	pass  # TODO

INCOMING_TYPE_VALIDATORS = {
	"String": validate_incoming_string,
	"Number": validate_incoming_number,
	"FilePath": validate_incoming_file,
	"ExtantFilePath": validate_incoming_extant_file,
	"*": validate_incoming_string,
	"Boolean": validate_incoming_bool,
}
OUTGOING_TYPE_VALIDATORS = {
	"String": validate_outgoing_string,
	"Number": validate_outgoing_number,
	"FilePath": validate_outgoing_file,
	"ExtantFilePath": validate_outgoing_extant_file,
	"*": validate_outgoing_string,
}

class CommandValidator:
	def _generateResponseStringBuilder(self, command):
		name = command.get("Name")
		self.commands[name] = command
		args = command.get("Arguments")
		responseArgs = command.get("ResponseArguments")
		def createResponseString(**kwargs):
			"""
			Validates that all outgoing parameters are correct & present,
			then sends it out over HTTP.
			"""
			debugString = []

			try:
				# Verify every argument is present.
				expected_args = dict((arg["Name"], True) for arg in responseArgs)
				for key in kwargs:
					if key in expected_args:
						del expected_args[key]
					else:
						logger.error("Unexpected argument: {}", key)
						raise HttpException(500, "Internal error")
				if expected_args:
					logger.error("Missing arguments to response; expected {}, got {}", responseArgs, kwargs)
					raise HttpException(500, "Internal error")

				# verify individual responseArgs (that is, types match)
				# We do this simultaneous to converting to strings (the OUTGOING_TYPE_VALIDATORS should raise exceptions if the types are wrong).
				response = []
				for outgoingArgDef in responseArgs:
					key = outgoingArgDef["Name"]
					type = outgoingArgDef["Type"]
					value = kwargs[key]
					try:
						validator = OUTGOING_TYPE_VALIDATORS[type]
					except Exception as e:
						logger.error("Type {} has no outgoing type validator", type)
						raise HttpException(500, "Internal error")
					try:
						asString = validator(value)
					except Exception as e:
						logger.error("Could not convert {} to output string of type {}", value, type)
						logger.error("{}: {}", e.__class__.__name__, str(e))
						raise HttpException(500, "Internal error")
					response.append(asString)
					if type != "*" or len(asString) < 30:
						debugString.append("{}: '{}'".format(key, asString))
					else:
						debugString.append("{}: string of length {}".format(key, len(asString)))

				logger.info("sending response '{}': {}", name, ", ".join(debugString))
				# build the response string & return the response.
				return "\n".join(response)
			except:
				logger.info("sending response '{}': error")
				raise
		return createResponseString

	def __init__(self, json, root):
		self.additional_args = {
			"FilePath": [root],
			"ExtantFilePath": [root],
		}
		self.commands = {}  # A map of command name --> JSON command details
		self.handlers = {}  # A map of command name --> callable to handle the command.
		self.callbacks = {}  # A map of command name --> callable to create the response string.
		for command in json.get("Commands"):
			name = command.get("Name")
			self.callbacks[name] = self._generateResponseStringBuilder(command)

	def _has_proper_arguments(self, sig, cmd):
		expected_count = len(cmd["Arguments"])
		actual_count = len(sig.parameters)
		if expected_count == actual_count:
			return True
		else:
			import itertools
			# print out the expected arguments and the actual arguments.
			fstring = ["", "{:>20s}    {:>20s}"]
			args = ["expected", "actual"]
			for (expected, actual) in itertools.zip_longest(cmd["Arguments"], sig.parameters, fillvalue=None):
				args.append(expected["Name"] if expected is not None else "n/a")
				args.append(actual if actual is not None else "n/a")
				fstring.append("{:>20s}    {:>20s}")
			fstring = "\n".join(fstring)
			logger.warning(fstring, *args)
			return False

	def register(self, handler):
		"""
		A handler should be an instance of a class with methods defined that
		match the names of the commands.
		"""
		import inspect
		logger.debug("registering handler {}", handler)
		for (key, value) in inspect.getmembers(handler):
			if key in self.commands:
				if key not in self.handlers:
					# ensure it takes the correct number of arguments.
					if self._has_proper_arguments(inspect.signature(value), self.commands[key]):
						self.handlers[key] = value
					else:
						logger.error("Handler {}.{} cannot be registered", handler, key)
				else:
					logger.warning("Found duplicate handlers for {}", key)
			else:
				pass  # finding methods that don't match any commands is very common.

	def handle(self, cmd):
		# the first line contains the command.
		lines = cmd.split("\n")
		command = lines[0]
		commandDefinition = self.commands.get(command)
		if not commandDefinition:
			raise HttpException(400, None, "Command {} is invalid".format(command))
		# Loop through the arguments. Any with type "*" means consume a multi-line string. Other types should go through their handlers.
		argumentsDefinition = commandDefinition.get("Arguments")
		arguments = []
		debugString = []
		if argumentsDefinition:
			i = 1
			for arg in argumentsDefinition:
				name = arg.get("Name")
				type = arg.get("Type")
				if type == "*":
					line = "\n".join(lines[i:])
					if len(line) < 30:
						debugString.append("{}: {}".format(name, line))
					else:
						debugString.append("{}: string of length {}".format(name, len(line)))
					i = len(lines)
				else:
					line = lines[i]
					debugString.append("{}: {}".format(name, line))
					i = i + 1
				try:
					arguments.append(INCOMING_TYPE_VALIDATORS[type](line, *self.additional_args.get(type, [])))
				except HttpException as e:
					raise
				except Exception as e:
					raise HttpException(400, None, "Bad argument {} ({}, type {})\n{}: {}".format(lines[i], name, type, e.__class__.__name__, str(e)))
		logger.info("received command '{}': {}".format(command, ", ".join(debugString)))
		try:
			handler = self.handlers.get(command)
			if handler:
				response = handler(*arguments)
				try:
					args = dict(**response)
				except TypeError as e:
					logger.error("Handler {} must return dictionary", command)
					raise HttpException(500, "Internal error")
				return self.callbacks[command](**args)
			else:
				raise HttpException(400, None, "Handler for {} not registered".format(command))
		except HttpException:
			raise
		except Exception as e:
			raise HttpException(400, None, "Error during handler:\n{}: {}".format(e.__class__.__name__, str(e)))


class CommandHandlerTest(unittest.TestCase):

	def test_command_validator(self):
		commands_file = os.path.abspath(os.path.join(os.path.dirname(os.path.realpath(__file__)), os.pardir, os.pardir, "generic", "commands.json"))
		with open(commands_file, "r") as f:
			commands = json.loads(f.read())
		validator = CommandValidator(
			commands,
			os.path.join(os.path.dirname(os.path.realpath(__file__)), os.pardir, "testdir")
		)
		from commandhandler.readwritehandler import RWCommandHandler
		validator.register(RWCommandHandler())
		self.assertEqual("", validator.handle("write\nfile1.txt\nfoobar"))
		self.assertEqual("foobar", validator.handle("read\nfile1.txt"))

