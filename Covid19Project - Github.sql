USE Covid19Project

select * from Covid19Project..CovidCases

--View table with some useful fields
select location, continent, date, population, total_cases, new_cases, total_deaths, new_deaths
from Covid19Project..CovidCases
order by 1,3


--Compare total cases to total population
select location, date, population, total_cases
		,cast((total_cases/population)*100 as decimal(6,4)) as InfectionRate
from Covid19Project..CovidCases
order by 1,2


-- Total cases per population each country
select location, population
		, max(total_cases) as TotalCases
		, max((total_cases/population) *100) as InfectionRate
from Covid19Project..CovidCases
where continent is not null --To eliminate sum data
group by location, population
order by InfectionRate DESC


--Global numbers--
select convert(date,max(date)) as PresentDate
		, sum(new_cases) as TotalCasesWorldwide
		, sum(cast(new_deaths as int)) as TotalDeathsWorldwide
from Covid19Project..CovidCases
where continent is not null --To eliminate sum data

--Create view from Global numbers and calculate Death rate worldwide--
USE Covid19Project
if exists(select * from sys.views where name = 'ViewGlobalNumbers')
	drop view ViewGlobalNumbers
GO
create view ViewGlobalNumbers as 
select convert(date,max(date)) as PresentDate
		, sum(new_cases) as TotalCasesWorldwide
		, sum(cast(new_deaths as int)) as TotalDeathsWorldwide
from Covid19Project..CovidCases
where continent is not null --To eliminate sum data
GO
select *, cast((TotalDeathsWorldwide/TotalCasesWorldwide *100) as decimal(6,4)) as DeathRateWorldwide
from ViewGlobalNumbers


--Create view from Global numbers and calculate Death rate by continent--
USE Covid19Project
drop view if exists View_GlobalNumbersByContinent
GO
create view View_GlobalNumbersByContinent as
	select continent
			, sum(new_cases) as Total_CasesPerContinent
			, sum(cast(new_deaths as int)) as Total_DeathsPerContinent
	from Covid19Project..CovidCases
	where continent is not null
	group by continent
GO
select *
		, cast(Total_DeathsPerContinent/Total_CasesPerContinent * 100 as decimal(6,4)) as DeathRatePerContinent
from View_GlobalNumbersByContinent


--Shows cumulative total cases from new cases day by day
--== CTE ==
GO
with CTE_cumulative_total_cases as
(
select location, cast(date as date) as Date, population, new_cases
	, sum(new_cases) over(partition by location order by date) as Total_cases
from Covid19Project..CovidCases
where continent is not null
)
select location
		, max(Date) as Date
		, max(population) as Population
		, max(Total_cases) as Total_cases
		, cast(max(Total_cases/population * 100) as decimal(7,4)) as InfectionRatePerPop
from CTE_cumulative_total_cases
group by location
order by population DESC


--Show top 10 countries with highest new cases a day 
select top (10) location, continent, population
		, max(new_cases) as HighestNewCases
		, cast(max(new_cases)/population * 100 as decimal(6,4)) as HighestInfectionRate
from Covid19Project..CovidCases
where continent IS NOT NULL 
group by location, continent, population
order by HighestNewCases DESC


--Shows cumulative total deaths from new deaths day by day (over())
--== CTE within View ==

if exists(select * from sys.views where name = 'vwCTE_DeathRatePerCases')
	drop view VwCTE_DeathRatePerCases
GO
create view VwCTE_DeathRatePerCases as
	with CTE_cumulative_total_deaths as
	(
	select location, continent, cast(date as date) as Date, population, total_cases, new_deaths
		, sum(cast(new_deaths as int)) over(partition by location order by date) as Total_deaths
	from Covid19Project..CovidCases
	where continent is not null
	)
	select location, continent
			, max(Date) as Date
			, max(population) as Population
			, max(total_cases) as Total_cases
			, max(Total_deaths) as Total_Deaths
			--, max(Total_Deaths/Total_cases * 100) as DeathRatePerTotalCases
	from CTE_cumulative_total_deaths
	--where location = 'Thailand' --for testing if the calculation is right.
	group by location, continent
GO
select top (20) *
		, cast(Total_Deaths/Total_cases * 100 as decimal(6,4))as DeathRatePerTotalCases
from VwCTE_DeathRatePerCases
order by DeathRatePerTotalCases DESC


