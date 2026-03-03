Compilateur Micro Go 
+1

Ce projet consiste en la réalisation d'un compilateur complet pour Micro Go, un fragment du langage Go, ciblant l'architecture MIPS.
+2

Développé en OCaml, il couvre toutes les étapes de la compilation : de l'analyse lexicale à la génération de code assembleur.
+1

Fonctionnalités du Langage
Micro Go est un sous-ensemble impératif de Go incluant :

• Types Primitifs : Entiers signés 32 bits , booléens où 0 représente false et chaînes de caractères représentées par des pointeurs dans le segment de données.
+4

• Structures & Pointeurs : Support des structures allouées sur le tas et manipulation via des pointeurs, incluant l'accès aux champs et la gestion de la valeur nil.
+3

• Contrôle de flot : Instructions conditionnelles if/else et boucles for déclinées en trois variantes : while, boucle infinie ou boucle classique.
+4

• Fonctions & Multi-retours : Capacité de définir des fonctions et de retourner des n-uplets de valeurs.
+2

• Affichage : Support de l'instruction fmt.Print pour des listes d'expressions de types arbitraires.
+1

Architecture du Compilateur
Le pipeline de compilation est structuré autour des phases suivantes :

• Analyse Lexicale & Syntaxique : Utilisation des outils ocamllex et menhir pour transformer le code source en un Arbre de Syntaxe Abstraite (AST).

• Insertion automatique de points-virgules : Gestion de l'ajout automatique des points-virgules en fin de ligne selon le contexte lexical.

• Analyse Sémantique (Typage) : Vérification de la conformité des types et gestion des fonctions ou structures mutuellement récursives.
+1

• Génération de Code MIPS : Stockage du résultat des expressions dans le registre $t0. Utilisation de la pile pour les calculs intermédiaires et le passage des arguments de fonction.
+1

• Gestion des Retours Multiples : Mise en œuvre par transformation de programme (passage par référence) ou par allocation de n-uplets sur le tas.
+1

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
