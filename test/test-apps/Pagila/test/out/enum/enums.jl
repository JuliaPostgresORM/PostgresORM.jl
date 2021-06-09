module Year
  export YEAR
  @enum YEAR begin
  end
end

module MpaaRating
  export MPAA_RATING
  @enum MPAA_RATING begin
    g = 1
    pg = 2
    pg_13 = 3 
    r = 4
    nc_17 = 5
    pg13 = 6
    nc17 = 7
  end
end
