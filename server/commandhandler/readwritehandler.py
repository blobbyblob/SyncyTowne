import os

class RWCommandHandler:
	"""
	Handles the read/write commands.
	"""
	def read(self, File):
		with open(File, "r") as f:
			contents = f.read()
		return {
			"Contents": contents
		}

	def write(self, File, Contents):
		# Ensure all the necessary folders exist
		if os.path.dirname(File):
			os.makedirs(os.path.dirname(File), exist_ok=True)
		# Write to the file.
		with open(File, "w") as f:
			f.write(Contents)
		return {}

	def delete(self, File):
		os.remove(File)
		return {}
