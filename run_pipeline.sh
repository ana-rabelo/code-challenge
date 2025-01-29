#!/bin/bash
set -e  

export CSV_OUTPUT_PATH="northwind-meltano/data/postgres/$(date +%Y-%m-%d)"
export CSV_DETAILS_OUTPUT_PATH="northwind-meltano/data/csv/$(date +%Y-%m-%d)"

mkdir -p "$CSV_OUTPUT_PATH"
mkdir -p "$CSV_DETAILS_OUTPUT_PATH"

if ! meltano run tap-postgres target-csv 2>&1 | tee -a $LOG_FILE; then
    echo "Erro na execução da pipeline! Veja detalhes em $LOG_FILE" | tee -a $LOG_FILE
    exit 1
fi

echo "Pipeline finalizada. Arquivos do banco de dados Postgres salvos em $CSV_OUTPUT_PATH"

if ! meltano run tap-csv-details target-csv-details 2>&1 | tee -a $LOG_FILE; then
    echo "Erro na execução da pipeline! Veja detalhes em $LOG_FILE" | tee -a $LOG_FILE
    exit 1
fi

echo "Pipeline finalizada. Arquivos do arquivo .csv salvos em $CSV_DETAILS_OUTPUT_PATH"

if ! meltano run tap-csv target-postgres 2>&1 | tee -a $LOG_FILE; then
    echo "Erro na execução da pipeline! Veja detalhes em $LOG_FILE" | tee -a $LOG_FILE
    exit 1
fi

echo "Pipeline finalizada. Arquivos salvos no banco de dados Posgres"


echo "Pipeline concluída com sucesso em $(date)" | tee -a $LOG_FILE

echo "Validando execução da pipeline..." | tee -a $LOG_FILE
PGPASSWORD=cd2153 psql -h localhost -U postgres -d northwind-target -c "
    select p.product_name, count(od.quantity) AS total_do_produto
    from products p join order_details od on p.product_id = od.product_id
    group by p.product_name
    order by total_do_produto desc;
" | tee -a $LOG_FILE