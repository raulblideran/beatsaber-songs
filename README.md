# Beat Saber Music Database

A fully static website to browse your Beat Saber custom songs.

## Usage

1. Run the generator script:
   ```bash
   ./generate.sh
   ```

2. Open `index.html` in your browser

## Features

- Search songs by name, artist, or mapper
- Filter by difficulty level
- View cover art (embedded as base64)
- Displays BPM and available difficulties
- Fully static - no web server needed

## Updating

The Beat Saber folder path is saved in `config.json`. To update:

1. Edit `config.json` if you want to change the path
2. Run `./generate.sh` again to regenerate the website

## Configuration

Current path: `/var/home/raul/.local/share/Steam/steamapps/common/Beat Saber/Beat Saber_Data/CustomLevels/`

To change it, edit `config.json`.
