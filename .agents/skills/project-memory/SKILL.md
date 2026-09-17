---
name: project-memory
description: Read/update PROJECT_MEMORY.md at session start and end so context survives across sessions for this project
---

# Project Memory Protocol

Project hii ina file ya kumbukumbu: `PROJECT_MEMORY.md` (root).

## Mwanzo wa kila session (LAZIMA)
1. Soma `PROJECT_MEMORY.md` kabla ya kujibu request yoyote ya kazi.
2. Kama request ya user inahusiana na kazi iliyopo kwenye "Kazi inayoendelea", anza pale ilipoisha — usianze upya.
3. Kama user anauliza "tulifanya nini iliyopita?", jibu kwa kutumia "Log" na "Hali ya sasa" kutoka file hiyo.

## Mwisho wa kila kazi (LAZIMA)
1. Update `PROJECT_MEMORY.md`:
   - "Hali ya sasa" — hali mpya ya code.
   - "Kazi inayoendelea" — ondoa kazi iliyokamilika, ongeza mpya zilizobaki.
   - "Maamuzi" — ongeza maamuzi mapya yaliyokubaliwa na user.
   - "Log" — ongeza mstari mmoja: tarehe + kazi iliyofanyika (mfupi).
2. Usifute history ya Log — ongeza tu juu (mpya kwanza) au chini kwa mtiririko wa tarehe.
3. Kama user ametoa maamuzi/pendezi mpya (mfano: "usiweke X", "tumia Y"), iandike kwenye "Maamuzi".

## Kanuni
- Memory iwe FUPII na ya KWELI — si diary ndefu. Mistari 1-2 kwa kila entry.
- Tumia tarehe (YYYY-MM-DD) kwenye Log kila wakati.
- Kama file ya memory haipo, itengeneze upya kwa muundo huo huo.
- File hii (SKILL.md) isibadilishwe bila sababu — memory yenyewe ni `PROJECT_MEMORY.md` pekee.
