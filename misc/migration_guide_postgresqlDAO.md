find -name "*.jl" -exec sed -i "s/PostgresqlDAO/PostgresORM/g" {} +
find -name "*.jl" -exec sed -i "s/DAO/ORM/g" {} +
find -name "*.jl" -exec sed -i "s/dao/orm/g" {} +
find -name "*.jl" -exec sed -i "s/getorm/get_orm/g" {} +
