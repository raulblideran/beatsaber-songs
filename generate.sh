#!/bin/bash

# Load Beat Saber path from config
BEATSABER_PATH=$(jq -r '.beatsaberPath' config.json)

echo "Generating static website from: $BEATSABER_PATH"
echo "Scanning songs..."

# Build JSON array directly to a file
echo "[" > songs_data.json
FIRST=true

# Loop through each song folder
for folder in "$BEATSABER_PATH"*/; do
    if [ -d "$folder" ]; then
        # Check for both Info.dat and info.dat (case-insensitive)
        INFO_FILE=""
        if [ -f "$folder/Info.dat" ]; then
            INFO_FILE="$folder/Info.dat"
        elif [ -f "$folder/info.dat" ]; then
            INFO_FILE="$folder/info.dat"
        fi

        if [ -n "$INFO_FILE" ]; then
            FOLDER_NAME=$(basename "$folder")

            # Read the Info.dat file
            SONG_NAME=$(jq -r '._songName // "Unknown"' "$INFO_FILE")
            SONG_SUB=$(jq -r '._songSubName // ""' "$INFO_FILE")
            ARTIST=$(jq -r '._songAuthorName // "Unknown Artist"' "$INFO_FILE")
            MAPPER=$(jq -r '._levelAuthorName // "Unknown Mapper"' "$INFO_FILE")
            BPM=$(jq -r '._beatsPerMinute // 0' "$INFO_FILE")
            COVER=$(jq -r '._coverImageFilename // ""' "$INFO_FILE")
            DIFFICULTIES=$(jq -r '._difficultyBeatmapSets[0]._difficultyBeatmaps[]._difficulty' "$INFO_FILE" 2>/dev/null | jq -R -s -c 'split("\n") | map(select(length > 0))')

            # Handle cover image
            COVER_DATA="null"
            if [ -n "$COVER" ] && [ -f "$folder/$COVER" ]; then
                COVER_BASE64=$(base64 -w 0 "$folder/$COVER")
                EXT="${COVER##*.}"
                MIME_TYPE="image/jpeg"
                case "$EXT" in
                    png) MIME_TYPE="image/png" ;;
                    jpg|jpeg) MIME_TYPE="image/jpeg" ;;
                    gif) MIME_TYPE="image/gif" ;;
                    webp) MIME_TYPE="image/webp" ;;
                esac
                COVER_DATA="\"data:$MIME_TYPE;base64,$COVER_BASE64\""
            fi

            # Add comma if not first entry
            if [ "$FIRST" = false ]; then
                echo "," >> songs_data.json
            fi
            FIRST=false

            # Escape quotes in strings properly
            SONG_NAME_ESC=$(echo "$SONG_NAME" | jq -R -s '.')
            SONG_SUB_ESC=$(echo "$SONG_SUB" | jq -R -s '.')
            ARTIST_ESC=$(echo "$ARTIST" | jq -R -s '.')
            MAPPER_ESC=$(echo "$MAPPER" | jq -R -s '.')

            # Write song JSON object directly to file
            echo -n "{\"id\":\"$FOLDER_NAME\",\"songName\":$SONG_NAME_ESC,\"songSubName\":$SONG_SUB_ESC,\"artist\":$ARTIST_ESC,\"mapper\":$MAPPER_ESC,\"bpm\":$BPM,\"coverImage\":$COVER_DATA,\"difficulties\":$DIFFICULTIES}" >> songs_data.json

            echo "  ✓ $SONG_NAME"
        fi
    fi
done

echo "]" >> songs_data.json

# Generate the HTML file
cat > index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Beat Saber Music Database</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <script>
    tailwind.config = {
      theme: {
        extend: {
          colors: {
            'dark-green': {
              50: '#f0fdf4',
              100: '#dcfce7',
              200: '#bbf7d0',
              300: '#86efac',
              400: '#4ade80',
              500: '#22c55e',
              600: '#16a34a',
              700: '#15803d',
              800: '#166534',
              900: '#14532d',
            }
          }
        }
      }
    }
  </script>
