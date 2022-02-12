#!/usr/bin/env bash
# MIT License

# Copyright (c) 2020 Enderson Tadeu Salgueiro Maia

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -eo pipefail
[[ $TRACE ]] && set -x

# https://servicodados.ibge.gov.br/api/docs/cnae?versao=2

get_cnaes() {
    echo "Baixando CNAEs do IBGE..."

    curl -sSL https://servicodados.ibge.gov.br/api/v2/cnae/subclasses > "$CNAE_JSON_TMP"
}

load_cnaes() {
    #TODO - importar campos de observações
    echo "Ingerindo dados para tratamento..."

    cat "$CNAE_JSON_TMP" \
        | jq -cr '[.[] | {subclasse_id: .id, subclasse_descricao: .descricao, classe_id: .classe.id, classe_descricao: .classe.descricao, grupo_id: .classe.grupo.id, grupo_descricao: .classe.grupo.descricao, divisao_id: .classe.grupo.divisao.id, divisao_descricao: .classe.grupo.divisao.descricao, secao_id: .classe.grupo.divisao.secao.id, secao_descricao: .classe.grupo.divisao.secao.descricao} ] | (map(keys) | add | unique) as $cols | map(. as $row | $cols | map($row[.])) as $rows | $cols, $rows[] | @csv' \
        | sqlite3 -csv -header "$DB_FILE" ".import /dev/stdin _cnaes"
}

load_secoes() {
    echo "Criando tabela cnae_secoes..."

    cat <<EOF | sqlite3 "$DB_FILE"
    DROP TABLE IF EXISTS cnae_secoes;
    CREATE TABLE IF NOT EXISTS cnae_secoes (
        id          CHAR(1) PRIMARY KEY NOT NULL, 
        descricao   TEXT NOT NULL
    );
    INSERT INTO cnae_secoes (id, descricao)
    SELECT DISTINCT secao_id, secao_descricao
    FROM _cnaes;
EOF
}

load_divisoes() {
    echo "Criando tabela cnae_divisoes..."

    cat <<EOF | sqlite3 "$DB_FILE"
    DROP TABLE IF EXISTS cnae_divisoes;
    CREATE TABLE IF NOT EXISTS cnae_divisoes (
        id          CHAR(2) PRIMARY KEY NOT NULL,
        descricao   TEXT NOT NULL,
        secao_id    CHAR(1) NOT NULL,
        FOREIGN KEY(secao_id) REFERENCES cnae_secoes(id)
    );
    CREATE INDEX divisoes_secao_id_index ON cnae_divisoes(secao_id);
    INSERT INTO cnae_divisoes (id, descricao, secao_id)
    SELECT DISTINCT divisao_id, divisao_descricao, secao_id
    FROM _cnaes;
EOF
}

load_grupos() {
    echo "Criando tabela cnae_grupos..."

    cat <<EOF | sqlite3 "$DB_FILE"
    DROP TABLE IF EXISTS cnae_grupos;
    CREATE TABLE IF NOT EXISTS cnae_grupos (
        id          CHAR(2) PRIMARY KEY NOT NULL,
        descricao   TEXT NOT NULL,
        divisao_id  CHAR(2) NOT NULL,
        secao_id    CHAR(1) NOT NULL,
        FOREIGN KEY (divisao_id) REFERENCES cnae_divisoes (id),
        FOREIGN KEY (secao_id) REFERENCES cnae_secoes (id)
    );
    CREATE INDEX grupos_divisao_id_index ON cnae_grupos(divisao_id);
    CREATE INDEX grupos_secao_id_index ON cnae_grupos(secao_id);
    INSERT INTO cnae_grupos (id, descricao, divisao_id, secao_id)
    SELECT DISTINCT grupo_id, grupo_descricao, divisao_id, secao_id
    FROM _cnaes
EOF
}

load_classes() {
    echo "Criando tabela cnae_classes..."

    cat <<EOF | sqlite3 "$DB_FILE"
    DROP TABLE IF EXISTS cnae_classes;
    CREATE TABLE IF NOT EXISTS cnae_classes (
        id          CHAR(5) PRIMARY KEY NOT NULL,
        descricao   TEXT NOT NULL,
        grupo_id    CHAR(2) NOT NULL,
        divisao_id  CHAR(2) NOT NULL,
        secao_id    CHAR(1) NOT NULL,
        FOREIGN KEY (grupo_id) REFERENCES cnae_grupos (id),
        FOREIGN KEY (divisao_id) REFERENCES cnae_divisoes (id),
        FOREIGN KEY (secao_id) REFERENCES cnae_secoes (id)
    );
    CREATE INDEX classes_grupo_id_index ON cnae_classes(grupo_id);
    CREATE INDEX classes_divisao_id_index ON cnae_classes(divisao_id);
    CREATE INDEX classes_secao_id_index ON cnae_classes(secao_id);
    INSERT INTO cnae_classes (id, descricao, grupo_id, divisao_id, secao_id)
    SELECT DISTINCT classe_id, classe_descricao, grupo_id, divisao_id, secao_id
    FROM _cnaes;
EOF
}

load_subclasses() {
    echo "Criando tabela cnae_subclasses..."

    cat <<EOF | sqlite3 "$DB_FILE"
    DROP TABLE IF EXISTS cnae_subclasses;
    CREATE TABLE IF NOT EXISTS cnae_subclasses (
        id          CHAR(7) PRIMARY KEY NOT NULL,
        descricao   TEXT NOT NULL,
        classe_id   CHAR(5) NOT NULL,
        grupo_id    CHAR(2) NOT NULL,
        divisao_id  CHAR(2) NOT NULL,
        secao_id    CHAR(1) NOT NULL,
        FOREIGN KEY (grupo_id) REFERENCES cnae_grupos (id),
        FOREIGN KEY (divisao_id) REFERENCES cnae_divisoes (id),
        FOREIGN KEY (secao_id) REFERENCES cnae_secoes (id),
        FOREIGN KEY (classe_id) REFERENCES cnae_secoes (id)
    );
    CREATE INDEX subclasses_grupo_id_index ON cnae_subclasses(grupo_id);
    CREATE INDEX subclasses_divisao_id_index ON cnae_subclasses(divisao_id);
    CREATE INDEX subclasses_secao_id_index ON cnae_subclasses(secao_id);
    CREATE INDEX subclasses_classe_id_index ON cnae_subclasses(classe_id);
    INSERT INTO cnae_subclasses (id, descricao, classe_id, grupo_id, divisao_id, secao_id)
    SELECT DISTINCT subclasse_id, subclasse_descricao, classe_id, grupo_id, divisao_id, secao_id
    FROM _cnaes;
EOF
}

clean_db(){
    sqlite3 "$DB_FILE" "DROP TABLE _cnaes;"
    sqlite3 "$DB_FILE" "VACUUM;"
}

main() {
    trap 'rm -f "$TMPFILE"' EXIT
    CNAE_JSON_TMP=$(mktemp) || exit 1

    DB_FILE="cnae.sqlite"

    get_cnaes
    load_cnaes
    load_secoes
    load_divisoes
    load_grupos
    load_classes
    load_subclasses
    clean_db
}

main "$@"