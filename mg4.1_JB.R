# mg4.1
# Jen Bradham, Clara Yip, Max Guillet

# move_grid : holds the number of times a peccary has crossed each space
# forest_id_grid : tracks forest id
# energy_grid : holds the amount of energy at each cell

# x_length        : x size of grid
# y_length        : y size of grid
# count_forest    : number of forests
# percent_forest  : percent of grid that is forested
# steps           : number of steps for simulation to run, 1 step = 3 hours
# max_dist        : maximum distance a peccary can move in one step
# iter            : number of iterations

# description of time and space units: each cell is 30x30 meters
# each step represents 3 hours, each month contains 30 days, 360 days in a year

DRY <- 1
WET <- 2
DEPLETION_LEVEL_CUTOFF <- 60
STUCK_TIMER <- 10
MAX_CROSSING_DISTANCE <- 20 # 600 meters divided into 30x30 meter cells

simulate_movement <- function(x_length, y_length, count_forest, percent_forest, 
                             steps, max_dist, iter) {
  library(plyr)
  library(RColorBrewer)
  library(car)
  library(fields)
  library(eva)
  
  # gen_grids: Generates move_grid and forest_grid by placing forests in randomly sampled
  # coordinates. 
  gen_grids <- function() {
    for (i in 1:count_forest) {
      x <- sample(1:x_length, 1)
      y <- sample(1:y_length, 1)
      
      # check that location hasn't been set yet. if it has, find a new location
      while (!is.na(move_grid[x, y])) {
        x <- sample(1:x_length, 1)  
        y <- sample(1:y_length, 1)
      }
      
      #set move_grid to 0 (no peccary count)
      move_grid[x, y] <<- 0   
      
      #set forest_id_grid to the forest id i
      forest_id_grid[x, y] <<- i
      
      #update the forest id
      #update_forest_id(x, y)
      x_forested <<- c(x_forested, x)
      y_forested <<- c(y_forested, y)
      x_forests[[i]] <<- c(x)
      y_forests[[i]] <<- c(y)
    }
  }
  
  
  # simulate_movement peccary movement
  simulate_movement <- function() {
    start_index <- sample(1:length(x_forested), 1)
    start_x <- x_forested[start_index]
    start_y <- y_forested[start_index]
    cur_forest_id <<- forest_id_grid[start_x, start_y]
    month <- 1
    time <- 1
    depletion_level <<- 100
    depleted_counter <<- 0
    non_depleted_counter <<- 0
    stuck_counter <<- 0
    curr_consecutive_stuck_counter <<- 0
    consecutive_stuck_counter <<- c(0)
    crossed_matrix_counter <<- 0
    total_distance <<- 0
    
    for (i in 1:steps) {

      #update month every 30 days
      if(i %% 240 == 0) {
        month <- next_month(month)
      }
      # Patches are returned to, on average, every 364.5 hours, or 121 timesteps. every 30, we grow a quarter back
      if(i %% 30 == 0) {
        energy_grid <- apply(energy_grid, 1:2, restore_cell_energy)
      }
      
      direction <- sample(1:8, 1)
      dist <- calculate_walk_distance(month, depletion_level)
      path <- next_path(start_x, start_y, direction, dist)
      stuck_timer <- STUCK_TIMER
      while (is.null(path) && stuck_timer != 0) {
        direction <- sample(1:8, 1)
        dist <- calculate_walk_distance(month, depletion_level)
        path <- next_path(start_x, start_y, direction, dist)
        stuck_timer <- stuck_timer - 1
      }
      if(stuck_timer != 0) {
        end_index <- walk(path)
        start_x <- end_index[1]
        start_y <- end_index[2]
        total_distance <<- total_distance + dist
        if(curr_consecutive_stuck_counter != 0) {
          if(is.na(consecutive_stuck_counter[curr_consecutive_stuck_counter])) {
            consecutive_stuck_counter[curr_consecutive_stuck_counter] <<- 0
          }
          consecutive_stuck_counter[curr_consecutive_stuck_counter] <<- consecutive_stuck_counter[curr_consecutive_stuck_counter] + 1
          curr_consecutive_stuck_counter <<- 0
        }
      } else {
        depleted_counter <- depleted_counter + 1
        stuck_counter <<- stuck_counter + 1
        curr_consecutive_stuck_counter <<- curr_consecutive_stuck_counter + 1
      }
    }
  }

  
  # next_path: generate next path
  next_path <- function(x, y, direction, dist) {
    endpoint <- get_coor(x, y, direction, dist)
    # verify endpoint is in bounds and forested. if not forested, verify it is within view of another forest
    if (in_bounds(endpoint[1], endpoint[2]) 
        && (!is.na(move_grid[endpoint[1], endpoint[2]]) 
        || forest_in_sight(endpoint[1], endpoint[2], dist))) {
      return(get_path(x, y, direction, dist))
    }
    return(c())
  }
  
  
  # forest_in_sight: return true if there is a forest within the maximum 
  # crossing distance before a peccary decides to move.
  forest_in_sight <- function(x, y, dist_traveled) {
    max_distance_to_forest <- MAX_CROSSING_DISTANCE - dist_traveled
    for (direction in 1:8) {
      for(endpoint in get_path(x, y, direction, max_distance_to_forest)) {
        if(in_bounds(endpoint[1], endpoint[2])
           && !is.na(move_grid[endpoint[1], endpoint[2]])) {
          return(TRUE)
        }
      }
    }
    return(FALSE)
  }
  
  
  # walk: peccary walks a given path, return last endpoint
  walk <- function(path) {
    x_coors <- path[1,]
    y_coors <- path[2,]
    len <- length(x_coors)
    depletion_sum <- 0
    for (i in 1:len) {
      if ((!is.na(move_grid[x_coors[i], y_coors[i]]))) {
        move_grid[x_coors[i], y_coors[i]] <<- move_grid[x_coors[i], 
                                                        y_coors[i]] + 1
      }
      if ((!is.na(energy_grid[x_coors[i], y_coors[i]]))) {
        depletion_sum <- depletion_sum + energy_grid[x_coors[i],
                                                     y_coors[i]]
        energy_grid[x_coors[i], y_coors[i]] <<- 0
      }
      new_forest_id <- forest_id_grid[x_coors[i], y_coors[i]]
      if (new_forest_id != 0 && new_forest_id != cur_forest_id) {
        crossed_matrix_counter <<- crossed_matrix_counter + 1
        cur_forest_id <<- new_forest_id
      }
    }
    depletion_level <<- depletion_sum / len
    return(c(x_coors[len], y_coors[len]))
  }
  
  
  # in_bounds: verifies x and y coordinates are in bounds of grid
  in_bounds <- function(x, y) {
    check_x <- (x > 0) && (x <= x_length)
    check_y <- (y > 0) && (y <= y_length)
    return(check_x && check_y) 
  }

  # get_diag_dist: helper function to calculate the distance a peccary must
  # travel in each cardinal direction
  get_diag_dist <- function(distance) {
    return (round(sqrt((distance^2)/2)))
  }
  
  # get_coor: Gets the new coordinate after move (1, 3, 5, 7 = left, up, right, down)
  get_coor <- function(x, y, direction, distance) {
    if (direction %% 2 == 0) { distance = get_diag_dist(distance) }
    if (direction == 1) {
      new_coor <- c(x - distance, y)
    } else if (direction == 2) {
      new_coor <- c(x - distance, y + distance)
    } else if (direction == 3) {
      new_coor <- c(x, y + distance)
    } else if (direction == 4) {
      new_coor <- c(x + distance, y + distance)
    } else if (direction == 5) {
      new_coor <- c(x + distance, y)
    } else if (direction == 6) {
      new_coor <- c(x + distance, y - distance)
    } else if (direction == 7) {
      new_coor <- c(x, y - distance)
    } else {
      new_coor <- c(x - distance, y - distance)
    }
    return(new_coor)  
  }

  
  # update_forest_id : sets neighboring forest cells to same forest id
  update_forest_id <- function(cur_x, cur_y) {
    forest_id <- forest_id_grid[cur_x, cur_y]
    left <- get_coor(cur_x, cur_y, 1, 1)
    up <- get_coor(cur_x, cur_y, 3, 1)
    right <- get_coor(cur_x, cur_y, 5, 1)
    down <- get_coor(cur_x, cur_y, 7, 1)
    
    if (in_bounds(left[1], left[2]) && forest_id_grid[left[1], left[2]] != 0 && 
        forest_id_grid[left[1], left[2]] != forest_id) {
      forest_id_grid[left[1], left[2]] <<- forest_id
    } else if (in_bounds(up[1], up[2]) &&  forest_id_grid[up[1], up[2]] != 0 && 
               forest_id_grid[up[1], up[2]] != forest_id) {
      forest_id_grid[up[1], up[2]] <<- forest_id
    } else if (in_bounds(right[1], right[2]) && forest_id_grid[right[1], 
                                                               right[2]] != 0 &&
               forest_id_grid[right[1], right[2]] != forest_id) {
      forest_id_grid[right[1], right[2]] <<- forest_id
    } else if (in_bounds(down[1], down[2]) && forest_id_grid[down[1], down[2]] 
               != 0 && forest_id_grid[down[1], down[2]] != forest_id) {
      forest_id_grid[down[1], down[2]] <<- forest_id
    }
  }

  
  # grow_forests: grows forests until desired percent forest cover is reached
  grow_forests <- function() {
    expected_count_forest <- as.integer(percent_forest / 100 * area)
    for (i in 1:(expected_count_forest - count_forest)) {
      added <- FALSE
      while (!added) {
        index <- sample(1:length(x_forested), 1)
        x <- x_forested[index]
        y <- y_forested[index]
        direction <- sample(c(1, 3, 5, 7), 1)
        to_add <- get_coor(x, y, direction, 1)
        next_x <- to_add[1]
        next_y <- to_add[2]
        if (in_bounds(next_x, next_y) && is.na(move_grid[next_x, next_y])) {
          move_grid[next_x, next_y] <<- 0
          energy_grid[next_x, next_y] <<- 100
          
          cur_forest_id <- forest_id_grid[x,y]
          forest_id_grid[next_x, next_y] <<- cur_forest_id
          update_forest_id(next_x, next_y)
          x_forested <<- c(x_forested, next_x)
          y_forested <<- c(y_forested, next_y)
          x_forests[[cur_forest_id]] <<- c(x_forests[[cur_forest_id]], next_x)
          y_forests[[cur_forest_id]] <<- c(y_forests[[cur_forest_id]], next_y)
          added <- TRUE 
        }
      }
    }
    merge_forests()
  }
  
  
  # merge_forests: merges the forests so connected forests share the same id
  merge_forests <- function() {
    for (x in 1:x_length) {
      for(y in 1:y_length) {
        merge_direction(x, y, x + 1, y)
        merge_direction(x, y, x - 1, y)
        merge_direction(x, y, x, y - 1)
        merge_direction(x, y, x, y + 1)
      }
    }
  }
  
  
  # merge_direction: helper function for merge_forests. checks cells in the 
  # given direction to merge the forests
  merge_direction <- function (x, y, x_new, y_new) {
    cur_forest_id <- forest_id_grid[x, y]
    if(cur_forest_id != 0 && in_bounds(x_new, y_new)) {
      new_forest_id <- forest_id_grid[x_new, y_new]
      if(new_forest_id != 0 && new_forest_id != cur_forest_id) {
        for(i in x_forests[new_forest_id]) {
          for(j in y_forests[new_forest_id]) {
            forest_id_grid[i, j] <<- cur_forest_id
            x_forests[[cur_forest_id]] <<- c(x_forests[[cur_forest_id]], i)
            y_forests[[cur_forest_id]] <<- c(y_forests[[cur_forest_id]], j)
          }
        }
        x_forests[[new_forest_id]] <<- vector()
        y_forests[[new_forest_id]] <<- vector()
      }
    }
  }
  
  # get_path: returns list of cells on path
  get_path <- function(x_orig, y_orig, direction, dist) {
    x <- x_orig
    y <- y_orig
    x_path <- c(x)
    y_path <- c(y)
    if(dist == 0) {
      return(rbind(x_path, y_path))
    }
    if(direction %% 2 == 0) {
      for (i in 1:get_diag_dist(dist)) {
        directions = c()
        if(direction == 8) {
          directions = c(7, 1)
        } else {
          directions = c(direction - 1, direction + 1)
        }
        nextCoor <- get_coor(x, y, directions[1], 1)
        x <- nextCoor[1]
        y <- nextCoor[2]
        x_path <- c(x_path, x)
        y_path <- c(y_path, y)
        nextCoor <- get_coor(x, y, directions[2], 1)
        x <- nextCoor[1]
        y <- nextCoor[2]
        x_path <- c(x_path, x)
        y_path <- c(y_path, y)
      }
    } else {
      for (i in 1:dist) {
        nextCoor <- get_coor(x, y, direction, 1)
        x <- nextCoor[1]
        y <- nextCoor[2]
        x_path <- c(x_path, x)
        y_path <- c(y_path, y)
      }
    }
    return(rbind(x_path, y_path))
  }

  
  # calculate distance
  calculate_walk_distance <- function(month, depletion_level) {
    season <- calculate_season(month)
    #introduce stochasticity into depletion level cutoff
    depletion_level_cutoff<-rnorm(1,DEPLETION_LEVEL_CUTOFF,(DEPLETION_LEVEL_CUTOFF/10))
    #introduce stochasticity into threshold between short and long range steps
    threshold<-rnorm(1,494,(494/10))
    if(depletion_level < DEPLETION_LEVEL_CUTOFF) {
      depleted = TRUE
      depleted_counter <<- depleted_counter + 1
    } else {
      depleted = FALSE
      non_depleted_counter <<- non_depleted_counter + 1
    }
    if (season == 3) {
      if (!depleted) {
        # for dry season if local patches not depleted
        step <- rgpd(1,scale = 563.5,shape=-0.12)
        while(step > threshold){
          step <- rgpd(1,scale = 563.5,shape=-0.12)
        }
      } else {
        #for dry season if local patches depleted
        step <- rgpd(1,scale = 563.5,shape=-0.12)
        while(step < threshold){
          step <- rgpd(1,scale = 563.5,shape=-0.12)
        }
      }
    } else {
      if (!depleted) {
        # for wet season if local patches not depleted
        step <- rgpd(1,scale = 432.6,shape=-0.029)
        while(step > threshold){
          step <- rgpd(1,scale = 432.6,shape=-0.029)
        }
      } else {
        # for wet season if local patches depleted
        step <- rgpd(1,scale = 432.6,shape=-0.029)
        while(step < threshold){
          step <- rgpd(1,scale = 432.6,shape=-0.029)
        }
      }
    }
    
    # step is in meters / into 30x30 meter cells
    return(floor(step / 30))
  }
  
  
  #calculates dry or wet season based on month
  calculate_season <- function(month) {
    if(month < 5 || month > 10) {
      return(DRY)
    } else {
      return(WET)
    }
  }
  
  
  #restores cells 25 % at a time
  restore_cell_energy <- function(x) {
    if(is.na(x)) {
      return(NA)
    }
    sum <- x + 25
    if (sum > 100) {
      return(100)
    } else {
      return(sum)
    }
  }
  
  
  # calculate the next month
  next_month <- function(curr_month) {
    return(if(curr_month == 12) 1 else curr_month + 1)
  }
  
  
  euc_distance <- function(p1, p2) sqrt(sum((p1 - p2)^2))
  
  
  # calculate the average minimum distance between each forest
  avg_dist_forests <- function() {
    forests <- sort(unique(as.vector(forest_id_grid)))[-1]
    patch_num <- length(forests)
    total_dist <- 0
    count <- 0
    if(patch_num == 1) {
      return(0)
    }
    for(i in 1:(patch_num - 1)) {
      for(j in (i+1):patch_num) {
        forest_i <- which(forest_id_grid == i, arr.ind=TRUE)
        forest_j <- which(forest_id_grid == j, arr.ind=TRUE)
        
        # find min distance between forest_i and forest_j
        min_distance <- 999999999.0
        for(n in nrow(forest_i)) {
          for(m in nrow(forest_j)) {
            curr_distance <- euc_distance(forest_i[n,], forest_j[m,])
            if(curr_distance < min_distance) {
              min_distance <- curr_distance
            }
          }
        }
        total_dist <- (total_dist + min_distance)
        count <- count + 1
      }
    }
    min_avg_dist <- total_dist / count
  }
  
  # calculate the maximum distance between each forest
  max_dist_bw_forests <- function() {
    forests <- sort(unique(as.vector(forest_id_grid)))[-1]
    patch_num <- length(forests)
    max_dist <- -1
    count <- 0
    if(patch_num < 2) {
      return(0)
    }
    for(i in 1:(patch_num - 1)) {
      dist_to_closest_forest <- 999999999999.0
      for(j in (i+1):patch_num) {
        forest_i <- which(forest_id_grid == forests[i], arr.ind=TRUE)
        forest_j <- which(forest_id_grid == forests[j], arr.ind=TRUE)
        
        # find min distance between forest_i and forest_j
        min_distance <- 9999999999999.0
        for(i_row in 1:nrow(forest_i)) {
          for(j_row in 1:nrow(forest_j)) {
            curr_distance <- euc_distance(forest_i[i_row,], forest_j[j_row,])
            if(curr_distance < min_distance) {
              min_distance <- curr_distance
            }
          }
        }
        if(min_distance < dist_to_closest_forest) {
          dist_to_closest_forest <- min_distance
        }
      }
      if(dist_to_closest_forest > max_dist) {
        max_dist <- dist_to_closest_forest
      }
    }
    return(max_dist)
  }
  
  
  # START MODEL
  
  # generate matrices for landscape and movement
  move_grid <- matrix(NA, nrow = x_length, ncol = y_length)
  forest_id_grid <- matrix(0L, nrow = x_length, ncol = y_length)
  energy_grid <- matrix(NA, nrow = x_length, ncol = y_length)

  # generate grids
  x_forested <- vector()
  y_forested <- vector()
  x_forests <- list()
  y_forests <- list()
  gen_grids()
  
  # grow forests
  area <- x_length * y_length
  if (percent_forest > 100 || percent_forest < (count_forest / area)) {
    print("percent percent_forest invalid")
    break
  }
  grow_forests()
  
  # save & output results to file_name
  file_name <- paste("Uniform", toString(count_forest), 
                     toString(percent_forest), toString(steps), iter, sep="_")
  
  # create/save the 'before' map visual 
  grid_1 <- replace(move_grid, is.na(move_grid), -10)
  img <- image(1:x_length, 1:y_length, grid_1, col =  brewer.pal(3, "OrRd")) 
  file_name_jpg_map <- paste(file_name, "move_grid", "before", ".jpeg", sep = "")
  dev.copy(jpeg, file_name_jpg_map)
  dev.off()
  
  simulate_movement()
  # avg_dist_forests <- avg_dist_forests()
  
  max_dist_bw_forests <- max_dist_bw_forests()
  
  # create/save the 'post' map visual 
  grid_1 <- replace(move_grid, is.na(move_grid), -10)
  img <- image(1:x_length, 1:y_length, grid_1, col =  brewer.pal(9, "OrRd")) 
  file_name_jpg_map <- paste(file_name, "move_grid", "post", ".jpeg", sep = "")
  dev.copy(jpeg, file_name_jpg_map)
  dev.off()
  
  # create/save histogram recording the frequency distribution of hit cells
  hist(move_grid, freq=TRUE, xlab = "Number of times treaded", col = 
         brewer.pal(10, "Spectral"), breaks = 20,  xlim = c(0,120), 
       ylim = c(0,4000))
  file_name_jpg_hist <- paste(file_name, "hist", ".jpeg", sep = "")
  dev.copy(jpeg, file_name_jpg_hist)
  dev.off()
  
  # create/save frequency table of number of cell hits and their frequency of 
  # occurence --> *** same data as histogram uses, correct?
  max_tread <- max(move_grid, na.rm =TRUE)
  nums <- c(0:max_tread)
  freq_all <- count(as.vector(move_grid))
  freq_0 <- freq_all[1,2]
  frequencies <- c(freq_0, tabulate(as.vector(move_grid)))
  freq <- setNames(frequencies, nums)
  expected_count_forest <- as.integer(percent_forest/100 * area)
  percents <- frequencies/as.integer(expected_count_forest)
  freq = rbind(freq, percents)
  file_name_csv <- paste(file_name, "freq", ".csv", sep = "")
  write.csv(freq, file = file_name_csv)
  write.csv(consecutive_stuck_counter, file = paste("consecutive_stuck_counter.csv", percent_forest, iter, sep = "_"))
  
  #return(c(freq[2,1], crossed_matrix_counter, avg_dist_forests, total_distance, stuck_counter, max_dist_bw_forests)) 
  return(c(freq[2,1], crossed_matrix_counter, -1, total_distance, stuck_counter, max_dist_bw_forests, depleted_counter)) 
}

