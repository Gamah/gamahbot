--
-- PostgreSQL database dump
--

-- Dumped from database version 12.9 (Ubuntu 12.9-0ubuntu0.20.04.1)
-- Dumped by pg_dump version 12.9 (Ubuntu 12.9-0ubuntu0.20.04.1)

-- Started on 2022-01-25 20:29:51 CST

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

DROP DATABASE gamahbot;
--
-- TOC entry 2982 (class 1262 OID 16386)
-- Name: gamahbot; Type: DATABASE; Schema: -; Owner: gamahbot
--

CREATE DATABASE gamahbot WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8';


ALTER DATABASE gamahbot OWNER TO gamahbot;

\connect gamahbot

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 207 (class 1255 OID 16485)
-- Name: log_message(bigint, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.log_message(chatter_id bigint, name character varying, log_message character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN

INSERT INTO chatters (id,display_name)
VALUES(chatter_id,name)
ON CONFLICT (id) 
DO 
UPDATE SET display_name = name;

insert into messages(chatter_id,message,timestamp)
values(chatter_id,log_message,current_timestamp);


RETURN chatter_id;
END; $$;


ALTER FUNCTION public.log_message(chatter_id bigint, name character varying, log_message character varying) OWNER TO postgres;

--
-- TOC entry 208 (class 1255 OID 16412)
-- Name: sessions_start(bigint); Type: PROCEDURE; Schema: public; Owner: gamahbot
--

CREATE PROCEDURE public.sessions_start(INOUT id bigint DEFAULT NULL::bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
	UPDATE sessions SET endtime = TO_TIMESTAMP('1900-01-01 00:00:00','YYYY-MM-DD HH24:MI:SS') WHERE endtime IS NULL;
    INSERT INTO sessions(starttime) values(current_timestamp);
   	SELECT sessions.id FROM sessions where endtime is null order by id desc limit 1 INTO id;
END
$$;


ALTER PROCEDURE public.sessions_start(INOUT id bigint) OWNER TO gamahbot;

--
-- TOC entry 209 (class 1255 OID 16437)
-- Name: sessions_stop(bigint); Type: PROCEDURE; Schema: public; Owner: gamahbot
--

CREATE PROCEDURE public.sessions_stop(session_id bigint)
    LANGUAGE sql
    AS $$UPDATE sessions SET endtime = current_timestamp WHERE sessions.id = session_id;$$;


ALTER PROCEDURE public.sessions_stop(session_id bigint) OWNER TO gamahbot;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 204 (class 1259 OID 16440)
-- Name: chatters; Type: TABLE; Schema: public; Owner: gamahbot
--

CREATE TABLE public.chatters (
    id bigint NOT NULL,
    display_name character varying(25)
);


ALTER TABLE public.chatters OWNER TO gamahbot;

--
-- TOC entry 206 (class 1259 OID 16479)
-- Name: messages; Type: TABLE; Schema: public; Owner: gamahbot
--

CREATE TABLE public.messages (
    id bigint NOT NULL,
    chatter_id bigint NOT NULL,
    message character varying(255) NOT NULL,
    "timestamp" timestamp with time zone NOT NULL
);


ALTER TABLE public.messages OWNER TO gamahbot;

--
-- TOC entry 205 (class 1259 OID 16477)
-- Name: messages_id_seq; Type: SEQUENCE; Schema: public; Owner: gamahbot
--

ALTER TABLE public.messages ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 202 (class 1259 OID 16401)
-- Name: sessions; Type: TABLE; Schema: public; Owner: gamahbot
--

CREATE TABLE public.sessions (
    id bigint NOT NULL,
    starttime timestamp with time zone NOT NULL,
    endtime timestamp with time zone
);


ALTER TABLE public.sessions OWNER TO gamahbot;

--
-- TOC entry 203 (class 1259 OID 16406)
-- Name: sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: gamahbot
--

ALTER TABLE public.sessions ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 2846 (class 2606 OID 16465)
-- Name: chatters chatters_id; Type: CONSTRAINT; Schema: public; Owner: gamahbot
--

ALTER TABLE ONLY public.chatters
    ADD CONSTRAINT chatters_id UNIQUE (id);


--
-- TOC entry 2848 (class 2606 OID 16444)
-- Name: chatters chatters_pkey; Type: CONSTRAINT; Schema: public; Owner: gamahbot
--

ALTER TABLE ONLY public.chatters
    ADD CONSTRAINT chatters_pkey PRIMARY KEY (id);


--
-- TOC entry 2850 (class 2606 OID 16483)
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: gamahbot
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- TOC entry 2844 (class 2606 OID 16405)
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: gamahbot
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


-- Completed on 2022-01-25 20:29:51 CST

--
-- PostgreSQL database dump complete
--

