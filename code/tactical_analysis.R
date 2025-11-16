# ============================================================================
# Home vs Away Tactical Setup Analysis - R Script Version
# Study Group 10: Neha, Ediz, Amy, Philippe, Sarah, Kinson
# ============================================================================

# Load required libraries
library(tidyverse)
library(tidytext)

# Load core data
games       <- read_csv("games.csv")
club_games  <- read_csv("club_games.csv")
lineups     <- read_csv("game_lineups.csv")

# Top 5 European leagues (full names)
top5 <- c("Premier League", "La Liga", "Serie A", "Ligue 1", "Bundesliga")

# Recode competition IDs
league_names <- c(
  "ES1" = "La Liga",
  "FR1" = "Ligue 1",
  "GB1" = "Premier League",
  "IT1" = "Serie A",
  "L1"  = "Bundesliga"
)

games$competition_id <- league_names[games$competition_id]

# ============================================================================
# GRAPH 1: Formation Comparison
# ============================================================================

# Filtering only top 5 leagues & reshape
formations_long <- games %>%
  filter(competition_id %in% top5,
         competition_type == "domestic_league") %>%
  pivot_longer(
    cols = c(home_club_formation, away_club_formation),
    names_to = "venue",
    values_to = "formation"
  ) %>%
  mutate(
    is_home = if_else(venue == "home_club_formation", "Home", "Away")
  ) %>%
  filter(!is.na(formation))

# Computing formation frequency per league
formation_freq <- formations_long %>%
  count(competition_id, formation, sort = TRUE)

# Keeping Top 10 formations per league
top_formations <- formation_freq %>%
  group_by(competition_id) %>%
  slice_max(n, n = 10) %>%
  ungroup()

formations_filtered <- formations_long %>%
  inner_join(top_formations, by = c("competition_id", "formation"))

# Compute share per formation
formation_share <- formations_filtered %>%
  group_by(competition_id, is_home, formation) %>%
  summarise(n = n(), .groups = "drop") %>%
  group_by(competition_id) %>%
  mutate(pct = n / sum(n)) %>%
  ungroup()

# Ordering formations by home usage
formation_order <- formation_share %>%
  filter(is_home == "Home") %>%
  group_by(competition_id) %>%
  arrange(desc(pct)) %>%
  mutate(order = row_number())

formation_share <- formation_share %>%
  left_join(formation_order %>% select(competition_id, formation, order),
            by = c("competition_id", "formation"))

# Plot
graph1 <- ggplot(formation_share,
                 aes(x = reorder_within(formation, pct, competition_id),
                     y = ifelse(is_home == "Home", pct, -pct),
                     fill = is_home)) +
  geom_col(width = 0.75, alpha = 0.85) +
  coord_flip() +
  scale_x_reordered() +
  scale_y_continuous(labels = abs) +
  facet_wrap(~ competition_id, scales = "free_y") +
  scale_fill_manual(
    name = "Match Location",
    values = c("Home" = "#1A73E8", "Away" = "#DB4437")
  ) +
  labs(
    title = "Home Teams Prefer More Attacking Formations Across Europe's Top 5 Leagues",
    subtitle = "Home = blue bars (right) | Away = red bars (left)",
    x = "Formation",
    y = "Share of Matches (Home Right | Away Left)"
  ) +
  theme_minimal(base_size = 14)

print(graph1)

# ============================================================================
# GRAPH 2: Defensive Evolution Over Time
# ============================================================================

extract_defenders <- function(f) {
  as.numeric(strsplit(f, "-", fixed = TRUE)[[1]][1])
}

# Vectorised version
extract_def_vec <- function(x) {
  sapply(x, function(f) {
    if (is.na(f)) return(NA_real_)
    extract_defenders(f)
  })
}

