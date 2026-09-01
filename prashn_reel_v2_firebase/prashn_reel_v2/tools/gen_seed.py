#!/usr/bin/env python3
"""firebase/seed/questions.json se lib/data/seed_questions.dart banata hai.

Naye prashn questions.json me jodein, phir:
    python3 tools/gen_seed.py
"""
import json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'firebase', 'seed', 'questions.json')
OUT = os.path.join(ROOT, 'lib', 'data', 'seed_questions.dart')
SUBJECTS = {'itihas','polity','bhugol','arth','vigyan','up','ca','hindi'}

def dq(s):
    return "'" + s.replace('\\','\\\\').replace("'", "\\'").replace('$','\\$').replace('\n',' ') + "'"

qs = json.load(open(SRC, encoding='utf-8'))

ids = set()
for q in qs:
    assert q['id'] not in ids, f"duplicate id: {q['id']}"
    ids.add(q['id'])
    assert len(q['options']) == 4, q['id']
    assert 0 <= q['answer'] <= 3, q['id']
    assert q['subject'] in SUBJECTS, q['id']

lines = ["// GENERATED FILE — firebase/seed/questions.json se bani hai, haath se na badlein.",
         "// Naye prashn questions.json me jodein, phir: python3 tools/gen_seed.py",
         "",
         "const List<Map<String, dynamic>> kSeedQuestions = ["]
for q in qs:
    opts = ", ".join(dq(o) for o in q['options'])
    lines += ["  {",
              f"    'id': {dq(q['id'])},",
              f"    'subject': {dq(q['subject'])},",
              f"    'question': {dq(q['question'])},",
              f"    'options': [{opts}],",
              f"    'answer': {q['answer']},",
              f"    'explanation': {dq(q['explanation'])},",
              "  },"]
lines.append("];")

open(OUT, 'w', encoding='utf-8').write("\n".join(lines) + "\n")

from collections import Counter
print(f"OK — {len(qs)} prashn -> lib/data/seed_questions.dart")
print("   ", dict(Counter(q['subject'] for q in qs)))
