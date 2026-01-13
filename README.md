# ing1-s1-architecture-project

Program for Stallaris Evalbot robot which calculate the area of a room

# Development research

- Robot speed = 2cm/s (at full speed = 0x192)
- Robot length = 10cm

# State diagram

## Initialisation

```mermaid
stateDiagram-v2
    [*] --> Initialisation

    Initialisation --> AttenteDirection : Modules initialisés
    note right of Initialisation
        MOTEUR_INIT
        BUMPERS_INIT
        SWITCHES_INIT
        LEDS_INIT
    end note

    AttenteDirection --> DebutLoop : Direction choisie (SW1/SW2)
    note right of AttenteDirection
        SW1 = rotation gauche
        SW2 = rotation droite
        Stocké dans r4
    end note
```

## Boucle

```mermaid
stateDiagram-v2
    DebutLoop --> DemarrageMoteurs : Compteur < 4
    note right of DebutLoop
        r7 = compteur rotations
        Initialisé à 0
    end note

    DemarrageMoteurs --> AvancerDroit : Chrono démarré
    note right of DemarrageMoteurs
        CHRONO_START
        MOTEUR_GAUCHE_AVANT
        MOTEUR_DROIT_AVANT
        MOTEUR_ON
    end note

    AvancerDroit --> VerifierBumpers : Moteurs actifs

    VerifierBumpers --> CollisionDetectee : Bumpers pressés (0x00)
    VerifierBumpers --> VerifierBumpers : Bumpers non pressés (0x03)

    CollisionDetectee --> StockerDistance : Chrono arrêté
    note right of CollisionDetectee
        CHRONO_STOP_DISTANCE
        Calcule distance en cm
    end note

    StockerDistance --> ArretMoteurs : Distance → tableau[r7]

    ArretMoteurs --> ChoixRotation : Moteurs arrêtés

    ChoixRotation --> RotationGauche : r4 == 1
    ChoixRotation --> RotationDroite : r4 == 2

    RotationGauche --> IncrementCompteur : ROTATION_90_GAUCHE
    RotationDroite --> IncrementCompteur : ROTATION_90_DROITE

    IncrementCompteur --> VerifCompteur : r7++

    VerifCompteur --> DebutLoop : r7 < 4
```

## Résultat

```mermaid
stateDiagram-v2
    VerifCompteur --> CalculResultat : r7 >= 4

    CalculResultat --> CalculDizaines : résultat = distance[1] × distance[2]
    note right of CalculResultat
        Multiplication des
        distances 1 et 2
        Stocké dans r5
    end note

    CalculDizaines --> AfficheDizaines : dizaines = r5 / 10

    AfficheDizaines --> Pause2s : LED clignote N fois

    Pause2s --> CalculUnites : DELAY 2000ms

    CalculUnites --> AfficheUnites : unités = r5 % 10

    AfficheUnites --> [*] : LED clignote N fois
```
