"""
Deals with I/O of command strings.

This reads the commands.json file & produces a helper module which parses incoming info & emits outgoing strings for each command.

The individual command handlers are children of this module.

commandhandler.py contains the common logic for all commands (type validation, etc.) and debugging help.
"""

from . import commandvalidator as _commandhandler

HttpException = _commandhandler.HttpException
CommandValidator = _commandhandler.CommandValidator

def create_command_handler(rootPath):
	"""
	Creates a command handler by importing commands.json & registering all child handlers.
	"""
	import json
	import os
	commands_file = os.path.abspath(os.path.join(os.path.dirname(os.path.realpath(__file__)), os.pardir, os.pardir, "generic", "commands.json"))
	with open(commands_file, "r") as f:
		commands = json.loads(f.read())
	validator = CommandValidator(commands, rootPath)

	from . import readwritehandler
	validator.register(readwritehandler.RWCommandHandler())
	from . import hashhandler
	validator.register(hashhandler.HashCommandHandler(rootPath))
	from . import filewatchhandler
	validator.register(filewatchhandler.FileWatchCommandHandler(rootPath))

	return validator
