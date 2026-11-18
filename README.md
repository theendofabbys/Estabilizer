Ferramenta em bash que estabiliza um reverse shell já obtido: abre PTY real, define `TERM=xterm`,
`stty sane` e o tamanho do terminal.

uso:
chmod +x main.sh
./main.sh

apos rodar, locamente:
Ctrl+Z
stty raw -echo; fg



