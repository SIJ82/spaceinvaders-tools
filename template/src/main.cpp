#include <curses.h>

#include "exampleClass.hpp"

int main() {
    // inizializza lo schermo
    initscr();

    exampleClass example("Tutto pronto! Premi un tasto per uscire.", 0, 0);
    example.draw();

    // una finestra di 10 righe e 20 colonne, con l'angolo in alto a sinistra in riga 10, colonna 10
    int height = 10;
    int width = 20;
    int start_y = 10;
    int start_x = 10;
    WINDOW* win = newwin(height, width, start_y, start_x);

    // aggiorna lo schermo
    refresh();

    // disegna il bordo della finestra e la mostra
    box(win, 0, 0);
    wrefresh(win);

    // aspetta un tasto, come "cin >> a;"
    getch();

    // libera la memoria e chiude curses
    delwin(win);
    endwin();
    return 0;
}
