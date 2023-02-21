/* import Covid Deaths and Covid Vaccinations tables from ourworldindata.org/covid-deaths and cleaned Excel files */

/* Review Data on each table */

SELECT *
FROM PortfolioProject.dbo.CovidDeaths$
WHERE continent IS NOT NULL
ORDER BY 3,4

--SELECT *
--FROM PortfolioProject.dbo.CovidVaccinations$
--ORDER BY 3,4

--select Data we are going to be using for this project

SELECT Location, date, total_cases, new_cases, total_deaths, population
FROM PortfolioProject.dbo.CovidDeaths$
ORDER BY 1,2

-- Looking at Total Cases vs Total Deaths & Exploring data for death counts per country (USA)
-- Shows chances of death if you contract COVID in your home country

SELECT Location, date, total_cases, total_deaths, (Total_deaths/total_cases)*100 AS death_percentage
FROM PortfolioProject.dbo.CovidDeaths$
WHERE location like '%states%'
ORDER BY 1,2

--Looking at total cases vs population
-- shows % of population in USA that contracted COVID

SELECT Location, date, total_cases, population, (total_cases/population)*100 AS percent_population
FROM PortfolioProject.dbo.CovidDeaths$
WHERE location = 'United States'
ORDER BY 1,2


-- Looking at what countries have the highest rates of infection per population

SELECT Location, population, MAX(total_cases) AS highest_infection_count, MAX((total_cases/population))*100 AS max_percent_population
FROM PortfolioProject.dbo.CovidDeaths$
--WHERE location = 'United States'
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY 4 DESC


-- Countries with Highest Death Count per Population

SELECT location, population, MAX(CAST(total_deaths AS int)) AS highest_death_count, MAX((total_deaths/population))*100 AS max_death_percent 
-- required to CAST total_deaths as int
FROM PortfolioProject.dbo.CovidDeaths$
--WHERE location = 'United States'
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY 3 DESC

-- Breaking down highest death count by Continent
--imperfect data... North America does not include Canada!

SELECT continent, MAX(CAST(total_deaths AS int)) AS highest_death_count
-- required to CAST total_deaths as int
FROM PortfolioProject.dbo.CovidDeaths$
--WHERE location = 'United States'
WHERE continent IS NOT NULL
GROUP BY continent
ORDER BY 2 DESC

-- Let's try something different to correct the numbers
-- Corrects North American numbers and adds "World"
-- Showing the Continents with highest death count

SELECT continent, MAX(CAST(total_deaths AS int)) AS highest_death_count
-- required to CAST total_deaths as int
FROM PortfolioProject.dbo.CovidDeaths$
--WHERE location = 'United States'
WHERE continent IS not NULL --changed from IS NOT NULL
GROUP BY continent
ORDER BY highest_death_count DESC



-- Going global! 
-- total cases and deaths by date
SELECT date, SUM(new_cases) AS total_cases, SUM(CAST(new_deaths AS int)) AS total_deaths, SUM(CAST(new_deaths AS int))/SUM(new_cases)*100 AS global_death_percentage
FROM PortfolioProject.dbo.CovidDeaths$
WHERE continent IS NOT NULL
GROUP BY date
ORDER BY 1,2

--global total numbers thru (4/30/2021)
SELECT SUM(new_cases) AS total_cases, SUM(CAST(new_deaths AS int)) AS total_deaths, SUM(CAST(new_deaths AS int))/SUM(new_cases)*100 AS global_death_percentage
FROM PortfolioProject.dbo.CovidDeaths$
WHERE continent IS NOT NULL
ORDER BY 1,2


-- Let's look at Vaccination Data

SELECT *
FROM PortfolioProject.dbo.CovidVaccinations$

-- Join death and vaccination data

SELECT *
FROM PortfolioProject.dbo.CovidDeaths$ AS deaths
JOIN PortfolioProject.dbo.CovidVaccinations$ AS vax
	ON deaths.location = vax.location
	AND deaths.date = vax.date
WHERE deaths.continent IS NOT NULL
	

	-- Look at total population vs vaccinations (new vax per day)

SELECT deaths.continent, deaths.location, deaths.date, deaths.population, vax.new_vaccinations
FROM PortfolioProject.dbo.CovidDeaths$ AS deaths
JOIN PortfolioProject.dbo.CovidVaccinations$ AS vax
	ON deaths.location = vax.location
	AND deaths.date = vax.date
WHERE deaths.continent IS NOT NULL
ORDER BY 2,3,4

-- Set up Rolling count of new vax per day
-- Partitioning by deaths.location and ordering by deaths.location and deaths.date

