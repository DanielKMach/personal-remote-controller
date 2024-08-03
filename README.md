# Personal Remote Controller

O Personal Remote Controller (Controle Remoto Pessoal) é um projeto que visa a criação de um controle remoto pessoal, que pode ser utilizado para controlar dispositivos ele de forma remota.

Ao executar este software, um servidor na rede local é iniciado, permitindo que qualquer pessoa conectada à rede local acesse o controle remoto através de um navegador web.

## Instalação

Atualmente, Windows é o único sistema operacional suportado. Para instalar o Personal Remote Controller, basta baixar o binário pré-compilado disponível na página de releases.

É recomendado que o binário seja armazenado em um diretório seguro e adicionado ao PATH do sistema.

## Uso

Para iniciar o servidor, basta executar o binário. O servidor será iniciado e o controle remoto estará disponível na porta `734`.

A seguinte imagem mostra o mapeamento dos botões do controle remoto:

![Controller](.github/readme/controller.png)

## Compilando a partir do código fonte

Para compilar o projeto, é necessário ter o [Zig](https://ziglang.org/) 0.13 instalado na máquina. Após a instalação, basta executar o seguinte comando:

```bash
zig build
```

O binário será gerado no diretório `zig-out/bin`.

Também é possível executar diretamente com o comando:

```bash
zig build run
```