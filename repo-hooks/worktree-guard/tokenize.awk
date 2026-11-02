# Split a shell command into one token per line for bash.sh.
# Words come out with quotes and escapes removed. Operators come out prefixed
# with \037 (unit separator) so a quoted ";" or ">" stays a plain word:
#   \037;  any command boundary (; | & && || newline, ( ) of subshells and $(...))
#   \037>  output redirect; the next token is the file written
#   \037<  input redirect or here-string; the next token is read, not written
# Heredoc bodies and comments are dropped. Variables, globs and command
# substitutions are not expanded. POSIX awk (works with BSD awk, gawk, mawk).

function flush() { if (have) print tok; tok = ""; have = 0 }
function op(s)   { flush(); print "\037" s }

BEGIN { q = ""; tok = ""; have = 0; hd = ""; inbody = 0 }

{
  line = $0
  if (inbody) {
    l = line
    if (hdstrip) sub(/^\t+/, "", l)
    if (l == hd) { hd = ""; inbody = 0 }
    next
  }
  n = length(line); i = 1
  while (i <= n) {
    c = substr(line, i, 1)
    if (q != "") {
      if (c == q) q = ""
      else if (q == "\"" && c == "\\" && i < n) { i++; tok = tok substr(line, i, 1) }
      else tok = tok c
      i++; continue
    }
    nx = substr(line, i + 1, 1)
    if (c == "'" || c == "\"") { q = c; have = 1 }
    else if (c == "\\") { if (i < n) { i++; tok = tok substr(line, i, 1); have = 1 } }
    else if (c == " " || c == "\t") flush()
    else if (c == "#" && !have) break
    else if (c == ";" || c == "|" || c == "(" || c == ")") op(";")
    else if (c == "&") {
      if (nx == ">") { i++; if (substr(line, i + 1, 1) == ">") i++; op(">") }
      else { op(";"); if (nx == "&") i++ }
    }
    else if (c == ">") {
      if (tok ~ /^[0-9]+$/) { tok = ""; have = 0 }
      flush()
      if (nx == ">" || nx == "|") { i++; nx = substr(line, i + 1, 1) }
      if (nx == "&") { i++; while (substr(line, i + 1, 1) ~ /[0-9-]/) i++ }
      else op(">")
    }
    else if (c == "<") {
      if (tok ~ /^[0-9]+$/) { tok = ""; have = 0 }
      flush()
      if (substr(line, i + 1, 2) == "<<") { i += 2; op("<") }
      else if (nx == "<") {
        i++; hdstrip = 0
        if (substr(line, i + 1, 1) == "-") { i++; hdstrip = 1 }
        while (substr(line, i + 1, 1) == " ") i++
        hd = ""
        while (i < n) {
          ch = substr(line, i + 1, 1)
          if (ch ~ /[ \t;|&<>()]/) break
          if (ch != "'" && ch != "\"" && ch != "\\") hd = hd ch
          i++
        }
      }
      else if (nx == "(") { i++; op(";") }
      else if (nx == "&") { i++; while (substr(line, i + 1, 1) ~ /[0-9-]/) i++ }
      else op("<")
    }
    else { tok = tok c; have = 1 }
    i++
  }
  if (q != "") { tok = tok " "; next }
  op(";")
  if (hd != "") inbody = 1
}

END { flush() }