SELECT deaths.continent, deaths.location, deaths.date, deaths.population, vax.new_vaccinations,
	SUM(CAST(vax.new_vaccinations AS int)) OVER (PARTITION BY deaths.location ORDER BY deaths.location, deaths.date) AS vax_rolling_count--,
	--(vax_rolling_count/population)*100 AS vax_per_population (cannot use newly created column for aggregate functions! need CTE or Temp Table)
FROM PortfolioProject.dbo.CovidDeaths$ AS deaths
JOIN PortfolioProject.dbo.CovidVaccinations$ AS vax
	ON deaths.location = vax.location
	AND deaths.date = vax.date
WHERE deaths.continent IS NOT NULL
ORDER BY 2,3

-- CTE example

WITH PopvsVax (Continent, Location, Date, Population, new_vaccinations, vax_rolling_count)
AS
(
SELECT deaths.continent, deaths.location, deaths.date, deaths.population, vax.new_vaccinations,
	SUM(CAST(vax.new_vaccinations AS int)) OVER (PARTITION BY deaths.location ORDER BY deaths.location, deaths.date) AS vax_rolling_count
FROM PortfolioProject.dbo.CovidDeaths$ AS deaths
JOIN PortfolioProject.dbo.CovidVaccinations$ AS vax
	ON deaths.location = vax.location
	AND deaths.date = vax.date
WHERE deaths.continent IS NOT NULL
)

SELECT*, (vax_rolling_count/population)*100
FROM PopvsVax
--WHERE location = 'United States'

--Temp Table example

DROP Table IF EXISTS #PercentPopulationVaccinated -- useful for adjusting table
CREATE Table #PercentPopulationVaccinated
(
Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
Population numeric,
new_vaccinations numeric,
vax_rolling_count numeric
)

INSERT INTO #PercentPopulationVaccinated
SELECT deaths.continent, deaths.location, deaths.date, deaths.population, vax.new_vaccinations,
	SUM(CAST(vax.new_vaccinations AS int)) OVER (PARTITION BY deaths.location ORDER BY deaths.location, deaths.date) AS vax_rolling_count
FROM PortfolioProject.dbo.CovidDeaths$ AS deaths
JOIN PortfolioProject.dbo.CovidVaccinations$ AS vax
	ON deaths.location = vax.location
	AND deaths.date = vax.date
WHERE deaths.continent IS NOT NULL

SELECT *, (vax_rolling_count/population)*100
FROM #PercentPopulationVaccinated


-- Create Views for Tableau!

-- Percent of population vaccinated
CREATE VIEW PercentPopulationVaccinated AS
SELECT deaths.continent, deaths.location, deaths.date, deaths.population, vax.new_vaccinations,
	SUM(CAST(vax.new_vaccinations AS int)) OVER (PARTITION BY deaths.location ORDER BY deaths.location, deaths.date) AS vax_rolling_count
FROM PortfolioProject.dbo.CovidDeaths$ AS deaths
JOIN PortfolioProject.dbo.CovidVaccinations$ AS vax
	ON deaths.location = vax.location
	AND deaths.date = vax.date
WHERE deaths.continent IS NOT NULL

-- Rate of Infection per population per country

CREATE VIEW CountryInfectionRate AS
SELECT Location, population, MAX(total_cases) AS highest_infection_count, MAX((total_cases/population))*100 AS max_percent_population
FROM PortfolioProject.dbo.CovidDeaths$
--WHERE location = 'United States'
WHERE continent IS NOT NULL
GROUP BY location, population

-- Highest Death Counts per Country

CREATE VIEW CountryDeathCount AS
SELECT location, population, MAX(CAST(total_deaths AS int)) AS highest_death_count, MAX((total_deaths/population))*100 AS max_death_percent 
-- required to CAST total_deaths as int
FROM PortfolioProject.dbo.CovidDeaths$
--WHERE location = 'United States'
WHERE continent IS NOT NULL
GROUP BY location, population

-- Continental Max Death Count

CREATE VIEW ContinentDeathCount AS
SELECT continent, MAX(CAST(total_deaths AS int)) AS highest_death_count
-- required to CAST total_deaths as int
FROM PortfolioProject.dbo.CovidDeaths$
--WHERE location = 'United States'
WHERE continent IS not NULL --changed from IS NOT NULL
GROUP BY continent

-- Global deaths per date

CREATE VIEW GlobalDeathsPerDate AS
SELECT date, SUM(new_cases) AS total_cases, SUM(CAST(new_deaths AS int)) AS total_deaths, SUM(CAST(new_deaths AS int))/SUM(new_cases)*100 AS global_death_percentage
FROM PortfolioProject.dbo.CovidDeaths$
WHERE continent IS NOT NULL
GROUP BY date