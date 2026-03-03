# Projet : Compilateur Micro Go

## Présentation du projet

[cite_start]Ce projet consiste en la réalisation d'un **compilateur complet** pour un fragment du langage Go, appelé **Micro Go**[cite: 65]. [cite_start]Le compilateur est développé en **OCaml** et produit du code assembleur pour l'architecture **MIPS**[cite: 5, 65]. 

[cite_start]L'objectif est de transformer un code source impératif incluant des structures de données complexes et des fonctions à retours multiples en un programme exécutable sur un simulateur MIPS[cite: 5, 65].

---

## Fonctionnalités réalisées

### 1. Types et Primitives
- [cite_start]**Entiers** : Support des entiers signés sur 32 bits[cite: 12].
- [cite_start]**Booléens** : Représentés par des entiers (0 pour `false`, non nul pour `true`)[cite: 13].
- [cite_start]**Chaînes de caractères** : Stockage via un pointeur vers le segment de données[cite: 14].
- [cite_start]**Valeur nil** : Représentée par l'entier 0, distincte de toute adresse de structure[cite: 18].

### 2. Structures et Pointeurs
- [cite_start]**Gestion du tas** : Les structures sont allouées dynamiquement sur le tas[cite: 15].
- [cite_start]**Accès aux champs** : Utilisation de tables pour localiser la position de chaque champ dans une structure[cite: 17, 263].
- [cite_start]**Pointeurs** : Manipulation explicite via les expressions `*e` et `&e`[cite: 72, 157].

### 3. Mécaniques de contrôle
- [cite_start]**Boucles for** : Implémentation des variantes "while", boucle infinie et boucle classique `for i; e; i {b}`[cite: 174, 177, 178].
- [cite_start]**Conditionnelles** : Blocs `if` et `else` complets [cite: 163, 231-233].
- [cite_start]**Point-virgule automatique** : Insertion automatique des points-virgules par l'analyseur lexical en fin de ligne[cite: 132].

### 4. Fonctions et Multi-retours
- [cite_start]**N-uplets** : Possibilité de renvoyer plusieurs valeurs comme résultat d'une fonction[cite: 74, 156].
- [cite_start]**Passage de paramètres** : Les arguments sont transmis via la pile[cite: 9].
- [cite_start]**Affectation multiple** : Gestion des syntaxes comme `x, y := f()`[cite: 160, 243].

### 5. Affichage
- [cite_start]**Instruction fmt.Print** : Application à des listes d'expressions de types arbitraires[cite: 21, 294].

---

## Architecture du projet

Le projet est structuré selon un pipeline de compilation classique.

### 1. Analyse Lexicale et Syntaxique
[cite_start]**Outils** : `ocamllex` et `menhir`[cite: 338].

**Responsabilités** :
- [cite_start]Transformation du code source en un **Arbre de Syntaxe Abstraite (AST)**[cite: 339, 340].
- [cite_start]Gestion des commentaires (`/* */` et `//`) et des mots-clés du langage [cite: 107-109, 115].

### 2. Analyse Sémantique (Typage)
[cite_start]**Module principal** : `typechecker.ml`[cite: 338].

**Responsabilités** :
- [cite_start]Vérification de la cohérence des types et de la portée des variables[cite: 236, 237, 289].
- [cite_start]Gestion des fonctions et structures **mutuellement récursives**[cite: 317].
- [cite_start]Validation des instructions `return` et des chemins d'exécution[cite: 332].

### 3. Génération de Code (MIPS)
[cite_start]**Module principal** : `compile.ml`[cite: 51].

**Responsabilités** :
- [cite_start]Stockage des résultats d'expressions dans le registre `$t0`[cite: 8].
- [cite_start]Utilisation de la **pile** pour les calculs intermédiaires et l'appel de fonctions[cite: 8, 9].
- [cite_start]Transformation des retours multiples en paramètres passés par référence ou en n-uplets sur le tas[cite: 25, 47].

---

## Répartition du travail

[cite_start]Le projet a été réalisé en binôme[cite: 342]. [cite_start]Nous avons choisi de travailler conjointement sur l'ensemble des modules (`mgolexer.mll`, `mgoparser.mly`, `typechecker.ml`) pour garantir une compréhension commune de la gestion de la mémoire et du passage des arguments[cite: 339]. [cite_start]Cette méthode nous a permis de résoudre plus efficacement les défis liés à la génération de code MIPS pour les structures récursives[cite: 343].

---

## Comment jouer (Utilisation)

### Lancement de la compilation
- **Compiler le projet** : Exécuter `dune build` dans le terminal.
- **Nettoyer les binaires** : Utiliser `make clean`.

### Commandes disponibles
- **Vérification syntaxique seule** : 
  [cite_start]`./mgoc --parse-only fichier.go`[cite: 350].
- **Vérification de typage seule** : 
  [cite_start]`./mgoc --type-only fichier.go`[cite: 366].
- **Compilation complète vers MIPS** : 
  `./mgoc fichier.go` (produit un fichier assembleur).

### Tests
- [cite_start]Une suite de tests est disponible dans le dossier `tests/` pour vérifier les cas valides et les erreurs attendues[cite: 338, 341].
- Pour lancer les tests : `make test`.
