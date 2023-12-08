create database Book_Reviews

-- Before we begin, some required data cleaning

delete duplicates
from
(
select *, duplicates_amount = ROW_NUMBER() over (partition by user_id order by user_id)
from users_info) as duplicates
where duplicates_amount > 1

delete duplicates
from
(
select *, duplicates_amount = ROW_NUMBER() over (partition by isbn order by isbn)
from Language_Category) as duplicates
where duplicates_amount > 1

/* We have 4 tables containing data regarding books and how they are rated by different uses of an online platform: Books, Book_Ratings, users_info and Language_category.
Our data enables us to gain insight into some interesting topics. Let's go over a few examples of how we can use SQL to generate useful ways to look at the information at hand. */

-- Example 1 - In which age groups does each author enjoy the greatest popularity?
-- Before we can analyze reading trends across different age groups, we need to add another column to our user's info table.

alter table users_info
add age_group varchar(50)

update users_info
set age_group=
case
when age<18 then 'under 18'
when 18<=age and age<=25 then '18-25'
when 25<age and age<=35 then '25-35'
when 35<age and age<=50 then '35-50'
when 50<age and age<=65 then '50-65'
when 65<age then '65+'
else NULL
end

-- now let's create a temporary table linking between the ratings and the age groups of the raters. 

Create Index indexed_User_ID on Book_Ratings (User_ID)
Create Index indexed_user_id on users_info (user_id)

select Book_Ratings.*,users_info.age_group
into #ratings_info
from Book_Ratings
left join users_info on Book_Ratings.User_id=users_info.user_id

-- With everything set up, we can answer our initial question

with cte (Book_Author,age_group, Avg_Book_Rating) as (
select Distinct Books.Book_Author, #ratings_info.age_group, avg(#ratings_info.Book_Rating) over (partition by Book_Author, age_group)
from #ratings_info
left join Books on #ratings_info.ISBN=Books.ISBN
)
select Book_Author, age_group, Avg_Book_Rating
from (
select  Book_Author, age_group, Avg_Book_Rating, ROW_NUMBER() over (partition by Book_Author order by Avg_Book_Rating DESC) as rating_rank
from cte
) as ranked
where rating_rank=1

-- Example 2 - what are the popular genres in different countries?
-- Once again, we start by modifying our users info table so we can query data with regard to countries.

alter table users_info
add country varchar(50)

-- Because of some faulty data from users mis-inserting their address, we break this step to two parts so we can query only the workable data.

update users_info
set country =
SUBSTRING(location,CHARINDEX(',',location,CHARINDEX(',',location)+1), len(location)-CHARINDEX(',',location,CHARINDEX(',',location))-2)

update users_info
set country =
SUBSTRING(country,3, len(country)-2)
where len(country)>=2

-- Next, we create a temporary table linking between the ratings and the countries of the raters.

select Book_Ratings.*,users_info.country
into #ratings_geo
from Book_Ratings
left join users_info on Book_Ratings.User_id=users_info.user_id

-- Now we can write the query to answer our question

with cte (Country,Genre, Avg_Genre_Rating) as (
select Distinct #ratings_geo.Country, Language_Category.Category, avg(#ratings_geo.Book_Rating) over (partition by Country, Category)
from #ratings_geo
left join Language_Category on #ratings_geo.ISBN=Language_Category.isbn
)
select Country, Genre, Avg_Genre_Rating
from (
select  Country, Genre, Avg_Genre_Rating, ROW_NUMBER() over (partition by Country order by Avg_Genre_Rating DESC) as rating_rank
from cte
) as ranked
where rating_rank=1

-- Example 3 - What percent of young people appreciate old books?
/* To answer this question, let's first establish a few presuppositions;
We're going to define young people as those 25 years old or less and old books as those written before 1990.
We'll say a book is 'highly rated' if it recieves an 8 or above rating and 'moderatly rated' if it receives a rating between 6 to 8.
*/

select
(cast(count(case when users_info.age <=25 and Book_Ratings.Book_Rating >=8 and Books.Year_Of_Publication <1990 then 1 end)as float) / cast(count(case when users_info.age<=25 then 1 end)as float))*100 as 'highly rated',
(cast(count(case when users_info.age <=25 and Book_Ratings.Book_Rating<8 and Book_Ratings.Book_Rating>=6 and Books.Year_Of_Publication <1990 then 1 end)as float) / cast(count(case when users_info.age<=25 then 1 end)as float))*100 as 'moderately rated'
from users_info
left join Book_Ratings on users_info.user_id=Book_Ratings.User_ID
left join Books on Book_Ratings.ISBN=Books.ISBN


-- Example 4 - Which publishers specialize in certain genre?
/* Suppose we're doing market analysis in the book publishing sector, we might want to monitor the answer to this question periodically.
In order to stay up to date, we'll create an event that points once a month at publishers who devote more than half of their books to the same genre. */

create event Publisher_Portion_Update
on schedule at Current_timestamp + interval 1 month
DO
begin
select Books.Publisher as Publisher, Language_Category.Category as Genre, Count(*) as Genre_Count, Sum(count(*)) over (partition by Books.Publisher) as Publisher_Count
into #Genre_Count_Table
from Books
left join Language_Category on Books.ISBN=Language_Category.isbn
group by Books.Publisher, Language_Category.Category

Drop table if exists Genre_Publishers

select Publisher, Genre, (cast (t.Genre_Count as float)/cast(t.Publisher_Count as float))*100 as Portion
into Genre_Publishers
from #Genre_Count_Table t
where (cast (t.Genre_Count as float)/cast(t.Publisher_Count as float))>=0.5
end
