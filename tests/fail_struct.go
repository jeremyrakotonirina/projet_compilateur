package main;
import "fmt";

type Point struct {
    x, y int;
};

func main() {
    p := new(Point);
    p.x = 1;
    p.z = 2; // Erreur: le champ 'z' n'existe pas dans Point
    fmt.Print(p.x)
};