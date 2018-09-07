CREATE DATABASE mmsite;
CREATE TABLE public.data (
  id integer NOT NULL,
  title character varying(255) NOT NULL,
  poster character varying(255),
  rating real DEFAULT 0,
  page integer DEFAULT 0,
  writer character varying(255),
  genres character varying(255),
  lang character varying(30),
  year integer,
  link character varying(1000),
  CONSTRAINT data_pkey PRIMARY KEY (id )
);

CREATE TABLE public.files (
  id bigserial,
  type smallint DEFAULT 0,
  file_id bigint NOT NULL,
  parent_id bigint DEFAULT 0,
  title character varying(200),
  file character varying(200),
  size bigint DEFAULT 0,
  is_web boolean DEFAULT false,
  count_download integer DEFAULT 0,
  count_view integer DEFAULT 0,
  owner_id bigint DEFAULT '-1'::integer,
  translate smallint DEFAULT 0,
  description character varying(300),
  res_x smallint DEFAULT 0,
  res_y smallint DEFAULT 0,
  other character varying(255),
  duration character varying(8),
  source character varying(255),
  source_time bigint DEFAULT 0,
  CONSTRAINT files_pkey PRIMARY KEY (id )
);
COMMENT ON COLUMN public.files.file_id IS 'Идентификатор родительского файла';
COMMENT ON COLUMN public.files.parent_id IS 'Идентификатор объекта группы';

CREATE TABLE public.files_conv_setting (
  file_id bigint NOT NULL,
  status smallint DEFAULT 1,
  change_time bigint DEFAULT 0,
  set_map character varying(10),
  set_b character varying(10),
  set_async character varying(10),
  set_af character varying(200),
  set_s character varying(15),
  set_ss character varying(15),
  set_t character varying(15),
  CONSTRAINT files_conv_setting_pkey PRIMARY KEY (file_id )
);
COMMENT ON COLUMN public.files_conv_setting.status IS '# ложь - данные не указаны, 1 - ожидает кодирования, 2 - выполнено, 3 - в процессе кодирования';

CREATE TABLE public.groups_countries (
  group_id bigint NOT NULL,
  countries_id smallint NOT NULL,
  CONSTRAINT groups_countries_pkey PRIMARY KEY (group_id , countries_id )
);

CREATE TABLE public.groups_data (
  id bigserial,
  title character varying(200),
  title_orig character varying(200),
  description character varying(1000),
  year smallint DEFAULT 0,
  allow_age smallint DEFAULT '-1'::integer,
  rate_count integer DEFAULT 0,
  rate_val integer DEFAULT 0,
  rate_our integer DEFAULT 0,
  owner_id bigint DEFAULT '-1'::integer,
  kinopoisk_id bigint NOT NULL,
  is_serial boolean DEFAULT false,
  CONSTRAINT groups_data_pkey PRIMARY KEY (id )
);
COMMENT ON COLUMN public.groups_data.allow_age IS '-1 - значение не указано';

CREATE TABLE public.groups_genres (
  group_id bigint NOT NULL,
  genres_id smallint NOT NULL,
  CONSTRAINT groups_genres_pkey PRIMARY KEY (group_id , genres_id )
);

CREATE TABLE public.groups_list (
  id bigserial,
  group_id bigint NOT NULL,
  CONSTRAINT groups_list_pkey PRIMARY KEY (id )
);
COMMENT ON TABLE public.groups_list
  IS 'Таблица хранит идентификаторы объектов групп в порядке их вывода на индексной странице.';

CREATE TABLE public.groups_peoples (
  group_id bigint NOT NULL,
  peoples_id smallint NOT NULL,
  is_director boolean DEFAULT false,
  CONSTRAINT groups_peoples_pkey PRIMARY KEY (group_id , peoples_id )
);

CREATE TABLE public.images (
  id bigserial,
  type smallint DEFAULT 0,
  parent_id bigint NOT NULL,
  owner_id bigint NOT NULL,
  title character varying(200),
  name character varying(200),
  CONSTRAINT images_pkey PRIMARY KEY (id )
);
COMMENT ON COLUMN public.images.parent_id IS '>0 - идентификатор группы
<0 - идентификатор человека';

CREATE TABLE public.members (
  id bigserial,
  title character varying(200),
  role smallint DEFAULT 1,
  pface_id bigint NOT NULL DEFAULT 0,
  vk_id bigint NOT NULL DEFAULT 0,
  CONSTRAINT members_pkey PRIMARY KEY (id , pface_id , vk_id )
);
COMMENT ON COLUMN public.members.role IS '0 - бан
1 - пользователь
2 - модератор
3 - администратор';

CREATE TABLE public.target_sessions (
  id character varying(50) NOT NULL,
  complete boolean DEFAULT false,
  value character varying(255) NOT NULL,
  last_modify integer NOT NULL,
  CONSTRAINT target_sessions_pkey PRIMARY KEY (id )
);
COMMENT ON TABLE public.target_sessions
  IS 'Таблица хранит информацию по статусу долгих запросов для реализации возврата промежуточных данных при ajax запросе.';
  
CREATE TABLE member_views (
  member_id bigint NOT NULL DEFAULT 0,
  file_id bigint NOT NULL DEFAULT 0,
  CONSTRAINT member_views_pkey PRIMARY KEY (member_id, file_id )
)

CREATE TABLE member_subscribes (
  member_id bigint NOT NULL DEFAULT 0,
  group_id bigint NOT NULL DEFAULT 0,
  CONSTRAINT member_subscribes_pkey PRIMARY KEY (member_id, group_id )
)