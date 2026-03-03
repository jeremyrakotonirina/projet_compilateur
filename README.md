Compilateur Micro Go 


Ce projet consiste en la réalisation d'un compilateur complet pour Micro Go, un fragment du langage Go, ciblant l'architecture MIPS.


Développé en OCaml, il couvre toutes les étapes de la compilation : de l'analyse lexicale à la génération de code assembleur.


Fonctionnalités du Langage
Micro Go est un sous-ensemble impératif de Go incluant :

• Types Primitifs : Entiers signés 32 bits , booléens où 0 représente false et chaînes de caractères représentées par des pointeurs dans le segment de données.


• Structures & Pointeurs : Support des structures allouées sur le tas et manipulation via des pointeurs, incluant l'accès aux champs et la gestion de la valeur nil.


• Contrôle de flot : Instructions conditionnelles if/else et boucles for déclinées en trois variantes : while, boucle infinie ou boucle classique.


• Fonctions & Multi-retours : Capacité de définir des fonctions et de retourner des n-uplets de valeurs.


• Affichage : Support de l'instruction fmt.Print pour des listes d'expressions de types arbitraires.


Architecture du Compilateur
Le pipeline de compilation est structuré autour des phases suivantes :

• Analyse Lexicale & Syntaxique : Utilisation des outils ocamllex et menhir pour transformer le code source en un Arbre de Syntaxe Abstraite (AST).

• Insertion automatique de points-virgules : Gestion de l'ajout automatique des points-virgules en fin de ligne selon le contexte lexical.

• Analyse Sémantique (Typage) : Vérification de la conformité des types et gestion des fonctions ou structures mutuellement récursives.


• Génération de Code MIPS : Stockage du résultat des expressions dans le registre $t0. Utilisation de la pile pour les calculs intermédiaires et le passage des arguments de fonction.


• Gestion des Retours Multiples : Mise en œuvre par transformation de programme (passage par référence) ou par allocation de n-uplets sur le tas.


Utilisation
• Compilation du projet : dune build

• make test : lancer les tests

• make clean : nettoyer les fichiers générés

• make all : tout exécuter

Structure du Dépôt
• mgolexer.mll : Fichier de l'analyseur lexical.

• mgoparser.mly : Fichier de l'analyseur grammatical.

• typechecker.ml : Module de vérification des types.

• compile.ml : Module de génération de code MIPS.

• tests/ : Suite de tests incluant des programmes valides et invalides
