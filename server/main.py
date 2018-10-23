import filewatch
import threading
import time
import server
import os
import logging
import inspect
from logger import logger
import commandhandler

def main():
	root = os.path.realpath(os.path.join(__file__, os.pardir, os.pardir, os.pardir))
	commandvalidator = commandhandler.create_command_handler(root)
	webman = server.HttpServer(commandvalidator)
	logger.info("Starting Server; Parse Root: {}", root)
	webman.start()

	while True:
		time.sleep(1);

if __name__ == "__main__":
	main()

