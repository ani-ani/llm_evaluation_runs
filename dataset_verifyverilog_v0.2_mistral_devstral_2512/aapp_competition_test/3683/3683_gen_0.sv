module miniature_golf_rank(
  input clk,
  input rst_n,
  input start,
  input [2:0] p,
  input [2:0] h,
  input [3:0] score_addr,
  input [7:0] score_in,
  input score_write,
  output reg [2:0] result_addr,
  output reg [2:0] result_data,
  output reg result_valid,
  output reg busy
);

  // Internal memory for scores (4 players * 4 holes)
  reg [7:0] score_mem [0:15];
  
  // State machine
  localparam [1:0] IDLE = 2'b00;
  localparam [1:0] LOAD = 2'b01;
  localparam [1:0] PROCESS = 2'b10;
  localparam [1:0] DONE = 2'b11;
  reg [1:0] state, next_state;
  
  // Processing variables
  reg [7:0] unique_scores [0:15];
  reg [3:0] unique_count;
  reg [7:0] current_l;
  reg [3:0] l_index;
  reg [3:0] player_index;
  reg [3:0] hole_index;
  reg [15:0] total_scores [0:3];
  reg [2:0] current_ranks [0:3];
  reg [2:0] best_ranks [0:3];
  reg [3:0] l_counter;
  reg [3:0] player_counter;
  reg [3:0] hole_counter;
  reg [3:0] rank_counter;
  reg [3:0] compare_counter;
  reg [3:0] temp_rank;
  reg [3:0] temp_count;
  
  // Control signals
  reg processing_done;
  reg rank_calc_done;
  reg l_processing_done;
  
  // Initialize best ranks to maximum (4)
  integer i;
  initial begin
    for (i = 0; i < 4; i = i + 1) begin
      best_ranks[i] = 3'b100;
    end
  end
  
  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      busy <= 1'b0;
      result_valid <= 1'b0;
      result_addr <= 3'b0;
      result_data <= 3'b0;
      l_index <= 0;
      player_index <= 0;
      hole_index <= 0;
      processing_done <= 1'b0;
      rank_calc_done <= 1'b0;
      l_processing_done <= 1'b0;
      l_counter <= 0;
      player_counter <= 0;
      hole_counter <= 0;
      rank_counter <= 0;
      compare_counter <= 0;
      temp_rank <= 0;
      temp_count <= 0;
    end else begin
      state <= next_state;
    end
  end
  
  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start && !score_write) begin
          next_state = LOAD;
          busy = 1'b1;
        end
      end
      LOAD: begin
        if (l_index == unique_count) begin
          next_state = PROCESS;
        end
      end
      PROCESS: begin
        if (processing_done) begin
          next_state = DONE;
          busy = 1'b0;
        end
      end
      DONE: begin
        if (!start) begin
          next_state = IDLE;
          result_valid = 1'b0;
        end
      end
    endcase
  end
  
  // Load scores into memory
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset handled in state machine
    end else if (state == LOAD && score_write) begin
      score_mem[score_addr] <= score_in;
    end
  end
  
  // Extract unique scores
  always @(posedge clk) begin
    if (!rst_n) begin
      unique_count <= 0;
      for (i = 0; i < 16; i = i + 1) begin
        unique_scores[i] <= 0;
      end
    end else if (state == LOAD && !score_write && start) begin
      // Simple unique score extraction (not optimal but works for small p*h)
      reg [7:0] temp_unique [0:15];
      reg [3:0] temp_count;
      integer j, k;
      reg found;
      
      temp_count = 0;
      for (j = 0; j < p*h; j = j + 1) begin
        found = 1'b0;
        for (k = 0; k < temp_count; k = k + 1) begin
          if (temp_unique[k] == score_mem[j]) begin
            found = 1'b1;
          end
        end
        if (!found && temp_count < 16) begin
          temp_unique[temp_count] = score_mem[j];
          temp_count = temp_count + 1;
        end
      end
      
      // Sort unique scores (bubble sort for simplicity)
      reg [7:0] temp;
      integer m, n;
      for (m = 0; m < temp_count; m = m + 1) begin
        for (n = m + 1; n < temp_count; n = n + 1) begin
          if (temp_unique[m] > temp_unique[n]) begin
            temp = temp_unique[m];
            temp_unique[m] = temp_unique[n];
            temp_unique[n] = temp;
          end
        end
      end
      
      // Store sorted unique scores
      for (i = 0; i < 16; i = i + 1) begin
        if (i < temp_count) begin
          unique_scores[i] <= temp_unique[i];
        end else begin
          unique_scores[i] <= 0;
        end
      end
      unique_count <= temp_count;
      next_state = PROCESS;
    end
  end
  
  // Processing state: iterate through l values
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset handled in state machine
    end else if (state == PROCESS) begin
      if (!l_processing_done) begin
        // Initialize total scores
        if (l_counter == 0) begin
          for (i = 0; i < 4; i = i + 1) begin
            total_scores[i] <= 0;
          end
        end
        
        // Process current l value
        if (player_counter < p && hole_counter < h) begin
          // Calculate adjusted score
          reg [7:0] adjusted_score;
          integer addr = player_counter * h + hole_counter;
          adjusted_score = (score_mem[addr] < current_l) ? score_mem[addr] : current_l;
          
          // Accumulate total score
          total_scores[player_counter] <= total_scores[player_counter] + adjusted_score;
          
          // Move to next hole or player
          if (hole_counter == h - 1) begin
            hole_counter <= 0;
            player_counter <= player_counter + 1;
          end else begin
            hole_counter <= hole_counter + 1;
          end
        end else if (rank_counter < p) begin
          // Calculate ranks
          temp_count = 0;
          for (i = 0; i < p; i = i + 1) begin
            if (total_scores[i] < total_scores[rank_counter]) begin
              temp_count = temp_count + 1;
            end
          end
          current_ranks[rank_counter] <= temp_count + 1;
          
          // Update best ranks
          if (current_ranks[rank_counter] < best_ranks[rank_counter]) begin
            best_ranks[rank_counter] <= current_ranks[rank_counter];
          end
          
          rank_counter <= rank_counter + 1;
        end else begin
          // Move to next l value
          l_counter <= l_counter + 1;
          if (l_counter < unique_count + 1) begin
            current_l <= (l_counter < unique_count) ? unique_scores[l_counter] : 8'hFF;
            player_counter <= 0;
            hole_counter <= 0;
            rank_counter <= 0;
          end else begin
            l_processing_done <= 1'b1;
            processing_done <= 1'b1;
          end
        end
      end
    end
  end
  
  // Output results
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset handled in state machine
    end else if (state == DONE) begin
      result_valid <= 1'b1;
      if (result_addr < p) begin
        result_data <= best_ranks[result_addr];
      end
    end else begin
      result_valid <= 1'b0;
    end
  end
  
  // Initialize current_l for first iteration
  always @(posedge clk) begin
    if (!rst_n) begin
      current_l <= 0;
    end else if (state == PROCESS && l_counter == 0) begin
      current_l <= (unique_count > 0) ? unique_scores[0] : 8'hFF;
    end
  end
  
  // Set busy signal
  always @(posedge clk) begin
    if (!rst_n) begin
      busy <= 1'b0;
    end else begin
      busy <= (state != IDLE && state != DONE);
    end
  end

endmodule