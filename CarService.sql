-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- 1. Fuggveny ami lehetove teszi egy tetszoleges alkatresz, tetszoleges nevu szemely altali megvasarlasat
create or replace procedure vasarolAlkatreszt(p_vasarlonev varchar2, p_darab number, p_alkatresznev varchar2)
is
    alk_ar number;
    vasarlo_id number;
    szemely_id number;
    alkatresz_id number;
    v_darab number;
    new_id number;
    new_client number;
begin
    dbms_lock.sleep(5);
    --lekerjuk az alkatresz id nev szerint
    alkatresz_id := alkatresznevToId(p_alkatresznev);
    
    --le kerjuk a szemely id nev szerint - visszaad -1 ha nem letezik
    szemely_id := szemelynevToId(p_vasarlonev);
    
    --ha nem letezik olyan fajta alkatresz amit venni szeretne akkor a ceg rendel belole
    if alkatresz_id = -1
    then
        rendelAlkatresz(p_alkatresznev, null, 'Yato', EXTRACT(MINUTE FROM SYSTIMESTAMP)*100, p_darab);
        alkatresz_id := alkatresznevToId(p_alkatresznev);
    end if;
   --az arat es a darabot ennek az alkatresznek- visszaad -1 ha nem letezik
    select part_price into alk_ar from spare_parts where part_code=alkatresz_id;
    select part_quantity into v_darab from spare_parts where  part_code=alkatresz_id;
    
    if personExists(p_vasarlonev) = 1 and alkatresz_id > 0 --ha letezik a szemely es az alkatresz
    then
            if clientOrNot(szemely_id) = 1 then --ha kliens
                select client_id into vasarlo_id from client where person_id=szemely_id;
                --vasarol
                vasarol(p_darab, alk_ar, v_darab, vasarlo_id, alkatresz_id);
            else
                --beszurjuk a klienst
                insert into client(person_id) values (szemely_id);
                select client_id into vasarlo_id from client where person_id=szemely_id;
                --vasarol
                vasarol(p_darab, alk_ar, v_darab, vasarlo_id, alkatresz_id);
            end if;
    else
            --beszurjuk a persont es klienst is, utana vasarol
            insert into people(person_name) values(p_vasarlonev);
            select person_id into new_id from people where person_name=p_vasarlonev;
            insert into client(person_id) values(new_id);
            select client_id into new_client from client where person_id=new_id;
            vasarol(p_darab, alk_ar, v_darab, new_client, alkatresz_id);
    end if;
end vasarolAlkatreszt;
/
select vasarlonevToId('Siko Mark') from dual;
/
--tulajdonkeppeni vasarlas fuggveny, ezt hasznalja a fentebbi
create or replace procedure vasarol(p_darab number, alk_ar number, v_darab number, vasarlo_id number, alkatresz_id number)
is
begin
    if v_darab >= p_darab then
        update spare_parts set part_quantity=((select part_quantity from spare_parts where part_code=alkatresz_id)-p_darab)
        where  part_code=alkatresz_id;
        dbms_output.put_line('sikerult megvenni');
        insert into sales(sales_date, sales_price, buyer_id, sales_ammount, sales_itemid)
        values(sysdate, alk_ar, vasarlo_id, p_darab, alkatresz_id);
    else
        dbms_output.put_line('NEM sikerult megvenni');
    end if;
end;
/
exec vasarol(1,  115, 5, 63, 81 );
/
exec vasarolAlkatreszt('Moldovan Adrienn', 1, 'windshield');
/
--visszaadja a megadott nevu szemely id-jat, vagy -1 ha nincs
create or replace function szemelynevToId(p_vasarlonev varchar2)
return number
is
    v_ret number;
begin
    select person_id into v_ret from people  where person_name=p_vasarlonev;
    return v_ret;
    exception when no_data_found then
    return -1;
end szemelynevToId;
/
--visszaadja a megadott alkatresz id-jat, vagy -1 ha nincs
create or replace function alkatresznevToId(p_alkatresznev varchar2)
return number
is
    v_ret number;
begin
    select part_code into v_ret from spare_parts where part_name=p_alkatresznev;
    return v_ret;
    exception when no_data_found 
    then
        return -1;
end alkatreszNevToId;
/
select *from sales;
select * from spare_parts;
/
select vasarlonevToId('Kovacs Istvan') from dual;
/
select alkatresznevToId('bonnet') from dual;
/
grant execute on nincsnegativDarab to C##info44;
/
select * from client;
select  * from people;
/
--visszaterit -1 ha a szemely nem letezik
--1 ha a szemely letezik es kliens
create or replace function personExists(p_name varchar2)
return number
is
    v_person_id number;
    v_ret number := 0;
