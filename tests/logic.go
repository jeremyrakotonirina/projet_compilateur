package main;
import "fmt";

// Résultat attendu : 1110
func main() {
    var t, f bool;
    t = true;
    f = false;

    // Test AND et NOT
    if (t && !f) { fmt.Print(1) } else { fmt.Print(0) };

    // Test OR
    if (f || t) { fmt.Print(1) } else { fmt.Print(0) };

    // Test Comparaisons entières
    if (10 >= 10) { fmt.Print(1) } else { fmt.Print(0) };
    if (5 == 6)   { fmt.Print(1) } else { fmt.Print(0) };
}
