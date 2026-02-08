/*Project: PostgreSQL Security Lab (Roles, Privileges, RLS)
Database: dvdrental
NOTE: For portfolio safety, we do NOT store passwords in the repo.
If you need to test locally, create a LOGIN user yourself.*/

-----------------------------TASK 2----------------------------------
----2.1) Create rentaluser with connect only
--2.1.1 Create the login role


DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rentaluser') THEN
    EXECUTE 'CREATE ROLE rentaluser NOLOGIN';
  END IF;
END
$$;

--2.1.2 Allow this user to connect to dvdrental
GRANT CONNECT
ON DATABASE dvdrental
TO rentaluser;

----2.2) Grant SELECT on customer and test
--2.2.1 Grant SELECT on the customer table

GRANT SELECT
ON TABLE public.customer
TO rentaluser;

--2.2.2 Test the permission

SET ROLE rentaluser;

SELECT
    cus.customer_id,
    cus.first_name,
    cus.last_name,
    cus.email,
    cus.active,
    cus.create_date
FROM public.customer AS cus
ORDER BY
    cus.customer_id;

RESET ROLE;

----2.3)Create group role rental and add rentaluser

--2.3.1 Create group role

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_roles WHERE rolname = 'rental'
    ) THEN
        CREATE ROLE rental
            NOLOGIN
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            INHERIT
            NOREPLICATION;
    END IF;
END
$$;

--2.3.2 Add rentaluser as a member of rental
GRANT rental
TO rentaluser;

----2.4)Grant INSERT & UPDATE on rental table and test

--2.4.1 Grant permissions to group role

GRANT INSERT, UPDATE
ON TABLE public.rental
TO rental;

--2.4.2 Insert a new row as that role
SET ROLE rentaluser; 

INSERT INTO public.rental (
    rental_date,
    inventory_id,
    customer_id,
    return_date,
    staff_id,
    last_update
)
SELECT
    NOW() AS rental_date,
    inv.inventory_id,
    cus.customer_id,
    NULL AS return_date,
    stf.staff_id,
    NOW() AS last_update
FROM public.inventory AS inv
CROSS JOIN LATERAL (
    SELECT customer_id
    FROM public.customer
    ORDER BY customer_id
    LIMIT 1
) AS cus
CROSS JOIN LATERAL (
    SELECT staff_id
    FROM public.staff
    ORDER BY staff_id
    LIMIT 1
) AS stf
LIMIT 1;

RESET ROLE;

--2.4.3 Update an existing row
SET ROLE rentaluser;

UPDATE public.rental AS r
SET return_date = NOW()
WHERE r.rental_id = (
    SELECT MAX(r2.rental_id)
    FROM public.rental AS r2
);

RESET ROLE;

----2.5) Revoke INSERT from rental and verify it fails
--2.5.1 Revoke INSERT
REVOKE INSERT
ON TABLE public.rental
FROM rental;
--2.5.2 Try to insert again 

SET ROLE rentaluser;
INSERT INTO public.rental (
    rental_date,
    inventory_id,
    customer_id,
    return_date,
    staff_id,
    last_update
)
SELECT
    NOW(),
    inv.inventory_id,
    cus.customer_id,
    NULL,
    stf.staff_id,
    NOW()
FROM public.inventory AS inv
CROSS JOIN LATERAL (
    SELECT cus_inner.customer_id
    FROM public.customer AS cus_inner
    ORDER BY cus_inner.customer_id
    LIMIT 1
) AS cus
CROSS JOIN LATERAL (
    SELECT stf_inner.staff_id
    FROM public.staff AS stf_inner
    ORDER BY stf_inner.staff_id
    LIMIT 1
) AS stf
LIMIT 1;
------
RESET ROLE;

----2.6) Personalized client role client_{first_name}_{last_name}
--2.6.1 finding a customer
SELECT
    cus.customer_id,
    cus.first_name,
    cus.last_name,
    COUNT(DISTINCT r.rental_id)  AS rental_count,
    COUNT(DISTINCT p.payment_id) AS payment_count
FROM public.customer AS cus
LEFT JOIN public.rental  AS r
       ON r.customer_id = cus.customer_id
LEFT JOIN public.payment AS p
       ON p.customer_id = cus.customer_id
GROUP BY
    cus.customer_id,
    cus.first_name,
    cus.last_name
HAVING
    COUNT(DISTINCT r.rental_id)  > 0
    AND COUNT(DISTINCT p.payment_id) > 0
ORDER BY
    cus.customer_id
LIMIT 1;

--2.6.2 Create the personalized role (NOLOGIN for portfolio safety)

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_roles WHERE rolname = 'client_MARY_SMITH'
    ) THEN
        EXECUTE 'CREATE ROLE client_MARY_SMITH NOLOGIN';
    END IF;
END
$$;


----------------------------TASK 3---------------------------
--3.1 Grant SELECT to that client role
GRANT SELECT
ON TABLE public.rental, public.payment
TO client_MARY_SMITH;

--3.2 Enable Row-Level Security on the tables
ALTER TABLE public.rental
    ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.payment
    ENABLE ROW LEVEL SECURITY;
	
--3.3 Create policies
---3.3.1 policy for rental
CREATE TABLE IF NOT EXISTS public.client_identity_map (
    role_name   TEXT PRIMARY KEY,
    customer_id INTEGER NOT NULL
);


DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename  = 'rental'
          AND policyname = 'rls_rental_client'
    ) THEN
        CREATE POLICY rls_rental_client
        ON public.rental
        FOR SELECT
        USING (
            customer_id = (
                SELECT cim.customer_id
                FROM public.client_identity_map AS cim
                WHERE LOWER(cim.role_name) = LOWER(current_user)
            )
        );
    END IF;
END
$$;

--3.3.2 policy for payment 

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename  = 'payment'
          AND policyname = 'rls_payment_client'
    ) THEN
        CREATE POLICY rls_payment_client
        ON public.payment
        FOR SELECT
        USING (
            customer_id = (
                SELECT cim.customer_id
                FROM public.client_identity_map AS cim
                WHERE LOWER(cim.role_name) = LOWER(current_user)
            )
        );
    END IF;
END
$$;

--3.4 test
GRANT SELECT
ON TABLE public.client_identity_map
TO client_MARY_SMITH;

--identity map as admin
INSERT INTO public.client_identity_map (role_name, customer_id)
VALUES ('client_MARY_SMITH', 1)
ON CONFLICT (role_name) DO UPDATE
SET customer_id = EXCLUDED.customer_id;

--3.4.1 test rental visibility

SET ROLE client_MARY_SMITH;

SELECT
    r.rental_id,
    r.rental_date,
    r.inventory_id,
    r.customer_id,
    r.return_date,
    r.staff_id
FROM public.rental AS r
ORDER BY
    r.rental_id;



--3.4.2 Test payment visibility 

SELECT
    p.payment_id,
    p.customer_id,
    p.staff_id,
    p.rental_id,
    p.amount,
    p.payment_date
FROM public.payment AS p
ORDER BY
    p.payment_id;

RESET ROLE;
