return [[
{
	"Name": "Commands",
	"Type": "Commands",
	"Commands": [
		{
			"Name": "read",
			"Arguments": [
				{
					"Name": "File",
					"Type": "FilePath"
				}
			],
			"ResponseArguments": [
				{
					"Name": "Contents",
					"Type": "*"
				}
			]
		},
		{
			"Name": "write",
			"Arguments": [
				{
					"Name": "File",
					"Type": "FilePath"
				},
				{
					"Name": "Contents",
					"Type": "*"
				}
			],
			"ResponseArguments": [
			]
		},
		{
			"Name": "delete",
			"Arguments": [
				{
					"Name": "File",
					"Type": "FilePath"
				}
			],
			"ResponseArguments": [
			]
		},
		{
			"Name": "parse",
			"Arguments": [
				{
					"Name": "File",
					"Type": "FilePath"
				},
				{
					"Name": "Depth",
					"Type": "Number"
				},
				{
					"Name": "Hash",
					"Type": "Boolean"
				}
			],
			"ResponseArguments": [
				{
					"Name": "Tree",
					"Type": "*"
				}
			]
		},
		{
			"Name": "hash",
			"Arguments": [
				{
					"Name": "Contents",
					"Type": "*"
				}
			],
			"ResponseArguments": [
				{
					"Name": "Hash",
					"Type": "String"
				}
			]
		},
		{
			"Name": "watch_start",
			"Arguments": [
				{
					"Name": "File",
					"Type": "FilePath"
				}
			],
			"ResponseArguments": [
				{
					"Name": "ID",
					"Type": "Number"
				}
			]
		},
		{
			"Name": "watch_poll",
			"Arguments": [
				{
					"Name": "ID",
					"Type": "Number"
				}
			],
			"ResponseArguments": [
				{
					"Name": "FileChange",
					"Type": "String"
				}
			]
		},
		{
			"Name": "watch_stop",
			"Arguments": [
				{
					"Name": "ID",
					"Type": "Number"
				}
			],
			"ResponseArguments": [
			]
		}
	]
}
]]
