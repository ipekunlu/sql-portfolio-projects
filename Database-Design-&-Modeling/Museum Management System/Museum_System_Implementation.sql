/* 
Project: Museum Management System
Purpose: Creates schema and tables for the museum management database.
Note: Database creation is optional and commented out for portability.
*/

--------------------- TABLE CREATION ---------------------

-- Optional (local use only):
-- CREATE DATABASE museum_db_museum;

-- Assumption: database already exists; this script creates schema and tables.

-- DROP SCHEMA IF EXISTS museum_mgmt CASCADE;
-- CREATE SCHEMA museum_mgmt;


SET search_path TO museum_mgmt;
--1. MUSEUM_ITEM TABLE
CREATE TABLE museum_item (
    item_id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    accession_code   VARCHAR(30)  NOT NULL UNIQUE,
    title            VARCHAR(200) NOT NULL,
    item_type        VARCHAR(50),
    category         VARCHAR(50),
    description      TEXT,
    creation_year    SMALLINT,
    origin_country   VARCHAR(100),
    acquisition_date DATE,
    insurance_value  NUMERIC(12,2) DEFAULT 0, 
    is_on_display    BOOLEAN       DEFAULT FALSE
);

COMMENT ON TABLE museum_item IS 'All collection objects in the museum';
COMMENT ON COLUMN museum_item.accession_code IS 'Internal museum inventory code';

--2. EMPLOYEE TABLE
CREATE TABLE employee (
    employee_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_no   VARCHAR(20)  NOT NULL UNIQUE,
    first_name    VARCHAR(100) NOT NULL,
    last_name     VARCHAR(100) NOT NULL,
    role          VARCHAR(50),
    hire_date     DATE,
    email         VARCHAR(150),
    phone         VARCHAR(30),
    is_active     BOOLEAN      DEFAULT TRUE,
    full_name TEXT GENERATED ALWAYS AS (
    first_name || ' ' || last_name
) STORED
);

COMMENT ON TABLE employee IS 'Museum staff (guides, curators, cashiers, etc.)';

--3. VISITOR TABLE
CREATE TABLE visitor (
    visitor_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name  VARCHAR(100) NOT NULL,
    last_name   VARCHAR(100) NOT NULL,
    email       VARCHAR(150),
    phone       VARCHAR(30),
    birth_year  SMALLINT,
    country     VARCHAR(100),
    full_name TEXT GENERATED ALWAYS AS (
    first_name || ' ' || last_name
) STORED
);

COMMENT ON TABLE visitor IS 'Visitors who buy tickets';

--4. STORAGE_LOCATION TABLE
CREATE TABLE storage_location (
    storage_location_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code                VARCHAR(20)  NOT NULL UNIQUE,
    name                VARCHAR(100) NOT NULL,
    location_type       VARCHAR(20),
    floor               SMALLINT,
    room                VARCHAR(20),
    capacity_items      INTEGER      DEFAULT 0 
);

COMMENT ON TABLE storage_location IS 'Storage rooms and galleries';

SET search_path TO museum_mgmt;


--5. EXHIBITION TABLE