begin
    select person_id into v_person_id from people where person_name= p_name; 
    dbms_output.put_line(v_person_id);
    if v_person_id is not null
    then
        --letezik a szemely
        dbms_output.put_line('letezik a szemely');
        v_ret := 1;
    end if;
    
    return v_ret;
    exception when no_data_found then
    return -1;
end personExists;
/
select personExists('Siko Mark') from dual;
/
declare
v_ret number;
begin 
    v_ret := personExists('Kiss Imola');
end;
/
--meghatarozza id szerint hogy kliens-e az illeto
-- visszaterit -1 ha nem, 1et ha igen
create or replace function clientOrNot(p_id number)
return number
is
    v_client_id number;
begin
    select client_id into v_client_id from client where person_id=p_id;
        if v_client_id is not null
        then
            --ha kliens
             dbms_output.put_line('kliens');
            return 1;
        end if;
    exception when no_data_found then
    return -1;
end clientOrNot;
/
select clientOrNot(162) from dual;
/

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--1. Trigger az alkatresz tablara
CREATE OR REPLACE TRIGGER nincsnegativDarab
before insert or update on spare_parts
for each row
declare
        Negative_Quantity EXCEPTION;
        Pragma exception_init (Negative_Quantity, -20001);
begin
    -- ha negativ ertekre modosulna a mennyiseg, kapjunk errort
    if ( :new.part_quantity < 0)
    then 
        raise_application_error(-20001, 'Nincs keszleten a kivant mennyiseg, csak ' || :old.part_quantity || 'darab');
    end if;
    -- ha 0ra allitodik a mennyiseg akkor az elerheto oszlop hamis (0)
    if ( :new.part_quantity = 0)
    then
         :new.part_avaiable := 0;
    end if;
    -- ha nem volt alkatresz raktaron de lett, akkor az elerheto oszlopot igazra allitjuk
    if (:old.part_quantity <= 0) and (:new.part_quantity > 0)
    then
        :new.part_avaiable := 1;
    end if;
    exception
    when Negative_Quantity then
    dbms_output.put_line('Nincs keszleten a kivant mennyiseg, csak ' || :old.part_quantity || 'darab');
end nincsnegativDarab;
/
select * from spare_parts;
select * from sales order by sales_date desc;
select * from purchases order by purchases_date desc;

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--2. Procedura, mely lehetove teszi megadott nevu, markaju alkatresz rendeleset a kivant mennyisegben
create or replace procedure rendelAlkatresz(p_alkatresznev varchar2, p_tipus varchar2, p_marka varchar2, p_ar number, p_mennyiseg number)
is
    v_alkatreszid number;
begin
    v_alkatreszid := alkatresznevToId(p_alkatresznev);
    if v_alkatreszid = -1
    then
        --ha az alkatresz eddig nem letezett a tablaban
        insert into spare_parts(part_name, part_type, part_brand, part_price, part_avaiable, part_quantity) values (p_alkatresznev, p_tipus, p_marka, p_ar, 1, p_mennyiseg);
        insert into purchases(purchases_date, purchases_price, seller_name, purchases_itemid, purchases_ammount, purchases_itemtype)
        values(sysdate, p_ar*p_mennyiseg, p_marka, (select max(part_code) from spare_parts), p_mennyiseg, 'p');
    else
        --ha mar az alkatreszek kozott letezik, csak novelni kell a keszleten a mennyiseget
        update spare_parts set part_quantity = ((select part_quantity from spare_parts where part_code=v_alkatreszid)+p_mennyiseg) where part_code=v_alkatreszid;
        insert into purchases(purchases_date, purchases_price, seller_name, purchases_itemid, purchases_ammount, purchases_itemtype)
        values(sysdate, p_ar*p_mennyiseg, p_marka, v_alkatreszid, p_mennyiseg, 'p');
    end if;
end rendelAlkatresz;
/
exec rendelAlkatresz('bonnet', 'carosserie element', 'klokkerholm', 573, 10);
/
exec rendelAlkatresz('etrier', 'brake element','gp group',115,10);
/
exec vasarolAlkatreszt('Siko Mark', 1, 'muffler');
/
update spare_parts set part_quantity=5 where part_name='etrier';
/
select * from people where person_name like 'Siko Mark';
/
select * from client where person_id=162;
/
exec vasarolAlkatreszt('Moldovan Adrienn', 14, 'muffler');commit;
/

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 3. Procedura amely visszaadja a ceg egy idoszakra eso profitjat, es beszurja egy income tablaba a ket datumot es az osszeget
create or replace function bejovetelIdoszak(p_kezdeti date, p_vegso date) return number
is PRAGMA AUTONOMOUS_TRANSACTION;
    v_alkatresz number;
    v_munka number;
    v_rendeles number;
    v_osszeg number(30,2);
