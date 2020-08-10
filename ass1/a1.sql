--1.List all the company names (and countries) that are incorporated outside Australia. 
create or replace view Q1(Name, Country) as 
select name, country
from company 
where country != 'Australia';


--Q2
Create or replace view Q2(Code) as
select Code
from Executive 
group by Code
having count(Person) > 5;


--Q3
create or replace view Q3(Name) as
select distinct Name
from category ca,company co
where ca.Code = co.Code and sector = 'Technology';


--Q4
create or replace view Q4(Sector, Number) as
select sector, count(distinct industry)
from category
group by sector;

--Q5
create or replace view Q5(Name) as
select distinct e.Person
from Executive e,Category c
where e.Code = c.Code
and c.sector = 'Technology';


--Q6
create or replace view Q6(Name) as
select co.name
from Company co,Category ca
where co.Code = ca.Code
and ca.sector = 'Services'
and co.country = 'Australia'
and co.Zip like '2%';



---Q7

create or replace view Q7_1("Date", Code, Volume, PrevPrice, Price, Change, Gain) as
select "Date",Code,Volume,
lag(Price,1) over (Partition by Code Order by "Date") as PrevPrice,
Price,
(Price - lag(Price,1) over (Partition by Code Order by "Date")) as Change,
(Price - lag (Price, 1) over (partition by Code order by "Date")) / lag (Price, 1) over (partition by Code order by "Date") * 100 as Gain
from asx;



create or replace view Q7("Date", Code, Volume, PrevPrice, Price, Change, Gain) as
select "Date", Code, Volume, PrevPrice, Price, Change, Gain
from Q7_1
where "Date" != (select distinct min("Date") from asx);




---Q8
create or replace view Q8_1("Date",Volume) as
select "Date",max(Volume)
from ASX
group by "Date";

create or replace view Q8("Date",Code,Volume) as
select a."Date",a.code,m.Volume
from ASX a, q8_1 m
where a."Date" = m."Date" and a.Volume = m.Volume
order by "Date",Code;


---Q9
Create or replace view Q9(Sector,Industry,Number) as
select Sector,Industry,count(Distinct Code)
from Category
Group by Sector,Industry
order by Sector,Industry;


--Q10
create or replace view Q10_1(Industry, Count) as
select industry, count(industry)
from category
group by industry;

create or replace view Q10(Code, Industry) as
select c.code, q.industry
from category c, Q10_1 q
where c.industry = q.industry and q.count = 1;



---Q11
create or replace view Q11(Sector, AvgRating) as
select com.Sector,AVG(com.AVGSTAR)
from 
----Average star for each company
(
select c.Sector,c.Code,AVG(r.Star) as AVGSTAR
from Category c 
inner join rating r
on c.Code = r.Code
group by c.Sector,c.Code 
)as com
group by com.Sector
order by AVG(com.AVGSTAR) DESC;


---Q12
create or replace view Q12(Name) as
select Distinct con.Person
from  (
select Person,count(Distinct Code) 
from executive 
group by Person
Having count(Distinct Code) > 1 ----More than one
) as con;



---Q13
create or replace view Q13(Code, Name, Address, Zip, Sector) as
select co.Code,co.Name,co.Address,co.zip,ca.Sector
from Company co,Category Ca
where co.Code = Ca.Code
and ca.Sector not in (
--Exclude the company that has overaseas address
select ca.Sector
from Company co
inner join Category ca
on ca.Code = co.Code
where co.country != 'Australia'
);


---Q14
create or replace view Q14(Code, BeginPrice, EndPrice, Change, Gain) as
select temp.Code,Fir.Price,Las.Price,
Las.Price - Fir.Price as Change,
(Las.Price-Fir.Price)/Fir.Price*100 as Gain
from (
    select Code, min("Date") as mi,max("Date") as ma
    from ASX group by Code
) as temp
inner join ASX Fir
on Fir.Code = temp.Code and Fir."Date" = temp.mi
inner join ASX Las
on Las.Code = temp.Code and Las."Date" = temp.ma
Order by Gain DESC,temp.Code ASC;


--Q15
CREATE OR REPLACE VIEW Q15(Code, MinPrice, AvgPrice, MaxPrice, MinDayGain, AvgDayGain, MaxDayGain) AS
WITH Price AS
(
    SELECT
        a.code,
        MIN(a.price) AS MinPrice,
        AVG(a.price) AS AvgPrice,
        MAX(a.price) AS MaxPrice
    FROM ASX AS a
    GROUP BY a.code
),
Gain AS
(
    SELECT
        q.code,
        MIN(q.gain) AS MinDayGain,
        AVG(q.gain) AS AvgDayGain,
        MAX(q.gain) AS MaxDayGain
    FROM q7 AS q
    GROUP BY q.code
)
SELECT
    p.code,
    p.MinPrice,
    p.AvgPrice,
    p.MaxPrice,
    g.MinDayGain,
    g.AvgDayGain,
    g.MaxDayGain
FROM price AS p
INNER JOIN gain AS g
ON p.code = g.code;


--Q16
-- create funtion trigger1()
create or replace function trigger1() returns trigger as $$
declare
        NumofCount int;
begin
    NumofCount := count(code) from executive where person = new.person;
    if NumofCount > 1 then 
        raise exception 'Invalid! This person is already there!';
    end if;
return new;
end;
$$ language plpgsql;


--create trigger Q16
create trigger q16
after insert or update on executive
for each row
execute procedure trigger1();



---Q17
--Max and Min daily gain for each sector

CREATE OR REPLACE VIEW Q17S(DT, Sector, MaxGain, MinGain) AS
SELECT
    q."Date"    AS DT,
    c.sector,
    MAX(q.gain) AS MaxGain,
    MIN(q.gain) AS MinGain
FROM q7 q
INNER JOIN category AS c
        ON q.code = c.code
GROUP BY q."Date", c.sector;

CREATE OR REPLACE FUNCTION insertASX() RETURNS TRIGGER
AS $$
DECLARE
    MxGain   FLOAT;
    MnGain   FLOAT;
    CurrGain FLOAT;
    sect     TEXT;
BEGIN
    SELECT c.sector INTO sect
    FROM category AS c
    WHERE c.code = new.code;
	
    -- Get Max, Min Gain --
    SELECT q.MaxGain, q.MinGain INTO MxGain, MnGain
    FROM Q17S AS q
    WHERE q.dt   = new."Date"
    AND   q.sector = sect;

    SELECT q.gain INTO CurrGain
    FROM Q7 AS q
    WHERE q."Date" = new."Date"
    AND   q.code   = new.code;
	
    IF (CurrGain <= MnGain) THEN
        UPDATE rating
        SET star = 1
        WHERE code = new.code;
    END IF;
	
    IF (CurrGain >= MxGain) THEN
        UPDATE rating
        SET star = 5
        WHERE code = new.code;
    END IF;
	
	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER checkInsert_ASX
AFTER INSERT ON ASX
FOR EACH ROW
EXECUTE PROCEDURE insertASX();

        


--Q18
Create or replace function updateASX() returns trigger
as $$
begin
    insert into asxlog values(now(),old."Date",old.code,old.volume,old.price);
    return NULL;
END;
$$ Language plpgsql;

Create Trigger Q18
after update on asx
for each row execute procedure updateASX();
 

