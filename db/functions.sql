/*
This is the functions.sql file used by Squirm-Rails. Define your Postgres stored
procedures in this file and they will be loaded at the end of any calls to the
db:schema:load Rake task.
*/
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'place_match') THEN
        CREATE TYPE place_match AS (confidence integer, score real, id integer);
    END IF;
END$$;

CREATE OR REPLACE FUNCTION find_place(pname VARCHAR, pstreet VARCHAR, pstate VARCHAR, pzipcode VARCHAR) RETURNS setof place_match AS $$
DECLARE
    place_name VARCHAR;
    place_address VARCHAR;
    place_zip2 VARCHAR;
BEGIN
    place_name     := normalize_place_name(pname);
    place_address  := normalize_addresss(pstreet);
    place_zip2 := substr(pzipcode, 1, 2);
    return Query (
        -- High confidence level (10)
        SELECT 10 confidence, similarity(normalize_place_name(name), place_name) score, places.id FROM places 
        WHERE state=pstate AND 
              substr(lower(normalize_place_name(name)), 1, 5) = substr(lower(place_name), 1, 5) AND 
              substr(normalize_addresss(lower(COALESCE(street_number, '') || ' ' || COALESCE(route, ''))), 1, 5) = substr(lower(place_address), 1, 5) AND 
              zipcode = pzipcode
    UNION
        -- Medium confidence level (5)
        SELECT 5 confidence, similarity(normalize_place_name(name), place_name) score, places.id FROM places 
        WHERE state=pstate AND 
              normalize_place_name(name) % place_name AND 
              similarity(normalize_addresss(lower(COALESCE(street_number, '') || ' ' || COALESCE(route, ''))), place_address) >= 0.5 AND 
              substr(normalize_addresss(lower(COALESCE(street_number, '') || ' ' || COALESCE(route, ''))), 1, 5) = substr(lower(place_address), 1, 5) AND
              zipcode = pzipcode
    UNION
        -- Low confidence level (1)
        SELECT 1 confidence, similarity(normalize_place_name(name), place_name) score, places.id FROM places 
        WHERE similarity(normalize_place_name(name), place_name) >= 0.5 AND 
              similarity(normalize_addresss(lower(COALESCE(street_number, '') || ' ' || COALESCE(route, ''))), place_address) >= 0.4 AND 
              (place_zip2 IS NULL OR substr(zipcode, 1, 2) = place_zip2) 
    ORDER BY 1 DESC, 2 DESC
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION normalize_addresss(address VARCHAR) RETURNS VARCHAR IMMUTABLE AS $$
BEGIN
    address := regexp_replace(address, '(\s|,|^)(rd\.?)(\s|,|$)', '\1Road\3', 'ig');
    address := regexp_replace(address, '(\s|,|^)(st\.?)(\s|,|$)', '\1Street\3', 'ig');
    address := regexp_replace(address, '(\s|,|^)(ste\.?)(\s|,|$)', '\1Suite\3', 'ig');
    address := regexp_replace(address, '(\s|,|^)(av|ave\.?)(\s|,|$)', '\1Avenue\3', 'ig');
    address := regexp_replace(address, '(\s|,|^)(blvd\.?)(\s|,|$)', '\1Boulevard\3', 'ig');
    address := regexp_replace(address, '(\s|,|^)(fwy\.?)(\s|,|$)', '\1Freeway\3', 'ig');
    address := regexp_replace(address, '(\s|,|^)(hwy\.?)(\s|,|$)', '\1Highway\3', 'ig');

    address := regexp_replace(address, '(\s|,|^)(Road|Street|Avenue|Boulevard|Freeway|Highway\.?)(\s|,|$)', '\1\3', 'ig');

    address := regexp_replace(address, '(\s|,|^)(fifth\.?)(\s|,|$)', '\15th\3', 'ig');
    address := regexp_replace(address, '(\s|,|^)(dr\.?)(\s|,|$)', '\1Drive\3', 'ig');
    address := regexp_replace(address, '(\s|,|^)(w\.?)(\s|,|$)', '\1West\3', 'ig');
    address := regexp_replace(address, '(\s|,|^)(s\.?)(\s|,|$)', '\1South\3', 'ig');
    address := regexp_replace(address, '(\s|,|^)(e\.?)(\s|,|$)', '\1East\3', 'ig');
    address := regexp_replace(address, '(\s|,|^)(n\.?)(\s|,|$)', '\1North\3', 'ig');
    address := regexp_replace(address, '(\s|,|^)(ne\.?)(\s|,|$)', '\1Northeast\3', 'ig');
    address := regexp_replace(address, '(\s|,|^)(nw\.?)(\s|,|$)', '\1Northwest\3', 'ig');
    address := regexp_replace(address, '(\s|,|^)(se\.?)(\s|,|$)', '\1Southeast\3', 'ig');
    address := regexp_replace(address, '(\s|,|^)(sw\.?)(\s|,|$)', '\1Southwest\3', 'ig');
    address := regexp_replace(address, '(\s|,|^)(pkwy\.?)(\s|,|$)', '\1Parkway\3', 'ig');
    address := regexp_replace(address, '[\.,]+', '', 'ig');
    address := regexp_replace(address, '\s+', ' ', 'ig');
    RETURN trim(both ' ' from address);
END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION normalize_place_name(name VARCHAR) RETURNS VARCHAR IMMUTABLE AS $$
BEGIN
    name := regexp_replace(name, '^the\s+', '', 'ig');
    name := regexp_replace(name, '''', '', 'ig');
    RETURN trim(both ' ' from name);
END;
$$ LANGUAGE plpgsql;


DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'td_linx_result') THEN
        CREATE TYPE td_linx_result AS (code varchar, name varchar, street varchar, city varchar, state varchar, zipcode varchar, confidence integer);
    END IF;
END$$;

CREATE OR REPLACE FUNCTION incremental_place_match(place_id INTEGER, state_code VARCHAR) RETURNS td_linx_result AS $$
DECLARE
    place RECORD;
    td_place RECORD;
    place_name VARCHAR;
    place_address VARCHAR;
    place_address2 VARCHAR;
    place_zip2 VARCHAR;
BEGIN
    SELECT * INTO place FROM places where places.id=incremental_place_match.place_id;
    place_name := normalize_place_name(place.name);
    place_address := normalize_addresss(COALESCE(place.street_number, '') || ' ' || COALESCE(place.route, ''));
    place_address2 := normalize_addresss(COALESCE(place.formatted_address, ''));
    place_zip2 := substr(place.zipcode, 1, 2);
    FOR td_place IN SELECT tdlinx_codes.*, 10 FROM tdlinx_codes WHERE state=state_code AND substr(lower(normalize_place_name(name)), 1, 5) = substr(lower(place_name), 1, 5) AND (substr(lower(street), 1, 5) = substr(lower(place_address), 1, 5) OR substr(lower(street), 1, 5) = substr(lower(place_address2), 1, 5)) AND zipcode = place.zipcode ORDER BY similarity(name, place_name) LOOP
        return td_place;
    END LOOP;

    FOR td_place IN SELECT tdlinx_codes.*, 5 FROM tdlinx_codes WHERE state=state_code AND normalize_place_name(name) % place_name AND (similarity(street, place_address) >= 0.5 AND (substr(lower(street), 1, 5) = substr(lower(place_address), 1, 5) OR substr(lower(street), 1, 5) = substr(lower(place_address2), 1, 5)) ) AND zipcode = place.zipcode ORDER BY similarity(name, place_name) LOOP
        return td_place;
    END LOOP;

    FOR td_place IN SELECT tdlinx_codes.*, 1 FROM tdlinx_codes WHERE similarity(normalize_place_name(name), place_name) >= 0.5 AND similarity(street, place_address) >= 0.4 AND (place_zip2 IS NULL OR substr(zipcode, 1, 2) = place_zip2) ORDER BY similarity(name, place_name) DESC LOOP
        return td_place;
    END LOOP;

    return null;
END;
$$ LANGUAGE plpgsql;

