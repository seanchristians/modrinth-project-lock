# Modrinth project lock

This script creates a lock-file for use as a Modrinth package "listing file" in the [itzg/docker-minecraft-server](https://docker-minecraft-server.readthedocs.io/en/latest/mods-and-plugins/modrinth/#usage).

## Project definition file format

Create a `modrinth.yaml` file that specifies your game version, modloader, and Modrinth projects. Here's the most basic format:

```yaml
---
minecraft_version: 26.1.2
loader: fabric
projects:
  - id: fabric-api
```

Each project can specify the following attributes:

- `id` can be either the Modrinth project ID or slug
- `game_version` defaults to `minecraft_version` but can be set to override it in certain scenarios
- `prefix` defaults to `loader` - see here for other options: [itzg/docker-minecraft-server "Auto-download from Modrinth"](https://docker-minecraft-server.readthedocs.io/en/latest/mods-and-plugins/modrinth/#usage)
- `release_type` defaults to "release" - see above link for other options

A sample [modrinth.yaml](./samples/modrinth.yaml) file is available in the samples folder.

## Script usage

Navigate to the folder containing your `modrinth.yaml` file and run [modrinth-project-lock.sh](./modrinth-project-lock.sh).

A file called "modrinth.lock.txt" will be created. (See example in the samples folder)

Provide this file to your itzg/docker-minecraft-server by setting the env var `MODRINTH_PROJECTS=@/path/to/modrinth.lock.txt` (make sure your lock-file is available inside your container).

## GitHub Action usage

You can use GitHub Actions to automatically check for updates to your lock-file and propose a PR when updates are available.

```yaml
permissions:
  contents: write
  pull-requests: write
steps:
  - uses: actions/checkout@v7
  - uses: seanchristians/modrinth-project-lock@v1
```

|     Input      | Required | Description                              | Default         | Example value           |
| :------------: | :------: | ---------------------------------------- | --------------- | ----------------------- |
| `project-file` | `False`  | Path to your Modrinth project YAML file. | ./modrinth.yaml | `samples/modrinth.yaml` |