</head>
<body class="bg-gray-900 text-gray-100 min-h-screen p-4 md:p-6">
  <div class="container mx-auto max-w-full">
    <header class="text-center mb-8">
      <h1 class="text-4xl md:text-5xl font-bold mb-2 text-dark-green-400">🎵 Beat Saber Music Database</h1>
      <div class="text-lg md:text-xl text-gray-400">
        <span id="songCount">Loading...</span>
      </div>
    </header>

    <div class="bg-gray-800 p-5 rounded-lg shadow-lg mb-8 border border-gray-700">
      <input
        type="text"
        id="searchInput"
        class="w-full px-4 py-3 bg-gray-700 text-gray-100 border-2 border-dark-green-600 rounded-lg outline-none focus:border-dark-green-500 transition-colors mb-4 placeholder-gray-500"
        placeholder="Search by song name, artist, or mapper..."
      >
      <div class="flex gap-2 flex-wrap items-center">
        <span class="font-bold text-dark-green-400">Difficulty:</span>
        <button class="filter-btn px-4 py-2 border-2 border-dark-green-600 bg-gray-700 text-gray-300 rounded-full cursor-pointer transition-all font-bold hover:bg-dark-green-600 hover:text-white" data-difficulty="all">All</button>
        <button class="filter-btn px-4 py-2 border-2 border-dark-green-600 bg-gray-700 text-gray-300 rounded-full cursor-pointer transition-all font-bold hover:bg-dark-green-600 hover:text-white" data-difficulty="Easy">Easy</button>
        <button class="filter-btn px-4 py-2 border-2 border-dark-green-600 bg-gray-700 text-gray-300 rounded-full cursor-pointer transition-all font-bold hover:bg-dark-green-600 hover:text-white" data-difficulty="Normal">Normal</button>
        <button class="filter-btn px-4 py-2 border-2 border-dark-green-600 bg-gray-700 text-gray-300 rounded-full cursor-pointer transition-all font-bold hover:bg-dark-green-600 hover:text-white" data-difficulty="Hard">Hard</button>
        <button class="filter-btn px-4 py-2 border-2 border-dark-green-600 bg-gray-700 text-gray-300 rounded-full cursor-pointer transition-all font-bold hover:bg-dark-green-600 hover:text-white" data-difficulty="Expert">Expert</button>
        <button class="filter-btn px-4 py-2 border-2 border-dark-green-600 bg-gray-700 text-gray-300 rounded-full cursor-pointer transition-all font-bold hover:bg-dark-green-600 hover:text-white" data-difficulty="ExpertPlus">Expert+</button>
      </div>
    </div>

    <div id="songsContainer">
      <div class="text-center text-gray-300 text-xl py-12">Loading songs...</div>
    </div>
  </div>

  <script>
    const SONGS_DATA =
HTMLEOF

# Append the JSON data directly to the HTML file
cat songs_data.json >> index.html

