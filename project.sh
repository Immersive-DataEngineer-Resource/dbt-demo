if [ ! -d .venv ]
then
    python -m venv .venv
fi

source .venv/bin/activate

pip install -r requirements.txt

export DBT_PROFILES_DIR=$(pwd)/dbt-profiles

cd my_project