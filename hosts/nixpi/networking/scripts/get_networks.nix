{ pkgs, ...}:
pkgs.writeShellScriptBin "get_networks" ''
#!${pkgs.bash}/bin/bash
scan_output=$(sudo iwlist wlan0 scan)

# Define an associative array to store max lengths of each column
declare -A max_length
max_length[mac]=0
max_length[essid]=0
max_length[frq]=0
max_length[chn]=0
max_length[qual]=0
max_length[lvl]=0
max_length[enc]=0

# Define an array to store all entries
declare -a entries

# First pass: calculate the maximum lengths and collect entries
current_entry=""
while IFS= read -r line; do
    if [[ "$line" =~ Address ]]; then
        mac=''${line##*ss: }
        [[ ''${#mac} -gt ''${max_length[mac]} ]] && max_length[mac]=''${#mac}
    elif [[ "$line" =~ "Channel:" ]]; then
        chn=''${line##*nel:}
        [[ ''${#chn} -gt ''${max_length[chn]} ]] && max_length[chn]=''${#chn}
    elif [[ "$line" =~ Frequen ]]; then
        frq=''${line##*ncy:}
        frq=''${frq%% *}
        [[ ''${#frq} -gt ''${max_length[frq]} ]] && max_length[frq]=''${#frq}
    elif [[ "$line" =~ Quality ]]; then
        qual=''${line##*ity=}
        qual=''${qual%% *}
        [[ ''${#qual} -gt ''${max_length[qual]} ]] && max_length[qual]=''${#qual}
        lvl=''${line##*evel=}
        lvl=''${lvl%% *}
        [[ ''${#lvl} -gt ''${max_length[lvl]} ]] && max_length[lvl]=''${#lvl}
    elif [[ "$line" =~ Encrypt ]]; then
        enc=''${line##*key:}
        [[ ''${#enc} -gt ''${max_length[enc]} ]] && max_length[enc]=''${#enc}
    elif [[ "$line" =~ ESSID ]]; then
        essid=''${line##*ID:}
        [[ ''${#essid} -gt ''${max_length[essid]} ]] && max_length[essid]=''${#essid}
        entry="$mac|$essid|$frq|$chn|$qual|$lvl|$enc"
        entries+=("$entry")
    fi
    done <<< "$scan_output"

# Sort entries by ESSID
IFS=$'\n' sorted_entries=($(sort -t'|' -k2 <<<"''${entries[*]}"))
unset IFS

# Print header line
printf "\n"
printf " %-*s %-*s %-*s %-*s %-*s %-*s %-*s\n" \
  ''${max_length[mac]} "mac" ''${max_length[essid]} "essid" ''${max_length[frq]} "frq" ''${max_length[chn]} "chn" ''${max_length[qual]} "qual" ''${max_length[lvl]} "lvl" ''${max_length[enc]} "enc"

channels_24=()
channels_5=()

# Print sorted data
for entry in "''${sorted_entries[@]}"; do
    IFS='|' read -r mac essid frq chn qual lvl enc <<< "$entry"
    if [[ -z "$essid" || "$essid" =~ ^\"?[[:space:]]*\"?$ ]]; then
      continue
    fi
    frq="''${frq:--1}"
    if [ "$chn" -le "14" ]; then
      channels_24+=($chn)
    else 
      channels_5+=($chn)
    fi
    kmy_list+=("item$i")
    printf " %-*s %-*s %-*s %-*s %-*s %-*s %-*s\n" \
      ''${max_length[mac]} "$mac" ''${max_length[essid]} "$essid" ''${max_length[frq]} "$frq" ''${max_length[chn]} "$chn" ''${max_length[qual]} "$qual" ''${max_length[lvl]} "$lvl" ''${max_length[enc]} "$enc"
done

used_24ghz_channels="''${channels_24[*]}"
used_5ghz_channels="''${channels_5[*]}"
# Unique and sorted
used_24ghz_channels=$(echo "$used_24ghz_channels" | sort -n | uniq)
used_5ghz_channels=$(echo "$used_5ghz_channels" | sort -n | uniq)

# Define all possible channels
all_24ghz_channels=$(echo "1 2 3 4 5 6 7 8 9 10 11 12 13 14" | sort -n | uniq)
all_5ghz_channels=$(echo "36 40 44 48 149 153 157 161 165" | sort -n | uniq)
all_40wide_channels=$(echo "36 44 149 157" | sort -n | uniq)

# Find unused channels by comparing all possible channels with used channels
unused_24ghz_channels=$(comm -23 <(echo "$all_24ghz_channels" | tr " " "\n" | sort) <(echo "$used_24ghz_channels" | tr " " "\n" | sort))
unused_5ghz_channels=$(comm -23 <(echo "$all_5ghz_channels" | tr " " "\n" | sort) <(echo "$used_5ghz_channels" | tr " " "\n" | sort))
unused_40wide_channels=$(comm -23 <(echo "$all_40wide_channels" | tr " " "\n" | sort) <(echo "$used_5ghz_channels" | tr " " "\n" | sort))


echo "''${unused_5ghz_channels//$'\n'/ }"
echo "''${unused_24ghz_channels//$'\n'/ }"
echo "''${unused_40wide_channels//$'\n'/ }"

# Output the best channels
if [[ -z "$unused_24ghz_channels" ]]; then
  echo "No unused 2.4GHz channels found."
else
  echo "Best 2.4GHz channel to use: $(echo "$unused_24ghz_channels" | head -n 1)"
fi

if [[ -z "$unused_5ghz_channels" ]]; then
  echo "No unused 5GHz channels found."
else
  echo "Best 5GHz channel to use: $(echo "$unused_5ghz_channels" | head -n 1)"
fi
if [[ -z "$unused_40wide_channels" ]]; then
  echo "No unused 5GHz channels found for 40 wide."
else
  echo "Best 5GHz channel to use for 40 wide: $(echo "$unused_40wide_channels" | head -n 1)"
fi
''
