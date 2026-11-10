# Proveniência dos dados

- Origem inicial: `~/.local/share/ryoku/plugins/emoji-ptbr/data/emojis.json`, versão declarada `emoji 17.0`, 3.944 sequências únicas. O arquivo foi copiado integralmente, sem scraping.
- Código/catalogação original: hypruser and contributors, MIT (aviso integral em LICENSE).
- Anotações: Unicode CLDR (português). O catálogo original cita https://www.unicode.org/license.txt. A composição original de palavras-chave também contém termos ingleses e sinônimos.
- Referência de experiência: https://emojipedia.org/pt. Sem associação à Emojipedia e sem uso de sua marca, arte ou descrições editoriais.
- Fontes: renderização pela fonte de emojis instalada no sistema. A aparência e a cobertura de emojis novos dependem dessa fonte.

O catálogo herdado não fixa a revisão CLDR que o gerou. A ferramenta original apontava para a branch main. Para uma futura atualização auditável, fixe releases de Unicode/CLDR e registre seus checksums antes de gerar a próxima versão. Esta versão preserva o snapshot incluído e testa sua integridade, sem alegar atualização automática.

Para revisão no catálogo público, o JSON foi reformatado com uma sequência por linha, sem alterar valores ou estrutura.

## Anotações localizadas em 0.4.0

`data/i18n/{pt,en,es,fr}.json` foi gerado a partir de annotations + annotationsDerived do repositório oficial Unicode CLDR JSON, revisão `7d2b9cb11cec08f4d333ad73209deb3df0711c3b`. A proveniência e os SHA-256 dos arquivos de origem estão em `data/i18n/source.json`. Cada idioma cobre 3.944/3.944 sequências do catálogo. Esses nomes e palavras-chave são distribuídos sob a licença Unicode, já incluída. A geração não usa serviços de tradução ou descrições editoriais da Emojipedia.
