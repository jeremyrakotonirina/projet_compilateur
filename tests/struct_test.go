package main;
import "fmt";

type Node struct {
    val int;
    next *Node;
};

// Résultat attendu : 1 2 3
func main() {
    var n1, n2, n3 *Node;
    
    n1 = new(Node);
    n2 = new(Node);
    n3 = new(Node);

    n1.val = 1;
    n2.val = 2;
    n3.val = 3;

    // Chainage : n1 -> n2 -> n3
    n1.next = n2;
    n2.next = n3;

    fmt.Print(n1.val);
    fmt.Print(n1.next.val);       // Accès imbriqué 1 niveau
    fmt.Print(n1.next.next.val);  // Accès imbriqué 2 niveaux
}
