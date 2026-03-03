package main;
import "fmt";

func main() {
    var x int = 10;
    fmt.Print(x); // Affiche 10
    
    // Nouveau bloc : nouvelle portée
    {
        var x int = 20; // Cette variable "masque" le x externe
        fmt.Print(x);   // Affiche 20
    }
    
    // On est sortis du bloc, on doit retrouver le x d'origine
    fmt.Print(x); // Affiche 10
}
