---
description: Create a new Foundry Forge project without default placeholder files and initialize git
argument-hint: "[project_name]"
allowed-tools:
  - "Bash(forge:*)"
  - "Bash(git:*)" 
  - "Bash(rm:*)"
  - "Bash(ls:*)"
  - "Bash(mkdir:*)"
---

Create a new Foundry Forge project named $ARGUMENTS (or "forge-project" if no name provided) with the following steps:

1. Initialize a new Forge project using `forge init`
2. Remove all default placeholder files:
   - Remove src/Counter.sol
   - Remove script/Counter.s.sol  
   - Remove test/Counter.t.sol
   - Remove any README.md files that contain default content
3. Initialize a git repository with `git init`
4. Create an initial commit with all the clean Forge structure

The resulting project should have a clean Foundry structure with:
- foundry.toml configuration
- Empty src/, script/, test/ directories
- lib/ directory with forge-std dependency
- A clean git repository

Do not ask for confirmation - proceed with creating the project structure immediately.