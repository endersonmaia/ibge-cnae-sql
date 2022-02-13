# IBGE CNAE - Cadastro Nacional de Atividade Economica

Este projeto utiliza a API do IBGE para gerar uma base de dados com o cadastro dos CNAE em formato SQL.

- [IBGE CNAE - Cadastro Nacional de Atividade Economica](#ibge-cnae---cadastro-nacional-de-atividade-economica)
  - [Carregando banco de dados](#carregando-banco-de-dados)
  - [Tabelas](#tabelas)
    - [Seções](#seções)
    - [Divisões](#divisões)
    - [Grupos](#grupos)
    - [Classes](#classes)
    - [Subclasses](#subclasses)
  - [Licença](#licença)

## Carregando banco de dados

Você precisará dos programas `curl`, `sqlite` e `jq`.

Baixe este repositório, e execute o script `./load-cnae.sh`.

Segue uma consulta de teste :

```shell
$ cat<<EOF | sqlite3 -csv cnae.sqlite
    SELECT cnae_subclasses.id, cnae_subclasses.descricao, cnae_secoes.descricao
    FROM cnae_subclasses
    JOIN cnae_secoes ON (cnae_secoes.id = cnae_subclasses.secao_id)
    WHERE cnae_secoes.id = 'A'
EOF
0111301,"CULTIVO DE ARROZ","AGRICULTURA, PECUÁRIA, PRODUÇÃO FLORESTAL, PESCA E AQÜICULTURA"
0111302,"CULTIVO DE MILHO","AGRICULTURA, PECUÁRIA, PRODUÇÃO FLORESTAL, PESCA E AQÜICULTURA"
0111303,"CULTIVO DE TRIGO","AGRICULTURA, PECUÁRIA, PRODUÇÃO FLORESTAL, PESCA E AQÜICULTURA"
0111399,"CULTIVO DE OUTROS CEREAIS NÃO ESPECIFICADOS ANTERIORMENTE","AGRICULTURA, PECUÁRIA, PRODUÇÃO FLORESTAL, PESCA E AQÜICULTURA"
0112101,"CULTIVO DE ALGODÃO HERBÁCEO","AGRICULTURA, PECUÁRIA, PRODUÇÃO FLORESTAL, PESCA E AQÜICULTURA"
```

## Tabelas

A hierarquia do CNAE é Seção > Divisão -> Grupo -> Classe -> Subclasse.

Ex.:

```
Seção       A               Agricultura, pecuária, produção florestal, pesca e aqüicultura
Divisão     01              Agricultura, pecuária e serviços relacionados
Grupo       01.1            Produção de lavouras temporárias
Classe      01.11-3         Cultivo de cereais
Subclasse   0111-3/01       Cultivo de arroz
```

### Seções

- `cnae_secoes`

```
campo       tipo
----        ----
id          CHAR(1)
descricao   TEXT
```

### Divisões

- `cnae_divisoes`

```
campo       tipo
-----       ----
id          CHAR(2)
descricao   TEXT
secao_id    CHAR(1)
```

### Grupos

- `cnae_grupos`

```
campo       tipo
----        ----
id          CHAR(2)
descricao   TEXT
divisao_id  CHAR(2)
secao_id    CHAR(1)
```

### Classes

- `cnae_classes`

```
campo       tipo
----        ----
id          CHAR(5)
descricao   TEXT
grupo_id    CHAR(2)
divisao_id  CHAR(2)
secao_id    CHAR(1)
```

### Subclasses

- `cnae_subclasses`

```
campo       tipo
----        ----
id          CHAR(5)
descricao   TEXT
classe_id   CHAR(5)
grupo_id    CHAR(2)
divisao_id  CHAR(2)
secao_id    CHAR(1)
```

## Licença

O código fonte deste projeto é [MIT License](LICENSE), Copyright (c) 2020-2022 Enderson Tadeu Salgueiro Maia.

Os dados são obtivos através da [API do IBGE](https://servicodados.ibge.gov.br/api/docs/cnae?versao=2).
