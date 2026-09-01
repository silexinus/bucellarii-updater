# bucellarii_updater

Utility script for all bucellarii-class scripts and programs. Automates the updating process for every one of these, and lets you organize them however you want (say, one folder for bash scripts, another for julia scripts, ..., or all of them together). Ideally, interaction would be so seamless the user wouldn't even notice this exists.

## Usage
Updates itself:
```
  $:bucellarii_updater.sh --self-update
```

Updates a bucellarii-class script, such as tachibana:
```
  $:bucellarii_updater.sh --update tachibana
```

Displays the local and newest versions of a bucellarii-class script. Let's use messerbild for this example:
```
  $:bucellarii_updater.sh --compare-version messerbild
```

## System requirements
* bash

## License
GPLv3

## Bucellarii-class programs
* [tachibana](https://github.com/silexinus/tachibana)
