#include <curses.h>

int main() {
    initscr();
    printw("Tutto pronto! Premi un tasto per uscire.");
    refresh();
    getch();
    endwin();
    return 0;
}
