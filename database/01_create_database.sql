-- =====================================================================
-- File: 01_create_database.sql
-- Purpose: Create the database for the Mettur Dam Smart Water &
--          Irrigation Management System and select it for use.
-- Run this file FIRST.
-- =====================================================================

DROP DATABASE IF EXISTS mettur_dam_irrigation;

CREATE DATABASE mettur_dam_irrigation
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE mettur_dam_irrigation;