# Append the rest of the HTML
cat >> index.html << 'HTMLEOF'
;

    let allSongs = SONGS_DATA.sort((a, b) => a.songName.localeCompare(b.songName));
    let filteredSongs = allSongs;
    let selectedDifficulty = 'all';

    function displaySongs() {
      const container = document.getElementById('songsContainer');

      if (filteredSongs.length === 0) {
        container.innerHTML = '<div class="text-center text-gray-300 text-xl py-12 bg-gray-800 rounded-lg">No songs found</div>';
        return;
      }

      const grid = document.createElement('div');
      grid.className = 'grid grid-cols-[repeat(auto-fill,minmax(180px,1fr))] gap-4 mb-8';

      filteredSongs.forEach(song => {
        const card = createSongCard(song);
        grid.appendChild(card);
      });

      container.innerHTML = '';
      container.appendChild(grid);
    }

    function createSongCard(song) {
      const card = document.createElement('div');
      card.className = 'bg-gray-800 rounded-lg overflow-hidden shadow-lg border border-gray-700 transition-transform hover:-translate-y-1 hover:shadow-xl cursor-pointer hover:border-dark-green-600';

      const difficultyColors = {
        'Easy': 'bg-green-500',
        'Normal': 'bg-blue-500',
        'Hard': 'bg-orange-500',
        'Expert': 'bg-red-500',
        'ExpertPlus': 'bg-purple-600'
      };

      card.innerHTML = `
        <div class="relative w-full pt-[100%] bg-gradient-to-br from-gray-700 to-gray-900 overflow-hidden">
          ${song.coverImage
            ? `<img src="${song.coverImage}" alt="${escapeHtml(song.songName)}" class="absolute top-0 left-0 w-full h-full object-cover" onerror="this.parentElement.innerHTML='<div class=\\'absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 text-6xl text-gray-600 opacity-30\\'>♪</div>'">`
            : '<div class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 text-6xl text-gray-600 opacity-30">♪</div>'
          }
        </div>
        <div class="p-2.5">
          <div class="text-sm font-bold mb-1 text-gray-100 break-words">${escapeHtml(song.songName)}</div>
          ${song.songSubName ? `<div class="text-xs text-dark-green-400 mb-1.5 overflow-hidden text-ellipsis whitespace-nowrap">${escapeHtml(song.songSubName)}</div>` : ''}
          <div class="text-xs text-gray-400 mb-1 overflow-hidden text-ellipsis whitespace-nowrap">🎤 ${escapeHtml(song.artist)}</div>
          <div class="text-xs text-gray-500 mb-1.5 overflow-hidden text-ellipsis whitespace-nowrap">📝 ${escapeHtml(song.mapper)}</div>
          <div class="flex justify-between items-center pt-1.5 border-t border-gray-700">
            <div class="bg-dark-green-600 text-white px-2 py-1 rounded-lg text-xs font-bold">${song.bpm} BPM</div>
            <div class="flex gap-1 flex-wrap">
              ${song.difficulties.map(d =>
                `<span class="${difficultyColors[d] || 'bg-gray-500'} text-white px-1.5 py-0.5 rounded text-[10px] font-bold uppercase">${d}</span>`
              ).join('')}
            </div>
          </div>
        </div>
      `;

      return card;
    }

    function escapeHtml(text) {
      const div = document.createElement('div');
      div.textContent = text;
      return div.innerHTML;
    }

    function updateStats() {
      document.getElementById('songCount').textContent =
        `${filteredSongs.length} of ${allSongs.length} songs`;
    }

    function applyFilters() {
      const searchQuery = document.getElementById('searchInput').value.toLowerCase();

      filteredSongs = allSongs.filter(song => {
        const matchesSearch = !searchQuery ||
          song.songName.toLowerCase().includes(searchQuery) ||
          song.artist.toLowerCase().includes(searchQuery) ||
          song.mapper.toLowerCase().includes(searchQuery) ||
          (song.songSubName && song.songSubName.toLowerCase().includes(searchQuery));

        const matchesDifficulty = selectedDifficulty === 'all' ||
          song.difficulties.includes(selectedDifficulty);

        return matchesSearch && matchesDifficulty;
      });

      displaySongs();
      updateStats();
    }

    document.getElementById('searchInput').addEventListener('input', applyFilters);

    document.querySelectorAll('.filter-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        document.querySelectorAll('.filter-btn').forEach(b => {
          b.classList.remove('bg-dark-green-600', 'text-white');
          b.classList.add('bg-gray-700', 'text-gray-300');
        });
        btn.classList.remove('bg-gray-700', 'text-gray-300');
        btn.classList.add('bg-dark-green-600', 'text-white');
        selectedDifficulty = btn.dataset.difficulty;
        applyFilters();
      });
    });

    // Set initial active state
    document.querySelector('.filter-btn[data-difficulty="all"]').classList.remove('bg-gray-700', 'text-gray-300');
    document.querySelector('.filter-btn[data-difficulty="all"]').classList.add('bg-dark-green-600', 'text-white');

    displaySongs();
    updateStats();
  </script>
</body>
</html>
HTMLEOF

SONG_COUNT=$(jq length songs_data.json)

echo ""
echo "✅ Generated index.html successfully!"
echo "📊 Total songs: $SONG_COUNT"
echo "📁 Open index.html in your browser to view the database"
echo ""
echo "Note: songs_data.json was created as a temporary file. You can delete it if you want."
