#!/usr/bin/env bash
# MIT License

# Copyright (c) 2020-2022 Enderson Tadeu Salgueiro Maia

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

################################################################################
# Seções
build_secoes() {
    printf "Construindo arquivo %s ...\n" "$API_BASE_PATH"/secoes.json

    jq -c '[.[].classe.grupo.divisao.secao] | unique_by(.id)' "$JSON_FILE" \
        > "$API_BASE_PATH"/secoes.json
}
#TODO: secao por id ex.: `secoes/A.json``

################################################################################
# Divisões
build_divisoes() {
    printf "Construindo arquivo %s ...\n" "$API_BASE_PATH"/divisoes.json

    jq -c '[.[].classe.grupo.divisao] | unique_by(.id)' "$JSON_FILE" \
        > "$API_BASE_PATH"/divisoes.json

    jq -r '.[].id' "$API_BASE_PATH"/secoes.json \
        | xargs -I % /bin/bash -c 'build_divisoes_por_secao "$@"' _ %
}
#TODO: divisoes por id ex.: `divisoes/01.json`

# Recebe uma seçãoo e constrói arquivos de divisões para cada seção
build_divisoes_por_secao() {
    local secao_id=$1; shift

    printf "Criando diretorio para seção %s...\n" "$secao_id"
    mkdir -p "$API_BASE_PATH"/secoes/"$secao_id"

    #TODO: extract sed to a file and remove duplicates
    printf "Criando arquivo de divisões da seção %s...\n" "$secao_id"
    jq -c '.[] | select(.secao.id == "'${secao_id}'")' "$API_BASE_PATH"/divisoes.json \
        | sed '1s/^/[/; $!s/$/,/; $s/$/]/' \
        | sed ':a;$!{N;s/\n/ /;ba;}' \
        > "$API_BASE_PATH"/secoes/${secao_id}/divisoes.json
}
export -f build_divisoes_por_secao

################################################################################
# Grupos
build_grupos() {
    printf "Construindo arquivo %s ...\n" "$API_BASE_PATH"/grupos.json

    jq -c '[.[].classe.grupo] | unique_by(.id)' "$JSON_FILE" \
        > "$API_BASE_PATH"/grupos.json

    jq -r '.[].id' "$API_BASE_PATH"/divisoes.json \
        | xargs -I % /bin/bash -c 'build_grupos_por_divisao "$@"' _ %

    jq -r '.[].id' "$API_BASE_PATH"/secoes.json \
        | xargs -I % /bin/bash -c 'build_grupos_por_secao "$@"' _ %
}
#TODO: grupos por id ex.: `grupos/011.json`

# Recebe uma divisão e contrói arquivos de grupos para cada divisão
build_grupos_por_divisao() {
    local divisao_id=$1; shift

    printf "Criando diretorio para divisão %s...\n" "$divisao_id"
    mkdir -p "$API_BASE_PATH"/divisoes/"$divisao_id"

    printf "Criando arquivo de grupos para divisão %s...\n" "$divisao_id"
    jq -c '.[] | select(.divisao.id == "'${divisao_id}'")' "$API_BASE_PATH"/grupos.json \
        | sed '1s/^/[/; $!s/$/,/; $s/$/]/' \
        | sed ':a;$!{N;s/\n/ /;ba;}' \
        > "$API_BASE_PATH"/divisoes/${divisao_id}/grupos.json
}
export -f build_grupos_por_divisao

# Recebe uma seção e contrói arquivos de grupos para cada seção
build_grupos_por_secao() {
    local secao_id=$1; shift

    printf "Criando diretorio para seção %s...\n" "$secao_id"
    mkdir -p "$API_BASE_PATH"/secoes/"$secao_id"

    printf "Criando arquivo de grupos da seção %s ...\n" "$secao_id"
    jq -c '.[] | select(.divisao.secao.id == "'${secao_id}'")' "$API_BASE_PATH"/grupos.json \
        | sed '1s/^/[/; $!s/$/,/; $s/$/]/' \
        | sed ':a;$!{N;s/\n/ /;ba;}' \
        > "$API_BASE_PATH"/secoes/${secao_id}/grupos.json
}
export -f build_grupos_por_secao

################################################################################
# Classes
build_classes() {
    printf "Construindo arquivo %s ...\n" "$API_BASE_PATH"/classes.json

    jq -c '[.[].classe] | unique_by(.id)' "$JSON_FILE" > "$API_BASE_PATH"/classes.json
}
# TODO: classes por id ex.: `classes/01121.json`
# TODO: classes por divisão 
# TODO: classes por grupo
# TODO: classes por seção

main() {
    export DB_FILE="data/cnae.sqlite"
    export JSON_FILE="data/cnae.json"
    export API_BASE_PATH="api/v2/cnae"

    mkdir -p "$API_BASE_PATH"/{classes,divisoes,grupos,secoes,subclasses}

    build_secoes
    build_divisoes
    build_grupos
    build_classes
}

main "$@"
