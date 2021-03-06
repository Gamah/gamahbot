--
-- PostgreSQL database dump
--

-- Dumped from database version 12.9 (Ubuntu 12.9-0ubuntu0.20.04.1)
-- Dumped by pg_dump version 12.9 (Ubuntu 12.9-0ubuntu0.20.04.1)

-- Started on 2022-02-02 19:41:01 CST

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
-- TOC entry 3004 (class 1262 OID 16386)
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
-- TOC entry 211 (class 1255 OID 16503)
-- Name: log_message(bigint, character varying, character varying); Type: FUNCTION; Schema: public; Owner: gamahbot
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

insert into messages(chatter_id,message,timestamp,session_id)
values(chatter_id,log_message,current_timestamp,(select id from sessions where endtime is null limit 1));

RETURN LASTVAL();
END; 
$$;


ALTER FUNCTION public.log_message(chatter_id bigint, name character varying, log_message character varying) OWNER TO gamahbot;

--
-- TOC entry 225 (class 1255 OID 16507)
-- Name: sessions_start(); Type: FUNCTION; Schema: public; Owner: gamahbot
--

CREATE FUNCTION public.sessions_start() RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN

UPDATE sessions SET endtime = TO_TIMESTAMP('1900-01-01 00:00:00','YYYY-MM-DD HH24:MI:SS') WHERE endtime IS NULL;
INSERT INTO sessions(starttime) values(current_timestamp);

RETURN LASTVAL();

END; 
$$;


ALTER FUNCTION public.sessions_start() OWNER TO gamahbot;

--
-- TOC entry 224 (class 1255 OID 16509)
-- Name: sessions_stop(bigint); Type: FUNCTION; Schema: public; Owner: gamahbot
--

CREATE FUNCTION public.sessions_stop(session_id bigint) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
	UPDATE sessions SET endtime = current_timestamp WHERE sessions.id = session_id;
RETURN session_id;

END; 
$$;


ALTER FUNCTION public.sessions_stop(session_id bigint) OWNER TO gamahbot;

--
-- TOC entry 226 (class 1255 OID 16521)
-- Name: vibechecks_start(bigint); Type: FUNCTION; Schema: public; Owner: gamahbot
--

CREATE FUNCTION public.vibechecks_start(message_id bigint) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN

INSERT INTO vibechecks(message_id) values(message_id);

RETURN LASTVAL();
END; 
$$;


ALTER FUNCTION public.vibechecks_start(message_id bigint) OWNER TO gamahbot;

--
-- TOC entry 229 (class 1255 OID 16589)
-- Name: vibeins_checkscore(bigint); Type: FUNCTION; Schema: public; Owner: gamahbot
--

CREATE FUNCTION public.vibeins_checkscore(chatter_id bigint) RETURNS integer
    LANGUAGE plpgsql
    AS $$


BEGIN

RETURN(
	SELECT
		sum(vi.score)
	FROM vibeins vi
	JOIN messages m on m.id = vi.message_id
	JOIN chatters c on c.id = m.chatter_id
	WHERE m.timestamp BETWEEN current_timestamp - (7 * interval '1 day') AND current_timestamp
	AND c.id = vibeins_checkscore.chatter_id
);

END;
$$;


ALTER FUNCTION public.vibeins_checkscore(chatter_id bigint) OWNER TO gamahbot;

--
-- TOC entry 227 (class 1255 OID 16591)
-- Name: vibeins_leaders(); Type: FUNCTION; Schema: public; Owner: gamahbot
--

CREATE FUNCTION public.vibeins_leaders() RETURNS TABLE(display_name character varying, score numeric)
    LANGUAGE plpgsql
    AS $$

BEGIN

RETURN QUERY
	
	SELECT
		c.display_name,sum(vi.score::numeric)
	FROM vibeins vi
	JOIN messages m on m.id = vi.message_id
	JOIN chatters c on c.id = m.chatter_id
	WHERE m.timestamp BETWEEN current_timestamp - (7 * interval '1 day') AND current_timestamp
	GROUP BY c.display_name
	ORDER BY 2 DESC
	LIMIT 3;

END;
$$;


ALTER FUNCTION public.vibeins_leaders() OWNER TO gamahbot;

--
-- TOC entry 228 (class 1255 OID 16532)
-- Name: vibeins_submit(bigint); Type: FUNCTION; Schema: public; Owner: gamahbot
--

CREATE FUNCTION public.vibeins_submit(message_id bigint) RETURNS integer
    LANGUAGE plpgsql
    AS $$


DECLARE 
	current_vibecheck bigint;
	score bigint;
	new_score bigint;
	already_vibed_message_id bigint;

BEGIN