begin 
        select sum(sales_price*sales_ammount) into v_alkatresz from sales where sales_date between p_kezdeti and p_vegso;
        select sum(work_fee) into v_munka from work where work_started >= p_kezdeti and work_ended <= p_vegso;
        select sum(purchases_price*purchases_ammount) into v_rendeles from purchases where purchases_date between p_kezdeti and p_vegso;
        
        v_osszeg := (v_alkatresz + v_munka)-v_rendeles;
        insert into income(income_period_start, income_period_end, income_sum) values (p_kezdeti, p_vegso, trunc(v_osszeg,2));
        commit;
        return v_osszeg;
end bejovetelIdoszak;
/
insert into income(income_period_start, income_period_end, income_sum) values ('10-APR-18', sysdate,102545);
select bejovetelIdoszak('15-MAR-20' , '24-MAY-21') from dual;
/

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 4.Procedura amely lehetove teszi egy kliens altali programalast javitasra
create or replace procedure programalas(p_kliensnev varchar2, p_vegzodatum date, p_munkaneve varchar2, p_automarka varchar2, p_autoszin varchar2 )
is
    szemely_id number;
    kliens_id number;
    kocsi_id number;
    modell_id number;
    munka_id number;
    munka_ar number;
    TYPE numeric_t IS TABLE OF number;
    munkasok numeric_t;
    munkas_id number;
begin
     szemely_id := szemelynevToId(p_kliensnev);
     
     --munkasok id-ja tombbe gyujtve
     select employee_id BULK COLLECT INTO munkasok from employee;
   
    if personExists(p_kliensnev) = 1
    then
            if clientOrNot(szemely_id) = 1 then
                select client_id into kliens_id from client where person_id=szemely_id;            
            else
                --beszurjuk a klienst
                insert into client(person_id) values (szemely_id);
                select client_id into kliens_id from client where person_id=szemely_id;
            end if;
            select car_id into kocsi_id from people where person_id=szemely_id; 
    else
        --beszurjuk a szemelyt, klienst es az autojat is
        insert into people(person_name) values(p_kliensnev);
        select person_id into szemely_id from people where person_name=p_kliensnev;
        
        insert into client(person_id) values(szemely_id);
        select client_id into kliens_id from client where person_id=szemely_id;
        
        insert into carbrand(carbrand_name, color) values (p_automarka, p_autoszin);
        select carbrand_id into modell_id from carbrand where carbrand_name=p_automarka and color=p_autoszin;
        
        insert into car(carbrand_id) values (modell_id);
        select car_id into kocsi_id from car where carbrand_id=modell_id;
    end if;
    --programal
    DBMS_RANDOM.seed (val => TO_CHAR(SYSTIMESTAMP,'YYYYDDMMHH24MISSFFFF'));
    munka_ar := trunc(DBMS_RANDOM.value(low => 20, high => 1000),2);
    munkas_id := munkasok(trunc(DBMS_RANDOM.value(low => 1, high => munkasok.count),0));
    
    insert into work(work_type, car_id, work_fee, employee_id) values (p_munkaneve, kocsi_id, munka_ar, munkas_id);
    select work_id into munka_id from work where work_type=p_munkaneve and car_id=kocsi_id;
    insert into programation(prog_date, prog_duedate, client_id, work_id) values (sysdate, p_vegzodatum, kliens_id, munka_id );
    
end programalas;
/
--az auto marka es szin param akkor kell csak megadni hogyha uj kliensrol van szo
exec programalas('Moldovan Adrienn', '10-JUN-21','tyre change', '', '');
exec programalas('Kiss Eleonora', '31-MAY-21', 'oil changing', 'Audi A8', 'green');

select * from people;
select * from client;
select * from work;
select * from programation;
/
set serveroutput on;

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--2. Trigger amely megakadalyozza hogy a programalasok datumanal hibas datum keruljon be
--a duedate nem lehet korabban mint a progdate
CREATE OR REPLACE TRIGGER dateTrigger
before insert or update on programation
for each row
declare
        invalid_date_range EXCEPTION;
        Pragma exception_init (invalid_date_range, -20002);
