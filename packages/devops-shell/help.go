package main

import (
	"sort"
	"strings"
)

const help = `GopherForge lab shell: Bash syntax over your private /lab, offline.
Nothing here starts a host process or opens the network.

Files   ls [-laR] · cd · pwd · tree · find · mkdir [-p] · touch · cp [-r]
        mv · rm [-r] · rmdir · du · df · chmod · realpath · basename
Text    cat [-n] · head/tail [-n N] · wc · grep [-ivncE] · sed · awk · cut
        tr · sort [-rnu] · uniq [-c] · nl · rev · diff [-u] · tee · xargs
Data    echo · printf · seq · date · sha256sum · base64 · sleep
Shell   variables · $(command) · $((math)) · globs like *.log · pipes |
        && || ; · > >> < 2> 2>&1 &> /dev/null · <<EOF heredocs
        if · for · while · until · case · [[ ]] · functions · local
        export · read · set -euo pipefail · source · sh file · ./script.sh
Prompt  nano FILE opens the editor · Tab completes · ↑ ↓ history · clear

Limits  16 KiB per command or script, 5000 steps per run, 64 KiB per file
        and per output, 128 files and directories, 2 MiB in total.
Not here docker, kubectl, ssh, curl, sudo, package managers, background
        jobs or real processes.

Type help COMMAND for its options.
`

