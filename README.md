# NPC dialogue parser

LUA script that attempts to log NPC dialogue to a SQLLite database.

## Requirements

- MQ
- MQ2Lua

## Installation
Download the latest `npc_parser.zip` from the latest [release](https://github.com/peonMQ/npc_parser/releases) and unzip the contents to the `lua` folder of your MQ directory.

## Usage

Start the application by running the following command in-game.
```bash
/lua run npc_parser
```

### SQLLite DB
The NPC dialogue will be written to an SQLLite DB located at `{MQConfigDir}\{ServerName}\data\npc_quest_parser.db`


### Logging
User/character configs are located at `{MQConfigDir}\{ServerName}\{CharacterName}.json`

Valid log levels: `trace | debug | info | warn | error | fatal | help`
Default log level: `warn`
```json
{
	"logging": {
		"loglevel": "debug" 
	}
}
```
