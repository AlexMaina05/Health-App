import codecs
import re

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthCore/HealthKitBridge.swift', 'r', 'utf-8') as f:
    text = f.read()

# Remove HbA1c, Cholesterol, Triglycerides, Electrolytes, Vitamins
to_remove = [
    r'\s*"4548-4".*?\n', r'\s*"17856-6".*?\n', r'\s*"25428-4".*?\n', # HbA1c
    r'\s*"2093-3".*?\n', r'\s*"2085-9".*?\n', r'\s*"13457-7".*?\n', # Cholesterol
    r'\s*"2571-8".*?\n', # Trigliceridi
    r'\s*"2951-2".*?\n', r'\s*"2823-3".*?\n', r'\s*"17861-6".*?\n', # Electrolytes
    r'\s*"2498-4".*?\n', r'\s*"19123-9".*?\n', r'\s*"3236-8".*?\n',
    r'\s*"2128-1".*?\n', r'\s*"2777-1".*?\n',
    r'\s*"1649-3".*?\n', r'\s*"62238-1".*?\n', r'\s*"7085-4".*?\n', # Vitamins
    r'\s*"2132-9".*?\n', r'\s*"2275-6".*?\n', r'\s*"2274-9".*?\n'
]

for pat in to_remove:
    text = re.sub(pat, '\n', text)

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthCore/HealthKitBridge.swift', 'w', 'utf-8') as f:
    f.write(text)