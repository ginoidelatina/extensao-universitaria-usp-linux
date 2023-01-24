#!/bin/bash

function nova_tarefa { # adiciona uma tarefa par a agenda
    REGEX_DATA="([0-9]{1,2})\/([0-9]{1,2})\/([0-9]{4})"

    while true; do # loop para requisitar a data da tarefa
        read -p "Data (dd/mm/aaaa): " DATA_TAREFA
        if [[ $DATA_TAREFA =~ $REGEX_DATA ]]
        then
            DATA_ATUAL=$(date +%s -d "today 0")
            DATA_FORMATO_PADRAO=$(echo $DATA_TAREFA | sed -E "s/$REGEX_DATA/\3-\2-\1/")
            DATA_ENTRADA=$(date +%s -d $DATA_FORMATO_PADRAO 2> /dev/null)
            if [[ $? -eq 0 ]]; then
                if [[ $DATA_ENTRADA -ge $DATA_ATUAL ]]; then
                    break
                else
                    echo "A data selecionada deve estar no futuro!"
                fi
            else
                echo "Data inválida"
            fi
        fi
    done

    while true; do # loop para requisitar a hora da tarefa
        read -p "Hora (hh:mm): " HORA_TAREFA
        date "+%R" -d "$HORA_TAREFA" > /dev/null  2>&1
        if [[ $? -eq 0 ]]; then
            DATA_ENTRADA=$(date +%s -d "$DATA_FORMATO_PADRAO $HORA_TAREFA")
            DATA_ATUAL=$(date +%s)
            if [[ $DATA_ENTRADA -ge $DATA_ATUAL ]]; then
                break
            else
                echo "A hora selecionada deve estar no futuro!"
            fi
        else
            echo "Hora inválida!"
        fi
    done

    while true; do # loop para requisitar a descrição da tarefa
        read -p "Descrição (min. 10 caracteres): " DESCRICAO_TAREFA
        # removendo ponto-e-virgula (pois é usado para separar campos no arquivo)
        DESCRICAO_TAREFA=$(echo $DESCRICAO_TAREFA | sed -r 's/\;//')
        if [[ ${#DESCRICAO_TAREFA} -ge 10 ]]; then
            break
        else
            echo "A descrição deve ter um mínimo de 10 caracteres!"
        fi
    done

    # salvando a tarefa na agenda
    DIR_APP="$HOME/.agenda"
    ARQUIVO_TAREFAS="$DIR_APP/tarefas.ssv"
    # criando diretorio se ainda não existir
    [[ ! -d $DIR_APP ]] && mkdir -p $DIR_APP
    echo "$DATA_ENTRADA;$DATA_TAREFA $HORA_TAREFA;$DESCRICAO_TAREFA" >> $ARQUIVO_TAREFAS

    # Ordenando o arquivo de tarefas
    ARQ_TEMPORARIO="/tmp/agenda_$(date +%s)"
    sort --field-separator=';' --key=1 $ARQUIVO_TAREFAS > $ARQ_TEMPORARIO
    rm $ARQUIVO_TAREFAS
    mv $ARQ_TEMPORARIO $ARQUIVO_TAREFAS
}

function formatar_tarefa {
    LINHA=$1
    DATA_TAREFA=$(echo $LINHA | cut -d ";" -f 2)
    DESC_TAREFA=$(echo $LINHA | cut -d ";" -f 3)
    printf "|------------------------------------------|\n"
    printf "|Data:   $DATA_TAREFA\n|Tarefa: $DESC_TAREFA\n"
    printf "|------------------------------------------|\n"
}

function obter_tarefas_periodo {
    DATA_INICIAL=$1
    DATA_FINAL=$2
    DIR_APP="$HOME/.agenda"
    ARQUIVO_TAREFAS="$DIR_APP/tarefas.ssv"
    [[ ! -d $DIR_APP ]] && mkdir -p $DIR_APP
    #criando arquivo das tarefas se ainda não existir
    [[ ! -f $ARQUIVO_TAREFAS ]] && touch $ARQUIVO_TAREFAS
    
    while IFS='' read -r LINE || [ -n "${LINE}" ]; do
        DATA_TAREFA=$(echo $LINE | cut -d ";" -f 1)
        if [[ $DATA_TAREFA -ge $DATA_INICIAL && $DATA_TAREFA -le $DATA_FINAL ]]; then
            formatar_tarefa "$LINE"
        fi
    done <  $ARQUIVO_TAREFAS
}

function inicializa_agenda_com_tarefas_exemplo {
    DIR_APP="$HOME/.agenda"
    ARQUIVO_TAREFAS="$DIR_APP/tarefas.ssv"
    rm $ARQUIVO_TAREFAS 2> /dev/null
    touch $ARQUIVO_TAREFAS
    [[ ! -d $DIR_APP ]] && mkdir -p $DIR_APP
    INC=0
    MIN=0
    for NRO in $(seq 100); do
        (( INC += ( RANDOM % 4 )  + 1 ))
        (( MIN = ( RANDOM % 59 )  + 1 ))
        DATA=$(date "+%s" -d "yesterday 0 -1 day +$INC hour +$MIN minutes")
        DESC="Tarefa agendada de exemplo #$NRO"
        echo "$DATA;$(date '+%d/%m/%Y %R' -d @$DATA);$DESC" >> $ARQUIVO_TAREFAS
    done
}

function ajuda {
cat << EOT
Uso: ./tarefa.sh [Opções]
Opções:
    -n, --nova-tarefa     Cadastrar nova tarefa (interativo)
    -po, --para-ontem     Listar tarefas agendadas para ontem
    -ph, --para-hoje      Listar tarefas agendadas para hoje
    -pa, --para-amanha    Listar tarefas agendadas para amanhã
    -ps, --para-semana    Listar tarefas agendadas para esta semana
    -pm, --para-mes       Listar tarefas agendadas para este mês
    --preencher-agenda    Preenche agenda com tarefas de exemplo
                          (***Atenção: apaga toda agenda!!!***)
    -h, --help            Este texto de ajuda
EOT
}

case "$1" in
    -n | --nova-tarefa)
        nova_tarefa
        exit 0
        ;;
    -po | --para-ontem) # ;)
        DT_INI=$(date +%s -d "yesterday 0")
        DT_FIM=$(date +%s -d "today 0 -1second")
        obter_tarefas_periodo $DT_INI $DT_FIM
        exit 0
        ;;
    -ph | --para-hoje) # da hora atual até o final do dia
        DT_INI=$(date +%s)
        DT_FIM=$(date +%s -d "tomorrow 0 -1second")
        obter_tarefas_periodo $DT_INI $DT_FIM
        exit 0
        ;;
    -pa | --para-amanha) # para amanhã (dia inteiro)
        DT_INI=$(date +%s -d "tomorrow 0")
        DT_FIM=$(date +%s -d "tomorrow +1day 0 -1second")
        obter_tarefas_periodo $DT_INI $DT_FIM
        exit 0
        ;;
    -ps | --para-semana) # da hora atual até o final do sábado
        DT_INI=$(date +%s)
        DT_FIM=$(date +%s -d "next saturday last second")
        obter_tarefas_periodo $DT_INI $DT_FIM
        exit 0
        ;;
    -pm | --para-mes) # da hora atual até o final do último dia do mês
        DT_INI=$(date +%s)
        DT_FIM=$(date +%s -d "$(date +%Y-%m-01) +1 month -1 second")
        obter_tarefas_periodo $DT_INI $DT_FIM
        exit 0
        ;;
    --preencher-agenda) # preenche a agenda com tarefas de exemplo
        inicializa_agenda_com_tarefas_exemplo
        exit 0
        ;;
    -h | --help | *)
        ajuda
        exit 0
        ;;
esac