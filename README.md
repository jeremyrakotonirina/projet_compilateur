# **Compilateur Micro Go**

Ce projet consiste en la réalisation d'un **compilateur complet** pour **Micro Go**, un fragment du langage Go, ciblant l'architecture **MIPS**. Développé en **OCaml**, il couvre toutes les étapes de la compilation : de l'analyse lexicale à la génération de code assembleur.

---

## **Fonctionnalités du Langage**

**Micro Go** est un sous-ensemble impératif de Go incluant :

### **1. Types Primitifs**
• **Entiers** : signés sur 32 bits.

• **Booléens** : 0 représente `false` et une valeur non nulle représente `true`.

• **Chaînes de caractères** : représentées par un pointeur vers une chaîne statique allouée dans le segment de données.

### **2. Structures & Pointeurs**
• **Allocation sur le tas** : Les structures sont représentées par un bloc mémoire alloué sur le tas contenant les valeurs des champs.

• **Pointeurs** : Support des expressions de création `new(S)` et d'accès aux champs `e.x`.

• **Valeur nil** : Représentée par l'entier 0.


### **3. Contrôle de flot**
• **Conditionnelles** : Blocs `if/else`.

• **Boucles for** : Support des variantes style **while**, boucle **infinie** ou **classique** avec initialisation et post-instruction.

### **4. Fonctions & Multi-retours**
• **Définition** : Fonctions pouvant retourner plusieurs valeurs simultanément (n-uplets).

• **Appels** : Passage des arguments sur la pile.

---

## **Architecture du Compilateur**

Le pipeline de compilation est découpé en quatre phases principales :

• **Analyse Lexicale & Syntaxique** : Utilisation de **ocamllex** et **menhir** pour transformer le code source en un Arbre de Syntaxe Abstraite (AST). Gestion du **point-virgule automatique** en fin de ligne.

• **Analyse Sémantique (Typage)** : Vérification de la cohérence des types, de la portée des variables et de la validité des appels de fonctions, incluant la récursivité mutuelle.

• **Génération de Code MIPS** :
  - Le résultat des expressions est stocké dans le registre **$t0**.
  - Les calculs intermédiaires et les arguments de fonctions transitent par la **pile**.
  - Les structures sont représentées par des blocs mémoire sur le **tas**.

• **Gestion des Retours Multiples** : Implémentation via une transformation de programme (passage par référence) ou allocation sur le tas pour garantir la transmission des n-uplets.

---

## **Utilisation**

• **Compilation du projet** : `dune build`

• **make test** : lancer les tests automatisés

• **make clean** : nettoyer les fichiers générés

• **make all** : tout exécuter

---

## **Structure du Dépôt**

• **mgolexer.mll** : Analyseur lexical (ocamllex).

• **mgoparser.mly** : Grammaire grammaticale (menhir)

• **typechecker.ml** : Vérificateur de types statique

• **compile.ml** : Générateur de code MIPS

• **tests/** : Suite de tests incluant des programmes valides et invalides
