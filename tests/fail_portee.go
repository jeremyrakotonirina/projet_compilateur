package main;
import "fmt";

func main() {
    if (true) {
        var y int = 42;
    };
    // erreur : y n'existe plus ici, il est mort à la fin du bloc if
    fmt.Print(y) 
};