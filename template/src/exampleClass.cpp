#include "exampleClass.hpp"

#include <cstring>
#include <curses.h>

exampleClass::exampleClass(const char* text, int row, int col) {
    // copia al massimo MAX_LENGTH caratteri e chiude sempre la stringa
    strncpy(this->text, text, MAX_LENGTH);
    this->text[MAX_LENGTH] = '\0';
    this->row = row;
    this->col = col;
}

void exampleClass::draw() const {
    mvprintw(row, col, "%s", text);
}