team_games_2 <- games %>%
  filter(competition_id %in% top5,
         competition_type == "domestic_league") %>%
  mutate(
    competition_id = recode(competition_id,
                            "ES1" = "La Liga",
                            "FR1" = "Ligue 1",
                            "GB1" = "Premier League",
                            "IT1" = "Serie A",
                            "L1"  = "Bundesliga")
  ) %>%
  pivot_longer(
    cols = c(home_club_formation, away_club_formation),
    names_to = "venue",
    values_to = "formation"
  ) %>%
  mutate(
    is_home   = if_else(venue == "home_club_formation", "Home", "Away"),
    defenders = extract_def_vec(formation)
  ) %>%
  filter(!is.na(defenders))

defenders_time <- team_games_2 %>%
  group_by(competition_id, season, is_home) %>%
  summarise(
    avg_def = mean(defenders, na.rm = TRUE),
    .groups = "drop"
  )

graph2 <- ggplot(defenders_time,
                 aes(x = season, y = avg_def, color = is_home)) +
  geom_line(size = 1) +
  facet_wrap(~ competition_id, scales = "free_x") +
  scale_x_continuous(
    breaks = seq(min(defenders_time$season), max(defenders_time$season), by = 5)
  ) +
  scale_color_manual(
    name = "Match Location",
    values = c("Home" = "#1A73E8", "Away" = "#DB4437"),
    labels = c("Away", "Home")
  ) +
  labs(
    title = "The Modern Game Is Getting Braver: Fewer Defenders, More Fluid Structures Across The Board",
    subtitle = "Home vs Away | Domestic league matches in Europe's Top 5 leagues",
    x = "Season",
    y = "Average Number of Defenders"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    legend.position = "top",
    strip.text = element_text(face = "bold", size = 14),
    plot.title.position = "plot",
    plot.title = element_text(hjust = 0.5, size = 18, face = "bold"),
    plot.subtitle = element_text(size = 13, color = "grey30")
  )

print(graph2)

# ============================================================================
# GRAPH 3: Risk vs Reward
# ============================================================================

# Attaching league + season to club_games
cg_merged <- club_games %>%
  left_join(
    games %>%
      select(game_id, competition_id, season),
    by = "game_id"
  ) %>%
  filter(competition_id %in% top5) %>%
  mutate(
    competition_id = recode(competition_id,
                            "ES1" = "La Liga",
                            "FR1" = "Ligue 1",
                            "GB1" = "Premier League",
                            "IT1" = "Serie A",
                            "L1"  = "Bundesliga")
  )

risk_reward <- cg_merged %>%
  mutate(
    hosting = recode(hosting,
                     "h" = "Home",
                     "a" = "Away",
                     "home" = "Home",
                     "away" = "Away")
  ) %>%
  group_by(competition_id, season, hosting) %>%
  summarise(
    avg_goals_for     = mean(own_goals, na.rm = TRUE),
    avg_goals_against = mean(opponent_goals, na.rm = TRUE),
    n_matches         = n(),
    .groups           = "drop"
  )

graph3 <- ggplot(risk_reward,
                 aes(x = avg_goals_against,
                     y = avg_goals_for,
                     color = hosting)) +
  geom_point(alpha = 0.8, size = 4) +
  facet_wrap(~ competition_id) +
  scale_color_manual(
    name = "Match Location",
    values = c("Home" = "#1A73E8", "Away" = "#DB4437"),
    labels = c("Away", "Home")
  ) +
  labs(
    title = "Risk vs Reward: Home Teams Attack More and Concede Less Across Every Major European League",
    subtitle = "Each point = league-season-hosting | Home (blue) scores more & concedes less | Away (red) scores less & concedes more",
    x = "Average Goals Conceded (Risk)",
    y = "Average Goals Scored (Reward)",
    color = "Venue"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    legend.position = "top",
    strip.text = element_text(face = "bold", size = 14),
    plot.title.position = "plot",
    plot.title = element_text(hjust = 0.5, size = 18, face = "bold"),
    plot.subtitle = element_text(size = 13, color = "grey30")
  )

print(graph3)

# ============================================================================
# GRAPH 4: Starting XI Structure
# ============================================================================

