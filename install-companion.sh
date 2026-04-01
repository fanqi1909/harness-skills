#!/bin/sh
# ✨ Claude Code Companion Patcher
# Hack your companion to any Shiny Legendary you want!
# Run: sh install-companion.sh

set -e

# --- Locate cli.js ---
CLAUDE_BIN="$(which claude 2>/dev/null || true)"
if [ -z "$CLAUDE_BIN" ]; then
  echo "❌ claude not found in PATH"; exit 1
fi
REAL="$(readlink -f "$CLAUDE_BIN" 2>/dev/null || readlink "$CLAUDE_BIN" 2>/dev/null)"
if [ -z "$REAL" ]; then
  # macOS fallback
  REAL="$(cd "$(dirname "$CLAUDE_BIN")" && pwd)/$(basename "$CLAUDE_BIN")"
fi
CLI="$(dirname "$REAL")/cli.js"
if [ ! -f "$CLI" ]; then
  echo "❌ cli.js not found at $CLI"; exit 1
fi

# --- Locate config ---
CONFIG="$HOME/.claude.json"
if [ ! -f "$CONFIG" ]; then
  CONFIG="$HOME/.claude/.config.json"
fi
if [ ! -f "$CONFIG" ]; then
  echo "❌ Config not found. Run claude and /buddy hatch first."; exit 1
fi

# --- Get UUID ---
UUID="$(node -e "const j=JSON.parse(require('fs').readFileSync('$CONFIG','utf8'));console.log(j.oauthAccount?.accountUuid??j.userID??'anon')")"
echo "🔑 Your ID: $UUID"
echo ""

# --- Pick species ---
echo "Pick your species:"
echo "  1) 🐉 dragon     2) 🐱 cat        3) 🐧 penguin"
echo "  4) 🐙 octopus    5) 🦆 duck       6) 🪿 goose"
echo "  7) 🫧 blob       8) 🦉 owl        9) 🐢 turtle"
echo " 10) 🐌 snail     11) 👻 ghost     12) 🦎 axolotl"
echo " 13) 🦫 capybara  14) 🌵 cactus    15) 🤖 robot"
echo " 16) 🐰 rabbit    17) 🍄 mushroom  18) 🟦 chonk"
echo "  0) Any (surprise me!)"
printf "> "
read -r PICK

SPECIES_LIST="duck goose blob cat dragon octopus owl penguin turtle snail ghost axolotl capybara cactus robot rabbit mushroom chonk"
case "$PICK" in
  1) WANT="dragon";;  2) WANT="cat";;      3) WANT="penguin";;
  4) WANT="octopus";; 5) WANT="duck";;     6) WANT="goose";;
  7) WANT="blob";;    8) WANT="owl";;      9) WANT="turtle";;
  10) WANT="snail";;  11) WANT="ghost";;   12) WANT="axolotl";;
  13) WANT="capybara";;14) WANT="cactus";; 15) WANT="robot";;
  16) WANT="rabbit";; 17) WANT="mushroom";;18) WANT="chonk";;
  *) WANT="";;
esac

# --- Shiny? ---
printf "Shiny? (y/N) > "
read -r SHINY_PICK
WANT_SHINY=false
case "$SHINY_PICK" in y|Y|yes|YES) WANT_SHINY=true;; esac

# --- Search ---
echo ""
echo "🔍 Searching for your perfect Legendary companion..."

RESULT="$(node -e "
const UUID='$UUID', WANT='$WANT', WANT_SHINY=$WANT_SHINY;
function mulberry32(s){let a=s>>>0;return function(){a|=0;a=(a+0x6d2b79f5)|0;let t=Math.imul(a^(a>>>15),1|a);t=(t+Math.imul(t^(t>>>7),61|t))^t;return((t^(t>>>14))>>>0)/4294967296}}
function hash(s){let h=2166136261;for(let i=0;i<s.length;i++){h^=s.charCodeAt(i);h=Math.imul(h,16777619)}return h>>>0}
const RW={common:60,uncommon:25,rare:10,epic:4,legendary:1};
const R=['common','uncommon','rare','epic','legendary'];
function rollR(g){let r=g()*100;for(const x of R){r-=RW[x];if(r<0)return x}return'common'}
const SP='duck goose blob cat dragon octopus owl penguin turtle snail ghost axolotl capybara cactus robot rabbit mushroom chonk'.split(' ');
const EY=['·','✦','×','◉','@','°'];
const HT=['none','crown','tophat','propeller','halo','wizard','beanie','tinyduck'];
function pick(g,a){return a[Math.floor(g()*a.length)]}
for(let i=0;i<500000;i++){
  const salt='friend-2026-'+i;
  const g=mulberry32(hash(UUID+salt));
  if(rollR(g)!=='legendary')continue;
  const species=pick(g,SP),eye=pick(g,EY),hat=pick(g,HT),shiny=g()<0.01;
  if(WANT&&species!==WANT)continue;
  if(WANT_SHINY&&!shiny)continue;
  console.log(JSON.stringify({salt,species,eye,hat,shiny}));
  process.exit(0);
}
console.log('NOTFOUND');
")"

if [ "$RESULT" = "NOTFOUND" ]; then
  echo "❌ No match found in 500k attempts. Try a different combo."; exit 1
fi

SALT="$(echo "$RESULT" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{const j=JSON.parse(d);console.log(j.salt)})")"
INFO="$(echo "$RESULT" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{const j=JSON.parse(d);console.log(j.species+' | eye: '+j.eye+' | hat: '+j.hat+' | shiny: '+j.shiny)})")"

echo "✨ Found: $INFO"
echo "   SALT:  $SALT"
echo ""

# --- Patch cli.js ---
if grep -q 'friend-2026-' "$CLI"; then
  if [ "$(uname)" = "Darwin" ]; then
    sed -i '' "s/friend-2026-[0-9]*/$(echo "$SALT" | sed 's/[&/\]/\\&/g')/g" "$CLI"
  else
    sed -i "s/friend-2026-[0-9]*/$(echo "$SALT" | sed 's/[&/\]/\\&/g')/g" "$CLI"
  fi
  echo "✅ Patched cli.js"
else
  echo "❌ SALT pattern not found in cli.js"; exit 1
fi

# --- Rename companion ---
printf "Name your companion (Enter to skip): "
read -r NAME
if [ -n "$NAME" ]; then
  node -e "
    const fs=require('fs'),f='$CONFIG';
    const j=JSON.parse(fs.readFileSync(f,'utf8'));
    if(j.companion){j.companion.name='$NAME';fs.writeFileSync(f,JSON.stringify(j,null,2));console.log('✅ Named → $NAME')}
    else console.log('⚠️  No companion — /buddy hatch first')
  "
fi

echo ""
echo "🎉 Done! Restart claude to meet your new Legendary companion."
