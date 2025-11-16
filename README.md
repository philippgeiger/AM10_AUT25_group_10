### AM10 AUT25 - Group 10

# Data Visualisation

**Important**: To access the dataset used in this project, please go to https://londonbusinessschool1000-my.sharepoint.com/:f:/g/personal/pgeiger_mam2026_london_edu/Ep8BeiFP83JMkbdCynExl9ABeffSvXTXG4st5gtdBr9MCw?e=IpEra5 to get the files.

### Dataset

The dataset we have chosen to analyse comes from https://www.kaggle.com/datasets/davidcariboo/player-scores?resource=download. It contains a lot of historical and current information about football in Europe, including data on matches, players, valuations, teams, formations, and leagues. From this data, we can easily analyse performance and team tactics, among other things.

### Preparing the dataset

This dataset comes in the form of several tables in the form of CSV files. First, we cleaned the data by removing unusable data (e.g., blank rows) and making sure each table has a unique private key. Next, we created a .db file from these tables to bring the data into one source, allowing us to formally define the connections of the tables and write SQL queries for our analyses. Below is an image of the schema. Please note that not all tables were used for this analyis. 

 ![Database Schema](/database_schema.png)

### The project

The main points of this dataset we have chosen to analyse are the teams, their formations, the development of their formations over time, the venues of their matches, and the results of their games. 

We created four key questions to answer with our visualisations of this dataset:

1. Which formations perform best?
2. Is there an evolution in favoured formations?
3. Do budgets change tactical choices?
4. Does cross-league contagion exist?
5. Do team formations change depending on where they play?
