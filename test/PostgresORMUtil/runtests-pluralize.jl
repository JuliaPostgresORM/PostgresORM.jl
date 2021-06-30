@testset "Test function `pluralize_eng`" begin
    PostgresORMUtil.pluralize("analysis","eng")
    PostgresORMUtil.pluralize("analyse","fra")
    PostgresORMUtil.pluralize("bateau","fra")
end
