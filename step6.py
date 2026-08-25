import codecs

filepath = 'e:/Code/Health-App/README.md'
with codecs.open(filepath, 'r', 'utf-8') as f:
    content = f.read()

# Add to index
content = content.replace('- [Documentazione di Progetto](#-documentazione-di-progetto)', '- [Documentazione di Progetto](#-documentazione-di-progetto)\n- [Guida Utente](#-guida-utente)')
content = content.replace('- 📄 [**Sviluppi Futuri e Roadmap**](Sviluppi_Futuri.md): La vision di prodotto per le versioni future (v4.0+), inclusa l\'integrazione di Small Language Models locali e cruscotti olistici proprietari.', '- 📄 [**Sviluppi Futuri e Roadmap**](Sviluppi_Futuri.md): La vision di prodotto per le versioni future (v4.0+), inclusa l\'integrazione di Small Language Models locali e cruscotti olistici proprietari.\n- 📘 [**Guida Utente**](GUIDA_UTENTE.md): Manuale d\'uso ufficiale per i pazienti, dall\'installazione all\'importazione dei PDF.')

with codecs.open(filepath, 'w', 'utf-8') as f:
    f.write(content)