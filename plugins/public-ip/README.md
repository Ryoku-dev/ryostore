# IP Pública

Ryoku shell plugin (`public-ip`): muestra la IP pública actual en la barra y,
al hacer clic, la copia al portapapeles.

## Qué hace

- **Servicio** (`service/Main.qml`): sondea `bin/poll.sh` cada `pollSeconds`
  segundos (por defecto 60) y guarda la última lectura.
- **Widget** (`content/Widget.qml`): muestra la IP (o `...`/`sin IP` mientras
  no hay lectura). Un clic izquierdo llama a `bin/copy.sh` con la IP y
  muestra brevemente «¡Copiada!». No abre ningún panel: es la única acción.

## Qué lee y qué escribe

- **Red**: `bin/poll.sh` hace `curl` a `https://checkip.amazonaws.com/`
  (único host, declarado en `capabilities.network`) y no envía nada más que
  la petición GET estándar. No hay backend propio ni telemetría.
- **Portapapeles**: `bin/copy.sh` recibe la IP como argumento (`argv`, nunca
  interpolada en una cadena de shell) y la pasa a `wl-copy`. No escribe en
  disco ni en ningún otro sitio.
- No hay credenciales, tokens ni acciones privilegiadas.

## Ajustes

| key         | type | default | description                  |
| ----------- | ---- | ------- | ----------------------------- |
| pollSeconds | int  | 60      | Intervalo de refresco (segundos) |

## Preview

Falta capturar `assets/preview-widget.png` y listarla en `manifest.json` si
se quiere publicar en la store.

## Build, check, install

```
ryoku plugin validate .
ryoku plugin add . --bar --yes
```

Aparece en la barra y bajo **QS Bar Settings > Community**.

## Autor

vampirejsv <vampirejsv@local>: plugin comunitario (`official` es false).
