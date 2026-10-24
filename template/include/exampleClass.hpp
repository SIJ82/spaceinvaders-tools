#ifndef EXAMPLECLASS_HPP
#define EXAMPLECLASS_HPP

// Classe di esempio: un testo da scrivere sullo schermo in una certa posizione.
// Ogni classe ha il suo header in include/ (la dichiarazione) e il suo .cpp in src/ (il codice dei metodi).
class exampleClass {
public:
    static const int MAX_LENGTH = 80;

    exampleClass(const char* text, int row, int col);
    void draw() const;

private:
    char text[MAX_LENGTH + 1];
    int row;
    int col;
};

#endif
