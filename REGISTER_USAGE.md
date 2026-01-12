# Convention d'utilisation des registres ARM

## Convention ARM AAPCS (ARM Architecture Procedure Call Standard)

### Registres scratch (peuvent être modifiés par les fonctions)
- **r0-r3** : Arguments et valeurs de retour
  - r0 : Premier argument / Valeur de retour
  - r1-r3 : Arguments supplémentaires
- **r12 (IP)** : Registre temporaire

### Registres préservés (DOIVENT être sauvegardés avec PUSH si modifiés)
- **r4-r11** : Variables locales persistantes
- **r13 (SP)** : Stack Pointer (ne JAMAIS modifier directement)
- **r14 (LR)** : Link Register (adresse de retour)

---

## Règles d'utilisation

### 1. Arguments et retours de fonction
- **Arguments** : Utiliser r0-r3
- **Retour** : Utiliser r0 (r1 pour retours multiples)

### 2. Sauvegarde des registres
```assembly
MA_FONCTION
    PUSH {r4-r7, LR}       ; Sauvegarder registres préservés utilisés
    ; ... code ...
    POP {r4-r7, PC}        ; Restaurer et retourner
```

### 3. Registres globaux du projet
- **r7** : Compteur de rotations (main.s)
- **r4** : Direction de rotation (retour de WAIT_SWITCH_PRESS)

Toutes les fonctions doivent préserver r7.

---

## Checklist pour chaque fonction

- [ ] Arguments dans r0-r3
- [ ] Retour dans r0
- [ ] PUSH {r4-r11, LR} si ces registres sont utilisés
- [ ] POP {r4-r11, PC} avant de retourner
- [ ] Ne jamais modifier SP directement

