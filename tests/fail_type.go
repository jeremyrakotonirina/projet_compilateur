package main;
import "fmt";

func main() {
    var x int;
    x = true; // erreur : on essaie de mettre un bool dans un int
    fmt.Print(x)
};