reset-docker() {
    docker compose down
    sudo rm -Rf citus-db-data
    sudo rm -Rf citus-healthcheck
    docker volume prune --all
    docker compose up -d
}

docker compose up -d

if [ ! -d .venv ]
then
    python -m venv .venv
fi

source .venv/bin/activate

pip install -r requirements.txt

export DBT_PROFILES_DIR=$(pwd)/dbt-profiles

cd my_project