SELECT v.id 
INTO current_vibecheck
from vibechecks v 
join messages m on m.id = v.message_id 
where m.timestamp + (5 * interval '1 minute') > current_timestamp;



IF current_vibecheck IS NULL
THEN
	INSERT INTO vibeins(message_id,score) VALUES(vibeins_submit.message_id,-100);
	RETURN -100;
ELSE
	SELECT vi.message_id
	INTO already_vibed_message_id
	FROM vibeins vi
	JOIN messages m on m.id = vi.message_id
	JOIN chatters c on c.id = m.chatter_id
	WHERE vi.vibecheck_id = current_vibecheck
	AND m.chatter_id = (select chatter_id from messages where id = vibeins_submit.message_id);
	
	IF already_vibed_message_id IS NULL
	THEN
		INSERT INTO vibeins(message_id, vibecheck_id,score) values(message_id,current_vibecheck,(SELECT 300 - EXTRACT(EPOCH FROM(current_timestamp - m.timestamp)) FROM vibechecks vc JOIN messages m on vc.message_id = m.id WHERE vc.id = current_vibecheck));
		RETURN(SELECT vibeins.score FROM vibeins WHERE id = lastval());																   
	ELSE
		score = (select vibeins.score from vibeins where vibeins.message_id = already_vibed_message_id);
		new_score = (SELECT 300 - EXTRACT(EPOCH FROM(current_timestamp - m.timestamp)) FROM vibechecks vc JOIN messages m on vc.message_id = m.id WHERE vc.id = current_vibecheck);
		UPDATE vibeins
		SET
			score = new_score,
			message_id = vibeins_submit.message_id
		WHERE vibeins.message_id = already_vibed_message_id;
		return new_score - score;
	END IF;
END IF;

/*

*/

return score;
END;
$$;


ALTER FUNCTION public.vibeins_submit(message_id bigint) OWNER TO gamahbot;

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
    message character varying(1024) NOT NULL,
    "timestamp" timestamp with time zone NOT NULL,
    session_id bigint DEFAULT '-1'::integer
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
-- TOC entry 208 (class 1259 OID 16515)
-- Name: vibechecks; Type: TABLE; Schema: public; Owner: gamahbot
--

CREATE TABLE public.vibechecks (
    id bigint NOT NULL,
    message_id bigint NOT NULL
);


ALTER TABLE public.vibechecks OWNER TO gamahbot;

--
-- TOC entry 207 (class 1259 OID 16513)
-- Name: vibecheck_id_seq; Type: SEQUENCE; Schema: public; Owner: gamahbot
--

ALTER TABLE public.vibechecks ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.vibecheck_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 210 (class 1259 OID 16526)
-- Name: vibeins; Type: TABLE; Schema: public; Owner: gamahbot
--

CREATE TABLE public.vibeins (
    id bigint NOT NULL,
    message_id bigint NOT NULL,
    vibecheck_id bigint,
    score bigint NOT NULL
);


ALTER TABLE public.vibeins OWNER TO gamahbot;

--
-- TOC entry 209 (class 1259 OID 16524)
-- Name: vibeins_id_seq; Type: SEQUENCE; Schema: public; Owner: gamahbot
--

ALTER TABLE public.vibeins ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.vibeins_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 2864 (class 2606 OID 16465)
-- Name: chatters chatters_id; Type: CONSTRAINT; Schema: public; Owner: gamahbot
--

ALTER TABLE ONLY public.chatters
    ADD CONSTRAINT chatters_id UNIQUE (id);


--
-- TOC entry 2866 (class 2606 OID 16444)
-- Name: chatters chatters_pkey; Type: CONSTRAINT; Schema: public; Owner: gamahbot
--

ALTER TABLE ONLY public.chatters
    ADD CONSTRAINT chatters_pkey PRIMARY KEY (id);


--
-- TOC entry 2868 (class 2606 OID 16483)
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: gamahbot
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- TOC entry 2862 (class 2606 OID 16405)
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: gamahbot
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- TOC entry 2870 (class 2606 OID 16519)
-- Name: vibechecks vibecheck_pkey; Type: CONSTRAINT; Schema: public; Owner: gamahbot
--

ALTER TABLE ONLY public.vibechecks
    ADD CONSTRAINT vibecheck_pkey PRIMARY KEY (id);


--
-- TOC entry 2872 (class 2606 OID 16530)
-- Name: vibeins vibeins_pkey; Type: CONSTRAINT; Schema: public; Owner: gamahbot
--

ALTER TABLE ONLY public.vibeins
    ADD CONSTRAINT vibeins_pkey PRIMARY KEY (id);


-- Completed on 2022-02-02 19:41:01 CST

--
-- PostgreSQL database dump complete
--