var usage = map[string]string{
	"ls":        "ls [-l] [-a] [-A] [-h] [-R] [-r] [-S] [-d] [PATH...]\n  -l long listing  -a include dotfiles  -h human sizes  -R recurse",
	"cd":        "cd [DIR]   no DIR goes to ~ (/lab); cd - returns to the previous directory",
	"pwd":       "pwd   print the working directory",
	"tree":      "tree [-a] [-d] [-L LEVEL] [DIR...]   draw the directory tree",
	"find":      "find [PATH...] [-name GLOB] [-iname GLOB] [-path GLOB] [-type f|d]\n     [-maxdepth N] [-mindepth N] [-empty]",
	"mkdir":     "mkdir [-p] [-v] DIR...   -p creates parents and accepts existing directories",
	"rmdir":     "rmdir DIR...   remove empty directories",
	"touch":     "touch FILE...   create empty files that do not exist yet",
	"cp":        "cp [-r] [-n] [-v] SOURCE... DEST   copy files, or directories with -r",
	"mv":        "mv [-n] [-v] SOURCE... DEST   move or rename files and directories",
	"rm":        "rm [-r] [-f] [-v] PATH...   -r removes directories, -f ignores missing files",
	"chmod":     "chmod MODE FILE...   accepted for scripts; permissions are not modelled in /lab",
	"du":        "du [-s] [-h] [PATH...]   disk usage in KiB",
	"df":        "df   how much of the 2 MiB lab quota is used",
	"echo":      "echo [-n] [-e] [WORD...]   -n no newline, -e interpret \\n \\t escapes",
	"printf":    "printf FORMAT [ARG...]   %s %d %f %x %c %b %q and widths like %-10s %05.2f",
	"cat":       "cat [-n] [-b] [-E] [FILE...]   print files; - or no file reads stdin",
	"head":      "head [-n N] [-c N] [FILE...]   first lines (10 by default)",
	"tail":      "tail [-n N] [-n +N] [-c N] [FILE...]   last lines, or from line N with +N",
	"wc":        "wc [-l] [-w] [-c] [-m] [FILE...]   count lines, words, bytes, characters",
	"grep":      "grep [-i] [-v] [-n] [-c] [-l] [-q] [-o] [-w] [-x] [-E] [-F] [-r] [-e PATTERN]\n     PATTERN [FILE...]   basic regular expressions; -E extended, -F literal",
	"sed":       "sed [-n] [-E] [-i] SCRIPT [FILE...]\n  commands: s/RE/REPL/[g p i N]  d  p  q  =  y/abc/xyz/  a TEXT  i TEXT  c TEXT\n  addresses: N  $  /RE/  and ranges like 2,5 or /start/,/end/; ! negates",
	"awk":       "awk [-F SEP] [-v NAME=VALUE] 'PROGRAM' [FILE...]\n  patterns: BEGIN END /RE/ expressions   actions: print printf if while for next exit\n  fields $0 $1 $NF, NR NF FS OFS, functions length substr index toupper tolower\n  int sprintf sub gsub sqrt. Arrays and getline are unavailable.",
	"cut":       "cut -f LIST [-d CHAR] [-s] | -c LIST [FILE...]   LIST like 1,3-5,7-",
	"tr":        "tr [-d] [-s] [-c] SET1 [SET2]   translate characters; ranges a-z, [:upper:]",
	"sort":      "sort [-r] [-n] [-u] [-f] [-h] [-k N] [-t SEP] [FILE...]",
	"uniq":      "uniq [-c] [-d] [-u] [-i] [FILE]   collapse adjacent duplicate lines",
	"nl":        "nl [-b a] [FILE...]   number lines",
	"rev":       "rev [FILE...]   reverse each line",
	"diff":      "diff [-u] [-q] FILE1 FILE2   exit 0 when equal, 1 when different",
	"tee":       "tee [-a] FILE...   copy stdin to files and to stdout",
	"xargs":     "xargs [-n N] [-I MARK] [-t] [-r] COMMAND [ARG...]   run a lab command with stdin words",
	"basename":  "basename PATH [SUFFIX]",
	"dirname":   "dirname PATH...",
	"realpath":  "realpath PATH...   absolute path inside /lab",
	"seq":       "seq [-s SEP] [-w] [FIRST [STEP]] LAST",
	"date":      "date [+FORMAT] [-u] [-I] [-R]   UTC time; %Y %m %d %H %M %S %F %T %s %a %b",
	"sleep":     "sleep SECONDS   up to 10 seconds; Stop interrupts it",
	"sha256sum": "sha256sum [FILE...]   one input prints its digest alone, as the guided labs record",
	"base64":    "base64 [-d] [-w COLS] [FILE]",
	"env":       "env   list variables (to set one for a command: NAME=value command)",
	"printenv":  "printenv [NAME...]",
	"export":    "export NAME[=VALUE]...",
	"set":       "set [-e] [-u] [-x] [-o pipefail] [-- ARG...]   options apply to this command line or script",
	"unset":     "unset [-f] NAME...",
	"read":      "read [-r] NAME...   read one line of stdin into variables",
	"test":      "test EXPR or [ EXPR ]: -e -f -d -s -n -z, = != < >, -eq -ne -lt -le -gt -ge, ! -a -o",
	"sh":        "sh [-e] [-x] FILE [ARG...] | sh -c 'COMMANDS' [NAME ARG...]   run in a child scope",
	"source":    "source FILE [ARG...]   run in the current shell, keeping its variables",
	"eval":      "eval WORD...   run the words as a command line",
	"type":      "type NAME...   say whether NAME is a builtin, keyword or function",
	"which":     "which NAME...",
	"command":   "command [-v] NAME [ARG...]   run NAME ignoring functions, or print what it is",
	"uname":     "uname [-a] [-s] [-n] [-r] [-m]",
	"exit":      "exit [N]",
	"return":    "return [N]   leave a function",
	"break":     "break [N]",
	"continue":  "continue [N]",
	"shift":     "shift [N]",
	"clear":     "clear   clear the terminal",
	"help":      "help [COMMAND]",
	"nano":      "nano FILE   open FILE in the built-in editor (type it at the prompt)",
}

func (s *Shell) help(cmd string, args []string, in *stream) (outcome, error) {
	if len(args) == 0 {
		return outcome{out: help}, nil
	}
	var out strings.Builder
	status := 0
	for _, name := range args {
		switch {
		case usage[name] != "":
			out.WriteString("usage: " + usage[name] + "\n")
		case unavailable[name] != "":
			out.WriteString(name + ": unavailable here: " + unavailable[name] + ".\n")
		case utilities[name] != nil:
			out.WriteString(name + ": a lab shell builtin\n")
		default:
			out.WriteString("help: no help for '" + name + "'. Commands: " + strings.Join(commandNames(), " ") + "\n")
			status = 1
		}
	}
	return outcome{out: out.String(), status: status}, nil
}

func commandNames() []string {
	var names []string
	for name := range utilities {
		if name != ":" && name != "[" && name != "." {
			names = append(names, name)
		}
	}
	sort.Strings(names)
	return names
}