--Show highest deaths of each country
select location, continent, population
		,max(convert(int, new_deaths)) as HighestNewDeaths
from Covid19Project..CovidCases
where continent IS NOT NULL AND
		new_deaths IS NOT NULL
group by location, continent, population
order by HighestNewDeaths DESC



/*******************************************************************************/

--Now, let's look at the other table, CovidVaccinations

select * from Covid19Project..CovidVaccinations

--View table with some useful fields
select location, continent, cast(date as date) as Date, total_tests
		, new_tests, total_vaccinations, new_vaccinations, people_vaccinated, people_fully_vaccinated
from Covid19Project..CovidVaccinations
order by 1


--Shows cumulative total tests from new tests day by day 
select c.location, c.date, c.population, cast(v.new_tests as int) as New_tests
		, sum(convert(int,v.new_tests)) over(partition by c.location order by c.date) as Total_tests
from Covid19Project..CovidCases as c
join Covid19Project..CovidVaccinations as v
on c.location = v.location
	and c.date = v.date
where c.continent is not null

-- CTE: shows total tests per population of each country --
GO
with CTE_cumulative_total_tests as
(
select c.location, c.date, c.population, cast(v.new_tests as int) as New_tests
	, sum(convert(int,v.new_tests)) over(partition by c.location order by c.date) as Total_tests
from Covid19Project..CovidCases as c
join Covid19Project..CovidVaccinations as v
on c.location = v.location
	and c.date = v.date
where c.continent is not null
)
select location, population, Total_tests, Total_tests/population * 100 as TotalTestsPerPopulation
from CTE_cumulative_total_tests
where date = '2021-12-28'
order by population DESC


--Shows cumulative total vaccinations from new vaccinations day by day 
select c.location, cast(c.date as date) as Date, c.population
		, cast(new_vaccinations as int) as New_vaccinations
		, sum(cast(new_vaccinations as bigint)) over(partition by c.location order by c.date) 
			as Cumulative_vaccinations
from Covid19Project..CovidCases as c
join Covid19Project..CovidVaccinations as v
on c.location = v.location 
	and c.date = v.date
where c.continent is not null
order by c.location, c.date

--Create temp table
USE Covid19Project
drop table if exists #temp_vaccinations

CREATE table #temp_vaccinations 
(
Location nvarchar(255),
Date date,
Population decimal,
New_vaccinations decimal,
Cumulative_vaccinations decimal
)

--Insert data from existing table into temp table 
insert into #temp_vaccinations
select c.location, cast(c.date as date) as Date, c.population
		, cast(new_vaccinations as int) as New_vaccinations
		, sum(cast(new_vaccinations as bigint)) over(partition by c.location order by c.date) 
			as Cumulative_vaccinations
from Covid19Project..CovidCases as c
join Covid19Project..CovidVaccinations as v
on c.location = v.location 
	and c.date = v.date
where c.continent is not null

/*select * from #temp_vaccinations*/

select Location, max(Date) as Date, Population, max(Cumulative_vaccinations) as Cumulative_vaccinations
		, max(cast((Cumulative_vaccinations/Population * 100) as decimal(6,3))) as VaccinationRatePerPop
from #temp_vaccinations
where Cumulative_vaccinations is not null
group by Location, Population
order by Location


--Death rate VS Vaccination rate
with CTE_DeathRateVSVaccRate as
(
select c.location, c.continent, c.population
		, cast(max(c.date) as date) as Date
		, max(total_cases) as Total_cases
		, max(cast(total_deaths as int)) as Total_Deaths
		--, cast(max(cast(total_deaths as int)/total_cases *100) as decimal(8,5)) as DeathRatePerTotalCases
		, max(cast(total_vaccinations as bigint)) as Total_Vaccinations
		, convert(decimal(8,5),max((convert(bigint, total_vaccinations))/c.population *100)) as VaccinationRatePerPop
from Covid19Project..CovidCases as c
join Covid19Project..CovidVaccinations as v
on c.location = v.location and c.date = v.date
where c.continent IS NOT NULL --To eliminate sum data
group by c.location, c.continent, c.population
--order by c.population DESC
)
select location, continent, population, Date, Total_cases, Total_Deaths
		, cast(total_deaths/total_cases *100 as decimal(8,5)) as DeathRatePerTotalCases
		, Total_Vaccinations
		, VaccinationRatePerPop
from CTE_DeathRateVSVaccRate

