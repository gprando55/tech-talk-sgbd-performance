--Numero aleatorio (Quantidade max de digitos por parametro)
create or replace function numero(digitos integer) returns integer as
$$
   begin
      return trunc(random()*power(10,digitos));
   end;
$$language plpgsql;
--select numero(3);

--Data aleatoria (indicar periodo na funcao se quiser alterar)
create or replace function data() returns date as
$$
   begin
   return date(timestamp '1980-01-01 00:00:00' +
       random() * (timestamp '2017-01-30 00:00:00' -
                   timestamp '1990-01-01 00:00:00'));
   end;
$$language plpgsql;
--select data()

--Texto aleatorio
Create or replace function texto(tamanho integer) returns text as
$$
declare
  chars text[] := '{0,1,2,3,4,5,6,7,8,9,A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z,a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z}';
  result text := '';
  i integer := 0;
begin
  if tamanho < 0 then
    raise exception 'Tamanho dado nao pode ser menor que zero';
  end if;
  for i in 1..tamanho loop
    result := result || chars[1+random()*(array_length(chars, 1)-1)];
  end loop;
  return result;
end;
$$ language plpgsql;

--select texto(5)

----------------------------------------------



-- indexar Texto
create table teste(nome varchar);

do $$
begin
for i in 1..1000000 loop
insert into teste values (texto(10));
end loop;
end; $$
language plpgsql;

analyze teste;


explain analyze
select * from teste where nome LIKE 'eQi%';
--Execution Time: 45.253 ms

create index idxtext on teste(nome);

-- index não acessado pois usa % pesquisa de texto completa
explain analyze
select * from teste where nome LIKE 'eQi%';


CREATE EXTENSION pg_trgm;


create index idxtextTrgm on teste using GIN(nome gin_trgm_ops);

explain analyze
select * from teste where nome LIKE 'eQi%';




-- Index Bitmap
create table pessoa (
	id serial primary key,
	nome varchar,
	genero varchar(1) check (genero in ('M','F'))
);

do $$
begin
for i in 1..1000000 loop
insert into pessoa(nome, genero) values (texto(10),'M');
end loop;
end; $$
language plpgsql;

do $$
begin
for i in 1..1000000 loop
insert into pessoa(nome, genero) values (texto(10),'F');
end loop;
end; $$
language plpgsql;

analyze pessoa;

explain analyze
select * from pessoa where genero = 'M';

create extension btree_gin;

create index idxgeneroBitmap on pessoa using gin (genero);
analyze pessoa;

explain analyze
select * from pessoa where genero = 'M';


create index idxNomeBTree on pessoa using (nome);
analyze pessoa;

explain analyze
select * from pessoa where nome = 'joao';


-- Hash usado somente para comparações "=", pouco usado
create index idxNomeHash on pessoa USING HASH (nome);
analyze pessoa;

drop index idxNomeBTree;

explain analyze
select * from pessoa where nome = 'joao';

-- Boa indicação para consultas com WHERE...AND. Ao usar OR o índice não será utilizado pelo PostgreSQL:



-- Indexar JSON
create table students (info jsonb);
do $$
declare vartype varchar [] = '{"quiz", "exam", "homework"}';
begin for i in 1..1000000 loop for j in 1..3 loop
insert into students
values (
    (
      '
{
"student" : ' || i || ',
"type" : "' || vartype [j] || '",
"score" : ' || round(random() * 100) || '
}'
    )::json
  );
end loop;
end loop;
end;
$$ language plpgsql;

explain analyze
Select info
FROM students
where info->>'type' = 'quiz';

create index idxtype on students using BTREE ((info->>'type'));

explain analyze
Select *
FROM students
WHERE info @> '{"type": "quiz"}';

create index idxJSON on students using GIN (info);

Select info->>'student'
FROM students
where info->>'score' = '10'
group by info->>'student' explain analyze;

Select *
FROM students
WHERE info @> '{"student": 3212}'
  and info->>'type' = 'exam';

explain analyze
Select info->>'score'
FROM students
WHERE info->>'student' = '3212';

