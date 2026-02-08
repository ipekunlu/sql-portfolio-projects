# Museum Management System 

## Overview
A relational database designed for managing museum items, storage locations, exhibitions, employees, and ticket sales.
The project includes conceptual modeling, logical schema design, and PostgreSQL implementation.

## Data Model
Key relationships covered:
- Museum items stored in storage locations (history tracked)
- Items participating in exhibitions (M:N)
- Exhibitions curated by employees (1:N)
- Visitors buying tickets; ticket sales optionally linked to exhibitions

## What I built
- Conceptual ER model and logical relational schema
- PostgreSQL schema with primary/foreign keys and constraints
- Implementation script to create tables and relationships

## Files
- Museum_ConceptModel.png = Conceptual model (ER)
- Museum_LogicalModel.png = Logical schema (tables/keys)
- Museum_System_Implementation.sql = PostgreSQL table creation script
- Museum_Project_Documentation.docx = Project explanation and design notes

## Skills Demonstrated
- Relational data modeling (ER --> relational)
- Normalization and relationship mapping (1:N, M:N)
- SQL DDL (PK/FK, constraints)
