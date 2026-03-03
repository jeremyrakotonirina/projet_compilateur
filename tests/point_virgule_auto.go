package main

type Node struct { value int }

func main() {
    x := 1              // verifie qu'une affectation se termine bien sans ;
    x++                 // verifie qu'une incrementation ++ se termine bien sans ;
	x--                 // verifie qu'une incrementation -- se termine bien sans ;
    fmt.Println(x)      // verifie qu'un Println se termine bien sans ;
	boo1 := true        // verifie true 
	boo2 := false       // verifie false
	texte := "test"     // verifie string
	ptr := nil          // verifie nil

	p := new(Node)       // new suivi d’un retour à la ligne
    if p != nil {       // ): en fin de condition doit marquer SEMI (en theorie nil aussi mais ) a la priorite ici )
        p.value = 42         // entier: doit marquer SEMI
    }                   // }:  doit marquer SEMI
}

func incr(x int) int {
    return x + 1  // doit marquer SEMI meme si il y a le commentaire (deja teste avant aussi) et le cas return
}
// Le retour a la ligne en dessous est important sinon on ne rentre pas dans le cadre du bonus