# Keeping only starting XIs
starters <- lineups %>%
  filter(type == "starting_lineup") %>%
  select(game_id, club_id, player_id, position)

# Mapping detailed positions → DEF / MID / FWD / GK
categorize_pos <- function(p) {
  p <- tolower(p)
  
  case_when(
    str_detect(p, "goalkeeper") ~ "GK",
    str_detect(p, "back") |
      str_detect(p, "defender") |
      str_detect(p, "sweeper") |
      str_detect(p, "wing-back") ~ "DEF",
    str_detect(p, "midfield") ~ "MID",
    str_detect(p, "winger") |
      str_detect(p, "striker") |
      str_detect(p, "forward") |
      str_detect(p, "attack") ~ "FWD",
    TRUE ~ "OTHER"
  )
}

starters <- starters %>%
  mutate(position_group = categorize_pos(position))

# Building team-game table (home/away info)
team_games_4 <- games %>%
  filter(competition_id %in% top5,
         competition_type == "domestic_league") %>%
  mutate(
    competition_id = recode(competition_id,
                            "ES1" = "La Liga",
                            "FR1" = "Ligue 1",
                            "GB1" = "Premier League",
                            "IT1" = "Serie A",
                            "L1"  = "Bundesliga")
  ) %>%
  select(game_id, competition_id, home_club_id, away_club_id) %>%
  pivot_longer(
    cols = c(home_club_id, away_club_id),
    names_to = "venue",
    values_to = "club_id"
  ) %>%
  mutate(is_home = if_else(venue == "home_club_id", "Home", "Away"))

# Merging lineups with home/away + league
merged_4 <- team_games_4 %>%
  left_join(starters, by = c("game_id", "club_id")) %>%
  filter(!is.na(position_group))

# Counting players per game + position group, then average
structure <- merged_4 %>%
  group_by(competition_id, is_home, game_id, position_group) %>%
  summarise(n_players = n(), .groups = "drop") %>%
  group_by(competition_id, is_home, position_group) %>%
  summarise(avg_players = mean(n_players), .groups = "drop")

# Focusing on DEF, MID, FWD
structure_plot <- structure %>%
  filter(position_group %in% c("DEF","MID","FWD")) %>%
  mutate(
    position_group = factor(position_group, levels = c("DEF","MID","FWD")),
    is_home        = factor(is_home, levels = c("Home","Away"))
  )

graph4 <- ggplot(structure_plot,
                 aes(x = is_home, y = position_group, fill = avg_players)) +
  geom_tile(color = "white") +
  facet_wrap(~ competition_id) +
  scale_fill_gradientn(
    colours = c("#FFF3B0", "#F9A03F", "#D1495B"),
    name = "Avg Players"
  ) +
  labs(
    title = "Teams Rarely Change Their Structural Lineup When Playing Away",
    subtitle = "Average number of defenders, midfielders, and forwards | Top 5 European leagues",
    x = "Venue",
    y = "Position Group",
    fill = "Avg Players"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid = element_blank(),
    strip.text = element_text(face = "bold", size = 14),
    plot.title.position = "plot",
    plot.title = element_text(hjust = 0.5, size = 18, face = "bold"),
    plot.subtitle = element_text(size = 13, color = "grey30")
  )

print(graph4)

# ============================================================================
# SUMMARY
# ============================================================================

cat("\n")
cat("============================================================================\n")
cat("ANALYSIS COMPLETE\n")
cat("============================================================================\n")
cat("\n")
cat("All 4 graphs have been generated:\n")
cat("  1. Formation Comparison (Home vs Away)\n")
cat("  2. Defensive Evolution Over Time\n")
cat("  3. Risk vs Reward Scatterplot\n")
cat("  4. Starting XI Structure Heatmap\n")
cat("\n")
cat("Key Finding:\n")
cat("Home vs away tactical setups differ meaningfully in formation choice\n")
cat("and match behaviour, but not in the number of players assigned to\n")
cat("defensive, midfield, or forward roles.\n")
cat("============================================================================\n")