CREATE TABLE exhibition (
    exhibition_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name                 VARCHAR(200) NOT NULL,
    start_date           DATE         NOT NULL,
    end_date             DATE,
    is_online            BOOLEAN      NOT NULL DEFAULT FALSE,
    location_description VARCHAR(200),
    curator_employee_id  BIGINT,
    CONSTRAINT fk_exhibition_curator
        FOREIGN KEY (curator_employee_id)
        REFERENCES museum_mgmt.employee(employee_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
);

COMMENT ON TABLE exhibition IS 'Museum exhibitions (physical or online)';
COMMENT ON COLUMN exhibition.curator_employee_id IS 'Curator responsible for this exhibition';


--6. ITEM_STORAGE TABLE

CREATE TABLE item_storage (
    item_storage_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    item_id             BIGINT      NOT NULL,
    storage_location_id BIGINT      NOT NULL,
    stored_from         DATE        NOT NULL,
    stored_to           DATE,
    CONSTRAINT fk_item_storage_item
        FOREIGN KEY (item_id)
        REFERENCES museum_mgmt.museum_item(item_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_item_storage_location
        FOREIGN KEY (storage_location_id)
        REFERENCES museum_mgmt.storage_location(storage_location_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

COMMENT ON TABLE item_storage IS 'History of where each museum item is stored';


--7. EXHIBITION_ITEM (M:N JUNCTION)

CREATE TABLE exhibition_item (
    exhibition_id BIGINT NOT NULL,
    item_id       BIGINT NOT NULL,
    displayed_from DATE,
    displayed_to   DATE,
    CONSTRAINT pk_exhibition_item
        PRIMARY KEY (exhibition_id, item_id),
    CONSTRAINT fk_exhibition_item_exhibition
        FOREIGN KEY (exhibition_id)
        REFERENCES museum_mgmt.exhibition(exhibition_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_exhibition_item_item
        FOREIGN KEY (item_id)
        REFERENCES museum_mgmt.museum_item(item_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

COMMENT ON TABLE exhibition_item IS 'Many-to-many link between exhibitions and museum items';

--8. TICKET_SALE (TRANSACTION TABLE)

CREATE TABLE ticket_sale (
    ticket_sale_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    visitor_id          BIGINT      NOT NULL,
    exhibition_id       BIGINT,
    sold_by_employee_id BIGINT,
    sale_datetime       TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    entry_datetime      TIMESTAMP,
    ticket_type         VARCHAR(30) NOT NULL,
    price               NUMERIC(8,2) NOT NULL,
    channel             VARCHAR(20) NOT NULL DEFAULT 'ONSITE',

    sale_quarter_start  DATE GENERATED ALWAYS AS (
        date_trunc('quarter', sale_datetime)::date
    ) STORED,
    CONSTRAINT fk_ticket_sale_visitor
        FOREIGN KEY (visitor_id)
        REFERENCES museum_mgmt.visitor(visitor_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_ticket_sale_exhibition
        FOREIGN KEY (exhibition_id)
        REFERENCES museum_mgmt.exhibition(exhibition_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_ticket_sale_employee
        FOREIGN KEY (sold_by_employee_id)
        REFERENCES museum_mgmt.employee(employee_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
);

COMMENT ON TABLE ticket_sale IS 'Ticket transactions (visitor, exhibition, price, channel, etc.)';

-------------CHECK CONSTRAINTS-------------
--1. INSURANCE_VALUE NOT NEGATIVE
ALTER TABLE museum_mgmt.museum_item
ADD CONSTRAINT chk_item_insurance_nonnegative
CHECK (insurance_value >= 0);
--2. CAPACITY_ITEMS NOT NEGATIVE
ALTER TABLE museum_mgmt.storage_location
ADD CONSTRAINT chk_storage_capacity_nonnegative
CHECK (capacity_items >= 0);
--3. VALID BIRTH_YEAR
ALTER TABLE museum_mgmt.visitor
ADD CONSTRAINT chk_visitor_birth_year_valid
CHECK (
    birth_year BETWEEN 1900 AND EXTRACT(YEAR FROM CURRENT_DATE)
);

ALTER TABLE museum_mgmt.visitor
ADD CONSTRAINT uq_visitor_email UNIQUE(email);

--4. PRICE NOT NEGATIVE
ALTER TABLE museum_mgmt.ticket_sale
ADD CONSTRAINT chk_ticket_price_nonnegative
CHECK (price >= 0);
--5. TICKET_TYPE ALLOWED TYPES
ALTER TABLE museum_mgmt.ticket_sale
ADD CONSTRAINT chk_ticket_type_allowed
CHECK (
    UPPER(ticket_type) IN ('ADULT', 'CHILD', 'STUDENT', 'SENIOR')
);
--6. LOCATION_TYPE ALLOWED TYPES
ALTER TABLE museum_mgmt.storage_location
ADD CONSTRAINT chk_location_type_allowed
CHECK (
    UPPER(location_type) IN ('GALLERY', 'STORAGE', 'RESTORATION')
);
--7. START_DATE > 2024
ALTER TABLE museum_mgmt.exhibition
ADD CONSTRAINT chk_exhibition_end_after_start
CHECK (
    end_date IS NULL OR end_date >= start_date
);



--8. ITEM_STORAGE ---> STORED_TO DATE CONSISTENCY
ALTER TABLE museum_mgmt.item_storage
ADD CONSTRAINT chk_storage_dates_valid
CHECK (
    stored_to IS NULL OR stored_to >= stored_from
);

----------DML------------
SET search_path TO museum_mgmt;


---INSERT DATA---
--STORAGE_LOCATION DATA
INSERT INTO museum_mgmt.storage_location (code, name, location_type, floor, room, capacity_items)
VALUES
    ('GAL-A1', 'Main Gallery A',         'GALLERY',      1,  'A1', 200),
    ('GAL-B1', 'Modern Art Gallery',     'GALLERY',      1,  'B1', 150),
    ('GAL-C1', 'History Gallery',        'GALLERY',      2,  'C1', 180),
    ('STR-01', 'Primary Storage Room',   'STORAGE',     -1,  'S1', 500),
    ('STR-02', 'Secondary Storage Room', 'STORAGE',     -1,  'S2', 300),
    ('RST-01', 'Restoration Studio',     'RESTORATION',  0,  'R1',  50);

--EMPLOYEE DATA
INSERT INTO museum_mgmt.employee (
    employee_no, first_name, last_name, role,
    hire_date, email, phone, is_active
)
VALUES
    ('EMP-001', 'Emma',    'Turner',  'CURATOR',
        DATE '2022-03-10', 'emma.turner@museum.org',    '+1-202-555-1001', TRUE),
    ('EMP-002', 'Michael', 'Brown',   'GUIDE',
        DATE '2023-05-21', 'michael.brown@museum.org',  '+1-202-555-1002', TRUE),
    ('EMP-003', 'Olivia',  'Clark',   'CASHIER',
        DATE '2024-01-15', 'olivia.clark@museum.org',   '+1-202-555-1003', TRUE),
    ('EMP-004', 'Ethan',   'Wilson',  'SECURITY',
        DATE '2021-11-02', 'ethan.wilson@museum.org',   '+1-202-555-1004', TRUE),
    ('EMP-005', 'Sophia',  'Bennett', 'CURATOR',
        DATE '2020-09-30', 'sophia.bennett@museum.org', '+1-202-555-1005', TRUE),
    ('EMP-006', 'Daniel',  'Carter',  'GUIDE',
        DATE '2024-06-01', 'daniel.carter@museum.org',  '+1-202-555-1006', TRUE);

--MUSEUM_ITEM DATA
INSERT INTO museum_mgmt.museum_item (
    accession_code, title, item_type, category,
    description, creation_year, origin_country,
    acquisition_date, insurance_value, is_on_display
)
VALUES
    ('ACC-0001', 'Portrait of a Woman',      'PAINTING',  'ART',
        '19th-century oil portrait on canvas.', 1885, 'France',
        CURRENT_DATE - INTERVAL '70 days', 50000, TRUE),

    ('ACC-0002', 'Ancient Greek Vase',       'CERAMIC',   'HISTORY',
        'Decorated classical vase with geometric motifs.', -500, 'Greece',
        CURRENT_DATE - INTERVAL '80 days', 30000, FALSE),

    ('ACC-0003', 'Ammonite Fossil',          'FOSSIL',    'SCIENCE',
        'Well-preserved ammonite fossil specimen.', -10000, 'Unknown',
        CURRENT_DATE - INTERVAL '40 days', 15000, TRUE),

    ('ACC-0004', 'Ottoman Decorative Sword', 'WEAPON',    'HISTORY',
        'Ornamental sword from the Ottoman period.', 1700, 'Turkey',
        CURRENT_DATE - INTERVAL '55 days', 45000, TRUE),

    ('ACC-0005', 'Abstract Steel Sculpture', 'SCULPTURE', 'ART',
        'Contemporary abstract sculpture made of steel.', 2020, 'USA',
        CURRENT_DATE - INTERVAL '20 days', 20000, TRUE),

    ('ACC-0006', 'Solar System Poster Set',  'PRINT',     'SCIENCE',
        'Educational posters illustrating the solar system.', 2024, 'USA',
        CURRENT_DATE - INTERVAL '10 days', 8000, FALSE);

--VISITOR DATA
INSERT INTO museum_mgmt.visitor (first_name, last_name, email, phone, birth_year, country)
VALUES
    ('Emma',   'Walker',   'emma.walker@example.com',   '+1-202-555-1101', 1998, 'USA'),
    ('Daniel', 'Miller',   'daniel.miller@example.com', '+1-202-555-1102', 1995, 'USA'),
    ('Lily',   'Ivanova',  'lily.ivanova@example.com',  '+7-999-1234567',  2001, 'Russia'),
    ('Sophia', 'Lopez',    'sophia.lopez@example.com',  '+34-600-112233',  1999, 'Spain'),
    ('Marco',  'Rossi',    'marco.rossi@example.com',   '+39-333-556677',  1995, 'Italy'),
    ('Sarah',  'Johnson',  'sarah.johnson@example.com', '+44-7700-900123', 1988, 'United Kingdom');

--EXHIBITIONS DATA
INSERT INTO museum_mgmt.exhibition (
    name, start_date, end_date, is_online,
    location_description, curator_employee_id
)
VALUES
    
    ('Impressionist Portraits',
        CURRENT_DATE - INTERVAL '75 days',
        CURRENT_DATE - INTERVAL '45 days',
        FALSE,
        'Main Gallery A',
        (SELECT employee_id FROM museum_mgmt.employee WHERE employee_no = 'EMP-001')
    ),

    ('Ancient Civilizations',
        CURRENT_DATE - INTERVAL '50 days',
        CURRENT_DATE - INTERVAL '20 days',
        FALSE,
        'History Gallery',
        (SELECT employee_id FROM museum_mgmt.employee WHERE employee_no = 'EMP-005')
    ),

    ('Modern Sculpture Showcase',
        CURRENT_DATE - INTERVAL '30 days',
        CURRENT_DATE - INTERVAL '5 days',
        FALSE,
        'Modern Art Gallery',
        (SELECT employee_id FROM museum_mgmt.employee WHERE employee_no = 'EMP-001')
    ),

    ('Photography of the 20th Century',
        CURRENT_DATE - INTERVAL '25 days',
        CURRENT_DATE - INTERVAL '2 days',
        FALSE,
        'Main Gallery B',
        (SELECT employee_id FROM museum_mgmt.employee WHERE employee_no = 'EMP-006')
    ),

    ('Digital Art and New Media',
        CURRENT_DATE - INTERVAL '18 days',
        CURRENT_DATE - INTERVAL '1 days',
        TRUE,
        'Online platform',
        (SELECT employee_id FROM museum_mgmt.employee WHERE employee_no = 'EMP-001')
    ),

    ('Natural History Highlights',
        CURRENT_DATE - INTERVAL '15 days',
        CURRENT_DATE + INTERVAL '15 days',
        FALSE,
        'History Gallery – Special Hall',
        (SELECT employee_id FROM museum_mgmt.employee WHERE employee_no = 'EMP-005')
    );


	--ITEM_STORAGE DATA
	INSERT INTO museum_mgmt.item_storage (item_id, storage_location_id, stored_from, stored_to)
SELECT
    item_id,
    (SELECT storage_location_id FROM museum_mgmt.storage_location WHERE code = 'STR-01'),
    CURRENT_DATE - INTERVAL '90 days',
    NULL
FROM museum_mgmt.museum_item;

--LINK ITEMS TO EXHIBITIONS (M:N)

-- Exhibition 1: Impressionist Portraits
INSERT INTO museum_mgmt.exhibition_item (exhibition_id, item_id, displayed_from, displayed_to)
SELECT
    (SELECT exhibition_id FROM museum_mgmt.exhibition WHERE name = 'Impressionist Portraits'),
    item_id,
    CURRENT_DATE - INTERVAL '70 days',
    CURRENT_DATE - INTERVAL '45 days'
FROM museum_mgmt.museum_item
WHERE accession_code IN ('ACC-0001','ACC-0002','ACC-0003');

-- Exhibition 2: Ancient Civilizations
INSERT INTO museum_mgmt.exhibition_item (exhibition_id, item_id, displayed_from, displayed_to)
SELECT
    (SELECT exhibition_id FROM museum_mgmt.exhibition WHERE name = 'Ancient Civilizations'),
    item_id,
    CURRENT_DATE - INTERVAL '50 days',
    CURRENT_DATE - INTERVAL '20 days'
FROM museum_mgmt.museum_item
WHERE accession_code IN ('ACC-0002','ACC-0004','ACC-0005');

-- Exhibition 3: Modern Sculpture Showcase
INSERT INTO museum_mgmt.exhibition_item (exhibition_id, item_id, displayed_from, displayed_to)
SELECT
    (SELECT exhibition_id FROM museum_mgmt.exhibition WHERE name = 'Modern Sculpture Showcase'),
    item_id,
    CURRENT_DATE - INTERVAL '30 days',
    CURRENT_DATE - INTERVAL '5 days'
FROM museum_mgmt.museum_item
WHERE accession_code IN ('ACC-0003','ACC-0005','ACC-0006');


--TICKET_SALE DATA
INSERT INTO museum_mgmt.ticket_sale (
    visitor_id, exhibition_id, sold_by_employee_id,
    sale_datetime, entry_datetime, ticket_type, price, channel
)
VALUES
    ((SELECT visitor_id FROM museum_mgmt.visitor WHERE email = 'emma.walker@example.com'),
     (SELECT exhibition_id FROM museum_mgmt.exhibition WHERE name = 'Impressionist Portraits'),
     (SELECT employee_id FROM museum_mgmt.employee WHERE employee_no = 'EMP-003'),
     CURRENT_TIMESTAMP - INTERVAL '60 days',
     CURRENT_TIMESTAMP - INTERVAL '60 days',
     'ADULT', 25.00, 'ONSITE'),

    ((SELECT visitor_id FROM museum_mgmt.visitor WHERE email = 'daniel.miller@example.com'),
     (SELECT exhibition_id FROM museum_mgmt.exhibition WHERE name = 'Ancient Civilizations'),
     (SELECT employee_id FROM museum_mgmt.employee WHERE employee_no = 'EMP-002'),
     CURRENT_TIMESTAMP - INTERVAL '40 days',
     CURRENT_TIMESTAMP - INTERVAL '40 days',
     'ADULT', 30.00, 'ONLINE'),

    ((SELECT visitor_id FROM museum_mgmt.visitor WHERE email = 'lily.ivanova@example.com'),
     (SELECT exhibition_id FROM museum_mgmt.exhibition WHERE name = 'Modern Sculpture Showcase'),
     (SELECT employee_id FROM museum_mgmt.employee WHERE employee_no = 'EMP-003'),
     CURRENT_TIMESTAMP - INTERVAL '25 days',
     CURRENT_TIMESTAMP - INTERVAL '25 days',
     'STUDENT', 15.00, 'ONSITE'),

    ((SELECT visitor_id FROM museum_mgmt.visitor WHERE email = 'sophia.lopez@example.com'),
     (SELECT exhibition_id FROM museum_mgmt.exhibition WHERE name = 'Impressionist Portraits'),
     (SELECT employee_id FROM museum_mgmt.employee WHERE employee_no = 'EMP-006'),
     CURRENT_TIMESTAMP - INTERVAL '70 days',
     CURRENT_TIMESTAMP - INTERVAL '70 days',
     'ADULT', 25.00, 'ONLINE'),

    ((SELECT visitor_id FROM museum_mgmt.visitor WHERE email = 'marco.rossi@example.com'),
     (SELECT exhibition_id FROM museum_mgmt.exhibition WHERE name = 'Ancient Civilizations'),
     (SELECT employee_id FROM museum_mgmt.employee WHERE employee_no = 'EMP-002'),
     CURRENT_TIMESTAMP - INTERVAL '35 days',
     CURRENT_TIMESTAMP - INTERVAL '35 days',
     'ADULT', 30.00, 'ONSITE'),

    ((SELECT visitor_id FROM museum_mgmt.visitor WHERE email = 'sarah.johnson@example.com'),
     (SELECT exhibition_id FROM museum_mgmt.exhibition WHERE name = 'Modern Sculpture Showcase'),
     (SELECT employee_id FROM museum_mgmt.employee WHERE employee_no = 'EMP-001'),
     CURRENT_TIMESTAMP - INTERVAL '10 days',
     CURRENT_TIMESTAMP - INTERVAL '10 days',
     'SENIOR', 20.00, 'ONSITE');


-----------------------------FUNCTIONS----------------------

SET search_path TO museum_mgmt;

---FUNCTION 1: UPDTAE ONE COLUMN IN MUSEUM_ITEM
--(primary key value → item_id
--column name to update → p_column_name
--new value → p_new_value
--protect against: invalid column name, trying to update the primary key)
CREATE OR REPLACE FUNCTION museum_mgmt.update_museum_item_column(
    p_item_id      BIGINT,
    p_column_name  TEXT,
    p_new_value    TEXT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_column_exists BOOLEAN;
BEGIN
-- Do not allow updating the primary key
    IF LOWER(p_column_name) = 'item_id' THEN
        RAISE EXCEPTION 'Updating the primary key column is not allowed.';
    END IF;

-- Check that if the column exists on museum_item or not
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'museum_mgmt'
          AND table_name   = 'museum_item'
          AND LOWER(column_name) = LOWER(p_column_name)
    )
    INTO v_column_exists;

    IF NOT v_column_exists THEN
        RAISE EXCEPTION 'Column "%" does not exist on table museum_item.', p_column_name;
    END IF;

-- Perform dynamic update.
    EXECUTE format(
        'UPDATE museum_mgmt.museum_item SET %I = $1 WHERE item_id = $2',
        p_column_name
    )
    USING p_new_value, p_item_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No museum_item row found with item_id = %', p_item_id;
    END IF;

    RAISE NOTICE 'museum_item row with item_id = % updated: column "%" set to "%".',
        p_item_id, p_column_name, p_new_value;
END;
$$;

---FUNCTION 2: ADD NEW TICKET TRANSACTION
CREATE OR REPLACE FUNCTION museum_mgmt.add_ticket_transaction(
    p_visitor_email     TEXT,
    p_exhibition_name   TEXT,       -- can be NULL (for general admission)
    p_employee_no       TEXT,
    p_ticket_type       TEXT,
    p_price             NUMERIC,
    p_channel           TEXT DEFAULT 'ONSITE',
    p_sale_datetime     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    p_entry_datetime    TIMESTAMP DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_visitor_id    BIGINT;
    v_exhibition_id BIGINT;
    v_employee_id   BIGINT;
    v_ticket_sale_id BIGINT;
BEGIN
-- Resolve visitor by natural key (email)
    SELECT visitor_id
    INTO v_visitor_id
    FROM museum_mgmt.visitor
    WHERE email = p_visitor_email;

    IF v_visitor_id IS NULL THEN
        RAISE EXCEPTION 'Visitor with email "%" not found.', p_visitor_email;
    END IF;

-- Resolve exhibition by name (allow NULL)
    IF p_exhibition_name IS NOT NULL THEN
        SELECT exhibition_id
        INTO v_exhibition_id
        FROM museum_mgmt.exhibition
        WHERE name = p_exhibition_name;

        IF v_exhibition_id IS NULL THEN
            RAISE EXCEPTION 'Exhibition with name "%" not found.', p_exhibition_name;
        END IF;
    ELSE
        v_exhibition_id := NULL;
    END IF;

-- Resolve employee by natural key 
    SELECT employee_id
    INTO v_employee_id
    FROM museum_mgmt.employee
    WHERE employee_no = p_employee_no;

    IF v_employee_id IS NULL THEN
        RAISE EXCEPTION 'Employee with number "%" not found.', p_employee_no;
    END IF;

-- Basic validations
    IF p_price < 0 THEN
        RAISE EXCEPTION 'Price cannot be negative (%.2f).', p_price;
    END IF;

 --surrogate keys and generated columns are not provided
    INSERT INTO museum_mgmt.ticket_sale (
        visitor_id,
        exhibition_id,
        sold_by_employee_id,
        sale_datetime,
        entry_datetime,
        ticket_type,
        price,
        channel
    )
    VALUES (
        v_visitor_id,
        v_exhibition_id,
        v_employee_id,
        p_sale_datetime,
        p_entry_datetime,
        p_ticket_type,
        p_price,
        p_channel
    )
    RETURNING ticket_sale_id INTO v_ticket_sale_id;

    RAISE NOTICE 'Ticket sale % inserted for visitor "%", exhibition "%", employee "%".',
        v_ticket_sale_id,
        p_visitor_email,
        COALESCE(p_exhibition_name, '[GENERAL ADMISSION]'),
        p_employee_no;
END;
$$;


-----------------CREATE VIEW---------------------
SET search_path TO museum_mgmt;
--ANALYTICS FOR MOST RECENT QUARTER
CREATE OR REPLACE VIEW museum_mgmt.vw_recent_quarter_summary AS
WITH recent_q AS (
    SELECT MAX(sale_quarter_start) AS q_start
    FROM museum_mgmt.ticket_sale
)
SELECT
    e.name AS exhibition_name,
    COUNT(ts.ticket_sale_id) AS total_tickets_sold,
    SUM(ts.price) AS total_revenue,
    COUNT(DISTINCT ts.visitor_id) AS unique_visitors,
    e.is_online AS is_online_exhibition,
    ts.sale_quarter_start AS quarter_start
FROM museum_mgmt.ticket_sale ts
INNER JOIN museum_mgmt.exhibition e
    ON ts.exhibition_id = e.exhibition_id
INNER JOIN recent_q rq
    ON ts.sale_quarter_start = rq.q_start
GROUP BY
    e.name,
    e.is_online,
    ts.sale_quarter_start
ORDER BY total_revenue DESC;

---TEST
SELECT * FROM museum_mgmt.vw_recent_quarter_summary;

------------READ-ONLY MANAGER ROLE---------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT FROM pg_roles WHERE rolname = 'museum_manager_ro'
    ) THEN
        CREATE ROLE museum_manager_ro
            LOGIN
            PASSWORD 'MuseumPassword';
    END IF;
END $$;

GRANT USAGE ON SCHEMA museum_mgmt TO museum_manager_ro;

GRANT SELECT ON ALL TABLES IN SCHEMA museum_mgmt TO museum_manager_ro;

ALTER DEFAULT PRIVILEGES IN SCHEMA museum_mgmt
GRANT SELECT ON TABLES TO museum_manager_ro;

--TEST
SELECT * FROM museum_mgmt.vw_recent_quarter_summary;
