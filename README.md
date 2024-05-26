# OllamaRPG
A fun project using Ollama and Godot. Developed on MacOs, not tested on Windows or Linux.

![macOS](https://img.shields.io/badge/mac%20os-000000?style=for-the-badge&logo=macos&logoColor=F0F0F0)

## Installation

You will need the following to run this project:
- Godot 4.2.x
- espeak 
- [Ollama](https://ollama.com/download/mac)


`brew install espeak`

## Ollama

When using Ollama, don't forget to pull the model you want to use
`ollama pull llama3`

Currently, the following models are supported:
- `llama3`
- `llama2`
- `command-r`

## OpenAI

If you want to use any of the OpenAI models, you need to rename the `sample.config.cfg` file to `config.cfg`, and place your API key in this file.

The following OpenAI models are supported:
- `OpenAI GPT-4o`
- `OpenAI GPT-4`
- `OpenAI GPT-4-turbo` 
- `OpenAI GPT-3.5-turbo-0125`

## Interaction

You can control the main player character, George, by using keyboard arrows or WASD keys. You can move George around in the game world, and have him discover items or NPCs. You can also talk to George by typing questions in the search box. You can ask George where he is, what he's doing and why. You can also ask George to walk somewhere by giving a location, or by asking him to walk to a previously discovered place or item.

![alt text](image.png)

