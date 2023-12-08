
select *
from dbo.DS_Jobs_Table

-- The company name column contains the rating of the company next to the name. let's fix that.
update DS_Jobs_Table
set Company_Name=
case
when floor(rating)=ceiling(rating) then replace(Company_Name,Concat(CONVERT(varchar(50),Rating),'.0'),'')
else replace(Company_Name,CONVERT(varchar(50),Rating),'')
end

-- We might want to make further analysis regarding the company's location, so let's divide the location column to city and state
Alter table DS_Jobs_Table
add location_state varchar(50)

update DS_Jobs_Table
set location_state=SUBSTRING(Location,charindex(',',Location)+2,2),
Location=REPLACE(Location,SUBSTRING(Location,charindex(',',Location),4),'')

sp_rename 'DS_Jobs_Table.Location', 'location_city', 'column'

-- the salary estimate column's datatype is varchar. To make queries on pay range easier, let's seperate it into two int columns.
alter table DS_Jobs_Table
add min_salary_est int, max_salary_est int

update DS_Jobs_Table
set
min_salary_est=convert(int,substring(Salary_Estimate,2,charindex('k',Salary_Estimate)-2))*1000,
max_salary_est=convert(int,substring(Salary_Estimate,charindex('-',Salary_Estimate)+2,charindex('(',Salary_Estimate)-charindex('-',Salary_Estimate)-4))*1000


-- we can add a column that describes wether the position is intended for a senior, a junior or unspecified
alter table DS_Jobs_Table
add seniority varchar(50)

update DS_Jobs_Table
set Seniority=
case
when CHARINDEX('senior',Job_Title)>0 or CHARINDEX('sr',Job_Title)>0 then 'senior'
when CHARINDEX('junior',Job_Title)>0 or CHARINDEX('jr', Job_Title)>0 then 'junior'
else 'unspecified'
end

-- we can extract a few common data scientist skills out of the job description column to get a better understanding of the the employer is looking for
alter table DS_Jobs_Table
add python int, [hadoop] int, spark int, aws int, tableau int

update DS_Jobs_Table
set python=
case
when CHARINDEX('python',Job_Description)>0 then 1
else 0
end,
[hadoop]=
case
when CHARINDEX('hadoop',Job_Description)>0 then 1
else 0
end,
spark=
case
when CHARINDEX('spark',Job_Description)>0 then 1
else 0
end,
aws=
case
when CHARINDEX('aws',Job_Description)>0 then 1
else 0
end,
tableau=
case
when CHARINDEX('tableau',Job_Description)>0 then 1
else 0
end