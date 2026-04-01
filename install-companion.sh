#!/bin/sh
# ✨ Claude Code Companion Patcher
# Hack your companion to any Shiny Legendary you want!
# Run: sh install-companion.sh

set -e

# --- Locate cli.js ---
CLI=""
# 1) npm global install: follow symlink from `which claude`
CLAUDE_BIN="$(which claude 2>/dev/null || true)"
if [ -n "$CLAUDE_BIN" ]; then
  REAL="$(readlink -f "$CLAUDE_BIN" 2>/dev/null || readlink "$CLAUDE_BIN" 2>/dev/null || true)"
  [ -z "$REAL" ] && REAL="$(cd "$(dirname "$CLAUDE_BIN")" && pwd)/$(basename "$CLAUDE_BIN")"
  CANDIDATE="$(dirname "$REAL")/cli.js"
  [ -f "$CANDIDATE" ] && CLI="$CANDIDATE"
fi
# 2) native local install: ~/.claude/local/node_modules/...
if [ -z "$CLI" ]; then
  CANDIDATE="$HOME/.claude/local/node_modules/@anthropic-ai/claude-code/cli.js"
  [ -f "$CANDIDATE" ] && CLI="$CANDIDATE"
fi
# 3) Linux XDG: ~/.local/share/claude/...
if [ -z "$CLI" ]; then
  XDG="${XDG_DATA_HOME:-$HOME/.local/share}/claude"
  if [ -d "$XDG/versions" ]; then
    # find the latest version directory
    LATEST="$(ls -1t "$XDG/versions" 2>/dev/null | head -1)"
    [ -n "$LATEST" ] && CANDIDATE="$XDG/versions/$LATEST/cli.js"
    [ -f "$CANDIDATE" ] && CLI="$CANDIDATE"
  fi
  # also check node_modules pattern under XDG
  if [ -z "$CLI" ]; then
    CANDIDATE="$XDG/node_modules/@anthropic-ai/claude-code/cli.js"
    [ -f "$CANDIDATE" ] && CLI="$CANDIDATE"
  fi
fi
if [ -z "$CLI" ]; then
  echo "❌ cli.js not found. Searched:"
  echo "   - symlink from 'which claude'"
  echo "   - ~/.claude/local/node_modules/@anthropic-ai/claude-code/cli.js"
  echo "   - ~/.local/share/claude/versions/*/cli.js"
  echo "   Tip: set CLI_PATH env var to override: CLI_PATH=/path/to/cli.js sh $0"
  exit 1
fi
# Allow manual override
[ -n "$CLI_PATH" ] && CLI="$CLI_PATH"
echo "📦 Found cli.js: $CLI"

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

# --- Install auto-patch wrapper ---
PATCH_SCRIPT="$HOME/.claude/patch-companion.sh"
cat > "$PATCH_SCRIPT" << PATCHEOF
#!/bin/sh
# Auto-patch companion SALT before launching claude
SALT="$SALT"
CLI=""
CLAUDE_BIN="\$(which claude 2>/dev/null || true)"
if [ -n "\$CLAUDE_BIN" ]; then
  REAL="\$(readlink -f "\$CLAUDE_BIN" 2>/dev/null || readlink "\$CLAUDE_BIN" 2>/dev/null || true)"
  [ -z "\$REAL" ] && REAL="\$(cd "\$(dirname "\$CLAUDE_BIN")" && pwd)/\$(basename "\$CLAUDE_BIN")"
  C="\$(dirname "\$REAL")/cli.js"; [ -f "\$C" ] && CLI="\$C"
fi
[ -z "\$CLI" ] && C="\$HOME/.claude/local/node_modules/@anthropic-ai/claude-code/cli.js" && [ -f "\$C" ] && CLI="\$C"
[ -z "\$CLI" ] && exit 0
if ! grep -q "\$SALT" "\$CLI" 2>/dev/null; then
  if [ "\$(uname)" = "Darwin" ]; then
    sed -i '' "s/friend-2026-[0-9]*/\$SALT/g" "\$CLI"
  else
    sed -i "s/friend-2026-[0-9]*/\$SALT/g" "\$CLI"
  fi
fi
PATCHEOF
chmod +x "$PATCH_SCRIPT"

# Detect shell rc file
SHELL_RC=""
case "$SHELL" in
  */zsh)  SHELL_RC="$HOME/.zshrc";;
  */bash) SHELL_RC="$HOME/.bashrc";;
  *)      SHELL_RC="$HOME/.profile";;
esac

# Add alias: claude → patch then launch
ALIAS_LINE="alias claude='sh $PATCH_SCRIPT && command claude'"
if [ -f "$SHELL_RC" ] && grep -qF "patch-companion" "$SHELL_RC"; then
  echo "✅ Shell alias already installed in $SHELL_RC"
else
  printf "\n# Claude Companion auto-patch\n%s\n" "$ALIAS_LINE" >> "$SHELL_RC"
  echo "✅ Added alias to $SHELL_RC"
fi

echo ""
echo "🎉 Done! Run 'source $SHELL_RC' or open a new terminal."
echo "   Every 'claude' launch will auto-patch your companion."
