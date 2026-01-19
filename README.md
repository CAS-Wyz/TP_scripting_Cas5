# TP Scripting - Cas 5 : Synchronisation sélective

## 📝 Contexte
L'objectif de ce projet est de mettre en place un script **Bash** permettant de relier deux environnements contenant des versions différentes de fichiers identiques. Le script assure une **synchronisation bidirectionnelle** intelligente et sécurisée.

## 📥 Entrées
* **Environnement A** : Répertoire contenant les fichiers sources/mis à jour.
* **Environnement B** : Répertoire cible pour la synchronisation.
* **`protected_files.txt`** : Fichier de configuration listant les fichiers protégés (non synchronisables).
* **Fichiers `.meta`** : Fichiers optionnels contenant les versions, auteurs et checksums pour l'arbitrage.

## 📤 Sorties
* **Synchronisation effective** : Les fichiers mis à jour dans les deux environnements.
* **`sync_report.log`** : Journal détaillé des décisions prises (copies, conflits, protections).

---

## 🤖 Pseudo-Code

### 1. Initialisation du système
* **DÉFINIR** les chemins : `REP_A = "/env_A/"` et `REP_B = "/env_B/"`
* **CHARGER** la liste `fichiers_proteges` à partir de `protected_files.txt`
* **OUVRIR** le fichier `sync_log.txt` en mode écriture
* **LISTER** tous les fichiers de `REP_A` et `REP_B` (en excluant les fichiers `.meta`)

### 2. Boucle de traitement principale
**POUR CHAQUE** `nom_fichier` **DANS** `liste_globale` **FAIRE :**

#### **Étape 1 : Vérification de la protection**
* **SI** `nom_fichier` est présent dans `fichiers_proteges` **ALORS**
    * **JOURNALISER** : "Ignoré", Justification : "Fichier protégé par configuration"
    * **PASSER** au fichier suivant

#### **Étape 2 : Analyse de la présence**
* `existe_dans_A` = VRAI si le fichier est présent dans `REP_A`
* `existe_dans_B` = VRAI si le fichier est présent dans `REP_B`

#### **Étape 3 : Cas de présence unique (Copie simple)**
* **SI** (`existe_dans_A` ET NON `existe_dans_B`) **ALORS**
    * **COPIER** de `REP_A` vers `REP_B`
    * **JOURNALISER** : "Copié A vers B", Justification : "Absent de l'environnement B"
* **SINON SI** (NON `existe_dans_A` ET `existe_dans_B`) **ALORS**
    * **COPIER** de `REP_B` vers `REP_A`
    * **JOURNALISER** : "Copié B vers A", Justification : "Absent de l'environnement A"

#### **Étape 4 : Cas de présence double (Conflit ou Version)**
* **SINON SI** (`existe_dans_A` ET `existe_dans_B`) **ALORS**
    * **TENTER** de lire `version_A` et `version_B` dans les fichiers `.meta` respectifs
    * **SI** (`version_A` existe ET `version_B` existe) **ALORS**
        * **SI** (`version_A` > `version_B`) **ALORS**
            * **COPIER** de A vers B | **JOURNALISER** : "Version plus récente en A"
        * **SINON SI** (`version_B` > `version_A`) **ALORS**
            * **COPIER** de B vers A | **JOURNALISER** : "Version plus récente en B"
        * **SINON** (Versions égales)
            * **JOURNALISER** : "Ignoré", Justification : "Versions identiques"
    * **SINON** (Métadonnées manquantes)
        * **JOURNALISER** : "Conflit détecté", Justification : "Métadonnées absentes pour arbitrage"
    * **FIN SI**
**FIN POUR**
