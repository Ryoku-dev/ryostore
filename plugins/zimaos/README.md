# ZimaOS

Plugin da QS Bar para um servidor ZimaOS. O ícone na barra é o nome ZIMA, num tom só, igual aos outros glifos, e abre o painel. Antes de entrar, o painel pede o endereço, o usuário e a senha. Depois de entrar, mostra o cartão do aparelho.

## O que aparece

Antes do login: **IP**, **Usuário** e **Senha**, e o botão **Entrar**. O IP fica preenchido quando já existe um endereço salvo. O exemplo do campo é só um placeholder.

Depois do login, no ZimaOS 1.8:

- Nome do aparelho, versão e modelo, lidos de `GET /v2/zimaos/device/info`. A foto do aparelho vem de `device_image` nesse mesmo JSON e é baixada de `/v2/zimaos/device/image?model=…&type=client`. O PNG fica em `$XDG_STATE_HOME/ryoku/plugins/zimaos/device.png` e só é baixado de novo quando o modelo muda.
- Interface e endereço IPv4 do caminho em uso (`GET /v2/zimaos/network/connection-status`). Os quatro ícones ao lado de LAN são remoto, Wi-Fi, Ethernet e Thunderbolt: o acento marca o caminho em uso, o tom claro marca um caminho disponível, e o tom apagado marca o que está desligado.
- Atalho **Ir ao painel** para a página inicial do servidor.
- Atalho **Abrir** o armazenamento (`/modules/icewhale_files/`), com o espaço livre do maior volume. O nome do volume só aparece depois do login.
- **Backup**, quando o app grid devolve um link; senão abre o painel.
- **PeerDrop** abre o módulo do servidor em `/modules/icewhale_peerdrop/`.
- **Sair** volta à mesma tela de entrar, com o IP salvo preenchido e a senha vazia.
- O cartão usa a superfície da própria barra: a mesma borda e o mesmo vidro do painel de música. Os blocos de dentro são um escurecimento leve, não uma placa opaca.

## O que corre, lê e escreve

- `bin/zima` (Python 3, biblioteca padrão). Um IP ou nome da rede local, sem esquema, continua em HTTP (por exemplo `192.168.0.180`). `http://` é o mesmo. `https://` usa HTTPS e verifica o certificado; a verificação não é desligada. Recusa caminho, `@` e qualquer outro esquema. Não segue redirecionamentos, para o token não ir para outro host.
- Caminhos: `POST /v1/users/login`, `POST /v1/users/refresh`, `GET /v1/sys/utilization`, `GET /v2/zimaos/network/interfaces`, `GET /v2/zimaos/network/connection-status`, `GET /v2/local_storage/storages`, `GET /v2/app_management/web/appgrid` e o device info acima.
- `xdg-open`, só quando você clica num atalho.
- O endereço é gravado com `pluginApi.saveSetting` na chave `host`. A senha não é gravada nem registrada.
- A sessão (usuário e tokens) fica em `$XDG_STATE_HOME/ryoku/plugins/zimaos/session.json`, modo `0600`. A foto do aparelho fica ao lado, em `device.png`.

Não há comando privilegiado. Não há host fixo em `capabilities.network`: o validador do Ryoku só exige essa lista para endereços `http://` ou `https://` escritos no código, e este plugin não tem nenhum. O servidor é o que a pessoa digita.

## Instalar

Outra pessoa com Ryoku copia esta pasta e roda, dentro dela:

```
ryoku plugin validate .
ryoku plugin add . --bar --yes
```

O glifo entra na barra. Abra o painel, informe o IP do ZimaOS, o usuário e a senha, e toque em **Entrar**. O mesmo plugin fica em **QS Bar Settings → Community**.
