# Omnified Hacks
[![Discord](https://img.shields.io/discord/348353194801364992?style=flat-square&label=Discord&logo=discord&logoColor=white&color=7289DA)](https://discord.gg/omni) 

This repo contains the code for the game-neutral Bad Echo Omnified framework and the game-targeted hacks powered by it.

These hacks exists to deliver a live Omnified experience on stream, but is licensed under the GNU Affero General Public License so that others may enjoy it as well; see the accompanying [license](https://github.com/BadEcho/omnified-hacks/blob/master/LICENSE.md) for details.

## What is Omnified?

A game becomes Omnified when hacked to be insanely hard; more specifically, an Omnified game has had one or more of my game-neutral Omnified gameplay overhauling systems injected into it.

For a detailed look at what an Omnified game is, please refer to its dedicated article:

[What Is Omnified?](https://badecho.com/index.php/what-is-omnified/)

## Game-Neutral Code

The gameplay systems provided by the Omnified framework are game-neutral. Although each game is quite different from one another (especially regarding their binary makeup), these systems have been designed to be injected into any targeted game and used without requiring modification.

While the framework code is game-neutral, the game-targeted hacks, which implement calls into the framework for specific games, are not. The goal has always been to minimize the amount of code required in the game-targeted hacks without compromising the game-neutral aspect of the framework.

## Organization and Structure

The Omnified hacking framework and its game-targeted hacks use the following structure:

* **omnified-hacks.workspace**: Workspace file for Visual Studio Code, which is what I use to do all my work on the Omnified Hacking framework.
* **framework/**: This contains all game-neutral, common Omnified framework code.
  * **defines.lua**: Configuration settings meant to be overridden in target .CT file registration routines.
  * **utility.lua**: Utility functions employed by the Omnified framework.
  * **messaging.lua**: Library for messages sent by the Omnified framework.
  * **apocalypseMessages.lua**: Defines the Omnified Apocalypse event messaging schema.
  * **statisticMessages.lua**: Defines the Omnified game statistic messaging schema.
  * **omnified.lua**: Core Omnified framework system code. This provides functionality that allows us to import in, load, and clean up the disparate bits of code that make up an Omnified hack, such as the framework and game-targeted assembly code. Many other system-wide functionalities are provided here as well, such as timers relating to status effects, etc.
  * **omnified.asm**: Core Omnified framework assembly code. All code and symbols that Omnified game-neutral systems are dependent on can be found here, such as general-purpose functions like random number generation and safe pointer checking. 
  * **template.ct**: This is a template .CT file that is used as the base for all newly targeted Omnified games.
  * **systems/**: This contains all of the various Omnified game-neutral systems.
    * **apocalypse.asm**: The assembly code for the [Apocalypse system](https://badecho.com/index.php/2020/10/19/apocalypse-system/), a process that completely overhauls the system responsible for handling damage dealt to the player in a game.
    * **predator.asm**: The assembly code for the [Predator system](https://badecho.com/index.php/2021/06/18/predator-system/), a process that makes movement of enemies deadlier through intelligent (and sometimes quite large) boosts to their speed.
    * **abomnification.asm**: The assembly code for the Abomnification system, a process that causes creatures to randomly change their shape and size in a manner reminiscent to a bad acid trip.
* **targets/**: This contains all Omnified game targets, typically a game that I've hacked and have played through on my [stream](https://twitch.tv/omni). Each Omnified game will have its own subdirectory. Targets here are referred to as being Omnified 2.0.
  * **nameOfGame/**: This would be the directory for the game acting as an Omnified target, containing all the code specific to that game.
    * **nameOfGame.ct**: The .CT file for the Omnified game. This is what we double click on and then check the **OMNIFY** check box in, in order to Omnify the loaded game's process. This is a direct copy from the Omnified template .CT file containing all the boilerplate code required to load the framework and target hacking code. The only things specific to the game in this file are the game's data structures discovered through reverse engineering. 
    * **hooks.asm**: Game specific hooks for the target Omnified game. These generally consist of the initiation points for the various game-neutral Omnified systems. Sometimes they also include Omnified-flavored enhancements specific to that game as well.
* **legacyTargets/**: This is a historical archive of all Omnified games that were created prior to the advent of Omnified 2.0. More information about these targets can be found on the [legacyTargets](https://github.com/BadEcho/omnified-hacks/tree/master/legacyTargets) page in source control.

## More Information About Omnified Games

Previous playthroughs can be seen in their entirety on my [YouTube](https://www.youtube.com/omniTTV) and the VODs available on my [Twitch stream](https://twitch.tv/omni). You can also find a variety of articles regarding the hacking/Omnification of many the games on the [Bad Echo website](https://badecho.com/index.php/category/games/).

For all games that were created and beaten following the creation of my [hackpad](https://badecho.com), you can find a write-up/summary of the playthrough in the [Tombstones](https://badecho.com/index.php/category/tombstones/) section.

For all Omnified games that were played and beaten prior to the creation of my [hackpad](https://badecho.com/), you can find their tombstones in the **#tombstones** channel on my [Discord server](https://discord.gg/omni).

## About Bad Echo
Bad Echo is a collection of software technologies and [various writings](https://badecho.com) by Matt Weber: a software designer, partnered [Twitch](https://twitch.tv/omni) streamer, and game developer.

While Bad Echo code concerns itself a great deal with the "best approaches" to general software problems, it also focuses on game development and providing entertainment through the clever manipulation of games (the results of which are streamed by myself).

## Getting in Contact
I'm a partnered Twitch streamer, and talking to me during one of my [Omnified streams](https://twitch.tv/omni), on the off chance that I actually _am_ streaming, is most definitely the quickest way to get my attention!

You may also reach me [via email](mailto:matt@badecho.com).