begin
    if (:new.prog_duedate) < (:new.prog_date) or (:new.prog_duedate) < (:old.prog_date) or (:old.prog_duedate) < (:new.prog_date)
    then
        raise_application_error(-20002, 'Az elvart elkeszitesi datum nem lehet a programalas datuma elotti!');
    end if;
end dateTrigger;
/
select * from programation;
--kivaltja a triggert
update programation set prog_date='15-DEC-20' where client_id=4 and work_id=12;
/
--tabla a torolt programalasok listazasahoz
drop table prog_log;
create table prog_log(
    prog_id number(30,0) NOT NULL,
    prog_date date,
    prog_duedate date,
    client_id number(30,0) NOT NULL,
    work_id number(30,0) NOT NULL,
    deleted_by varchar2(100) NOT NULL,
    deleted_at date NOT NULL
);
/

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--3. Trigger amelyik a fentebbi tablaba lementi a torolt programalasok adatait, valamint azt, hogy ki torolte es mikor
create or replace trigger toroltprogLogger
before  delete on programation
for each row
declare
    v_username varchar2(100);
begin
    select user into v_username from dual;
    
    insert into prog_log
    values(:old.prog_id, :old.prog_date,  :old.prog_duedate, :old.client_id, :old.work_id, v_username, sysdate);
end toroltprogLogger;
/
delete from programation where work_id=21;
select * from prog_log;
/
CREATE OR REPLACE TRIGGER nincsNegativSales
before insert or update on sales
for each row
declare
        negative_value EXCEPTION;
        Pragma exception_init (negative_value, -20003);
begin
    if :new.sales_price < 0 or :new.sales_ammount < 0
    then
        raise_application_error(-20003, 'A mennyiseg es ar nem lehet negativ!');
    end if;
end nincsNegativSales;
/

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--4. Trigger amely az ujonnan beszurt szemely telefonszamat beallitja annak fuggvenyeben, hogy hany maganhangzobol all a neve
create or replace trigger telGenerator
before insert on people
for each row
declare
    v_mgh number;
begin
    v_mgh := length(:new.person_name)- length(REGEXP_REPLACE(:new.person_name,'[a,e,i,o,u,A,E,I,O,U]',''));
    --dbms_output.put_line(v_mgh);
 
    :new.phone_nr := '07' || to_char(RPAD(to_char(v_mgh),LENGTH(to_char(v_mgh))*8,to_char(v_mgh)));
   
end telGenerator;
/
insert into people(postal_code,car_id,person_name) values(524,43, 'Oven Baker');
/
select phone_nr from people where person_name='Oven Baker';
/

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 5. Procedura amely megnezi melyik munkasoknak nem keszult el a munkaja idoben
--levonja a fizeteset annyi szazalekkal ahanyszor ez elofordult
create or replace procedure levonFizetes
is
    TYPE numeric_t IS TABLE OF number;
    munkas_idk numeric_t;
    nr_kesesek number;
    csokkent_fiz number;
    fiz number;
begin
    --lekerdezzuk melyik munkasok kestek mar es azoknak id-jat lementjuk egy tombbe
    select employee_id BULK COLLECT INTO munkas_idk from employee where employee_id in (
    select employee_id from work w join programation p
    on w.work_id = p.work_id 
    where w.work_ended >  (select prog_duedate from programation where work_id=w.work_id )
    );
    if munkas_idk.count > 0
    then
        --vegigmegyunk a tombon
        FOR  i in 1..munkas_idk.count LOOP
            --elmentjuk a kesesek szamat valtozoba
            select count(*)  into nr_kesesek from work w join programation p
            on w.work_id = p.work_id 
            where w.work_ended >  (select prog_duedate from programation where work_id=w.work_id)
            and w.employee_id=munkas_idk(i);
            
            dbms_output.put_line('A(z) ' || munkas_idk(i) ||' id-ju munkas  ennyiszer nem vegzett idobe: ' || nr_kesesek);
            
            --lekerjuk az adott munkas fizeteset
            select salary into fiz from employee where employee_id=munkas_idk(i);
            csokkent_fiz := (fiz * nr_kesesek)/100; --kiszamoljuk a csokkentes merteket
            update employee set salary=(fiz-csokkent_fiz) where employee_id=munkas_idk(i); --lecsokkentjuk a fizetest
        END LOOP;
    else
        dbms_output.put_line('Nincs kesokasa munkasunk!');
    end if;
        exception when others then
        dbms_output.put_line('Hiba van a fizetes csokkento fuggvenyben!');
