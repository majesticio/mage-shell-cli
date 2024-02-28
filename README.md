
# Mage shell CLI

## Overview

`mage.sh` is a command-line interface (CLI) tool designed to enhance your terminal experience by providing quick and intuitive access to a powerful conversational AI. Inspired by the capabilities of modern AI, `mage.sh` allows users to interact with an AI assistant directly from their terminal, offering assistance with a wide range of topics and tasks.

Whether you need help understanding complex concepts, looking for coding assistance, or simply curious about what AI can do, `mage.sh` is your go-to terminal companion.

## Features

- **Conversational AI Interaction:** Engage in natural, conversational exchanges with an AI directly from your terminal.
- **Markdown Rendering:** Responses from the AI are rendered in Markdown, providing a rich text experience that includes formatting for improved readability.
- **Simple Installation:** Easy to install with minimal dependencies, getting you started in no time.
- **Cross-Platform Compatibility:** Designed to work seamlessly across various Unix-like operating systems.

## Prerequisites

Before installing `mage.sh`, ensure you have the following dependencies installed on your system:

- `curl`: For downloading files from the internet.
- `jq`: For processing JSON data.
- `glow`: For rendering Markdown content in the terminal.

## Installation

To install `mage.sh`, run the following command in your terminal:

```sh
curl -sSL https://raw.githubusercontent.com/majesticio/mage-shell-cli/main/install.sh | sudo bash
```

This command fetches the installation script and executes it, handling all necessary setup steps to get `mage.sh` up and running on your system.

**Note:** Always exercise caution when executing scripts from the internet with root privileges. We encourage you to download and inspect the installation script before running it.

## Usage

After installation, you can start using `mage.sh` by typing `mage` in your terminal. This command launches the CLI interface, allowing you to begin interacting with the AI assistant.

Example usage:

```sh
mage
```

Follow the on-screen prompts to engage in a conversation with the AI. To exit, simply type `exit` or `quit`. A history of your chat is created at `~/.chat_history` which is loaded every time you run `mage`. Responses are rendered in markdown in your terminal.

## Customization

`mage.sh` is for a private api. I am using ollama so you can change the url for your own server.

## Contributing

We welcome contributions! If you have suggestions for improvements or encounter any issues, please feel free to [open an issue](https://github.com/username/repo/issues) or submit a pull request.

## License

`mage.sh` is released under the [MIT License](https://opensource.org/licenses/MIT). See the LICENSE file for more details.

---

Remember to replace placeholders like `https://raw.githubusercontent.com/username/repo/main/install_mage.sh` with the actual URL to your script, and adjust the sections as necessary to accurately reflect the capabilities and requirements of your `mage.sh` script.