end levonFizetes;
/
set serveroutput on;
exec levonfizetes;
/
select employee_id from employee where employee_id in (
    select employee_id from work w join programation p
    on w.work_id = p.work_id 
    where w.work_ended >  (select prog_duedate from programation where work_id=w.work_id )
);
/
select count(*) from work w join programation p
    on w.work_id = p.work_id 
    where w.work_ended >  (select prog_duedate from programation where work_id=w.work_id)
    and w.employee_id=1;
    
 select * from programation where work_id=101;
 select *from work where employee_id=1;
 insert into work(work_type,work_started,work_ended,work_fee,employee_id,car_id) values('tinning', '10-OCT-20', '25-MAY-21', 682.14, 1, 5);
 insert into programation(prog_date, prog_duedate, client_id,work_id) values ('10-OCT-20', '20-APR-21', 4, 101);
/

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 6. Procedura amely 40%-al megnoveli a javitas koltsegeit ha az autoja BMW es rendel neki indexet
create or replace procedure bmwSofor(p_nev varchar2 )
is 
    v_auto varchar2(100);
    kocsi_id number;
    szazalek number;
    koltseg_uj number;
    type work_bulk_type is table of number;
    v_koltseg work_bulk_type;
begin
    select car_id into kocsi_id from people where person_name=p_nev;
        
    select carbrand_name into v_auto from carbrand where carbrand_id =
                (select carbrand_id from car where car_id = kocsi_id );

    select work_fee bulk collect into v_koltseg from work where car_id=kocsi_id;
    
    if UPPER(v_auto) like 'BMW'
    then
        dbms_output.put_line('BMW markaju autoja van!');
        FOR i in 1..v_koltseg.count LOOP
            szazalek := v_koltseg(i)*40/100;
            koltseg_uj := v_koltseg(i)+szazalek;

            update work set work_fee=trunc(koltseg_uj,2) where work_fee=v_koltseg(i);
            dbms_output.put_line('A munkadij meg lett novelve!');
        END LOOP;
        vasarolAlkatreszt(p_nev, trunc(dbms_random.value(1,100), 0), 'index');
                    dbms_output.put_line('A vasarlas megtortent!');
    else
        dbms_output.put_line('Nincs BMW markaju autoja');
    end if;
    
    exception when others then
    dbms_output.put_line('A bmw fuggvenyben van a hiba!');
end bmwSofor;
/
select * from car where carbrand_id =2;
select * from people where car_id=6;
/
exec bmwSofor('Nagy Mate');
/

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 5. Trigger amely uj munka beszurasnal levon a munka arbol 10%-ot ha az illeto legalabb 3-szor vasarolt az elmult fel evben
CREATE OR REPLACE TRIGGER kedvezmeny
before insert on work
for each row
declare
type sid_bulk_type is table of number;
    v_carid sid_bulk_type;
    prcnt number;
    csokkentett number;
begin
    --tombbe tesszuk azon szemelyek kocsijanak id-jat, akik huseges vasarlok
    select car_id BULK COLLECT INTO v_carid from people where person_id in 
    (select person_id from client where client_id in 
    (select buyer_id from sales 
    where sales_date between add_months(sysdate, -6) and sysdate 
    group by buyer_id having count(buyer_id)>=3));
   
    FOR i in 1..v_carid.count LOOP
        if :new.car_id = v_carid(i)
        then
            --csokkentjuk a munka arat 40%al
            prcnt := 40 * (:new.work_fee)/100;
            csokkentett := (:new.work_fee)- trunc(prcnt,2);
            :new.work_fee := csokkentett;
        end if;
    END LOOP;
end kedvezmeny;
/
select * from work where car_id=9;
insert into work (work_type,work_started,work_ended,work_fee,employee_id, car_id) values ('oil change', '18-APR-19', '18-MAY-19', 50.25, 7, 9 );
/
-- job ami havonta meghivja a bejovetelIdoszak fuggvenyt, igy naplozza a havi nyereseget
--nem futtathattuk mert nem volt jogosultsag
--BEGIN                      
--  DBMS_SCHEDULER.CREATE_JOB ( 
--   job_name        => 'calculate_income',
--   job_type        => 'STORED_PROCEDURE',   
--   job_action      => 'bejovetelIdoszak(add_months(sysdate,-1), sysdate)',
--   repeat_interval => 'FREQ=MONTHLY;INTERVAL=1',    -- monthly
--   end_date        => add_months(sysdate,12),
--   enabled         => TRUE,
--   comments        => 'automatic filling the income table');
--END;
--/



exec C##info42.vasarolAlkatreszt('Siko Mark', 2, 'bonnet');
commit;
/
set serveroutput on;