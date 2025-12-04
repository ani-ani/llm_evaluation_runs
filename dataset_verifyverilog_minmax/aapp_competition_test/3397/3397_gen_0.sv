module dog_feeding_optimizer(
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // pulse to start computation
  input [2:0] n, // number of dogs (2-4)
  input [2:0] m, // number of bowls (n <= m <= 6)
  input [7:0] eating_times_0_0, eating_times_0_1, eating_times_0_2, eating_times_0_3, eating_times_0_4, eating_times_0_5, // dog0 bowl times
  input [7:0] eating_times_1_0, eating_times_1_1, eating_times_1_2, eating_times_1_3, eating_times_1_4, eating_times_1_5, // dog1 bowl times
  input [7:0] eating_times_2_0, eating_times_2_1, eating_times_2_2, eating_times_2_3, eating_times_2_4, eating_times_2_5, // dog2 bowl times
  input [7:0] eating_times_3_0, eating_times_3_1, eating_times_3_2, eating_times_3_3, eating_times_3_4, eating_times_3_5, // dog3 bowl times
  output reg [9:0] result, // minimum total waiting time
  output reg done // high when computation completes
);

  // State machine states
  typedef enum {IDLE, PREP, EVALUATE, DONE} state_t;
  state_t state;
  
  // Internal signals
  reg [2:0] m_r, n_r;
  reg [9:0] best_T;
  reg [7:0] best_asgn [0:3];
  reg [9:0] perm_count;
  integer divs [0:3];
  reg [7:0] current_asgn [0:3];
  
  // Available arrays for assignment generation
  reg [7:0] available0 [0:5];
  reg [7:0] available1 [0:5];
  reg [7:0] available2 [0:5];
  reg [7:0] available3 [0:5];
  
  // Function to get eating time for a specific dog and bowl
  function [7:0] get_eating_time;
    input [2:0] dog;
    input [2:0] bowl;
    begin
      case (dog)
        0: begin
          case (bowl)
            0: get_eating_time = eating_times_0_0;
            1: get_eating_time = eating_times_0_1;
            2: get_eating_time = eating_times_0_2;
            3: get_eating_time = eating_times_0_3;
            4: get_eating_time = eating_times_0_4;
            5: get_eating_time = eating_times_0_5;
            default: get_eating_time = 0;
          endcase
        end
        1: begin
          case (bowl)
            0: get_eating_time = eating_times_1_0;
            1: get_eating_time = eating_times_1_1;
            2: get_eating_time = eating_times_1_2;
            3: get_eating_time = eating_times_1_3;
            4: get_eating_time = eating_times_1_4;
            5: get_eating_time = eating_times_1_5;
            default: get_eating_time = 0;
          endcase
        end
        2: begin
          case (bowl)
            0: get_eating_time = eating_times_2_0;
            1: get_eating_time = eating_times_2_1;
            2: get_eating_time = eating_times_2_2;
            3: get_eating_time = eating_times_2_3;
            4: get_eating_time = eating_times_2_4;
            5: get_eating_time = eating_times_2_5;
            default: get_eating_time = 0;
          endcase
        end
        3: begin
          case (bowl)
            0: get_eating_time = eating_times_3_0;
            1: get_eating_time = eating_times_3_1;
            2: get_eating_time = eating_times_3_2;
            3: get_eating_time = eating_times_3_3;
            4: get_eating_time = eating_times_3_4;
            5: get_eating_time = eating_times_3_5;
            default: get_eating_time = 0;
          endcase
        end
        default: get_eating_time = 0;
      endcase
    end
  endfunction
  
  // Combinational block to generate current assignment from permutation count
  always_comb begin
    // Initialize available0
    available0[0] = 0;
    available0[1] = 1;
    available0[2] = 2;
    available0[3] = 3;
    available0[4] = 4;
    available0[5] = 5;
    
    // Step 0
    integer idx0 = perm_count / divs[0];
    integer temp0 = perm_count % divs[0];
    current_asgn[0] = available0[idx0];
    
    // Generate available1 by removing selected element
    for (int i = 0; i < 6; i++) begin
      if (i < idx0) available1[i] = available0[i];
      else if (i < 5) available1[i] = available0[i+1];
    end
    
    // Step 1
    integer idx1 = temp0 / divs[1];
    integer temp1 = temp0 % divs[1];
    current_asgn[1] = available1[idx1];
    
    // Generate available2
    for (int i = 0; i < 5; i++) begin
      if (i < idx1) available2[i] = available1[i];
      else if (i < 4) available2[i] = available1[i+1];
    end
    
    // Step 2
    integer idx2 = temp1 / divs[2];
    integer temp2 = temp1 % divs[2];
    current_asgn[2] = available2[idx2];
    
    // Generate available3
    for (int i = 0; i < 4; i++) begin
      if (i < idx2) available3[i] = available2[i];
      else if (i < 3) available3[i] = available2[i+1];
    end
    
    // Step 3
    integer idx3 = temp2 / divs[3];
    current_asgn[3] = available3[idx3];
  end
  
  // State machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      best_T <= 10'h3FF; // Initialize to maximum value
      done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            m_r <= m;
            n_r <= n;
            
            // Compute divisors for permutation generation
            for (int i = 0; i < 4; i++) begin
              if (n_r-1-i <= 0) begin
                divs[i] = 1;
              end else begin
                divs[i] = 1;
                for (int j = 0; j < n_r-1-i; j++) begin
                  divs[i] = divs[i] * (m_r-1-i - j);
                end
              end
            end
            
            state <= PREP;
          end
        end
        
        PREP: begin
          // Calculate total permutations
          total_perms_reg = 1;
          for (int j = 0; j < n_r; j++) begin
            total_perms_reg = total_perms_reg * (m_r - j);
          end
          
          perm_count <= 0;
          state <= EVALUATE;
        end
        
        EVALUATE: begin
          // Evaluate current assignment
          integer max_t = 0;
          integer T = 0;
          
          // Find maximum eating time
          for (int i = 0; i < n_r; i++) begin
            integer t_i = get_eating_time(i, current_asgn[i]);
            if (t_i > max_t) max_t = t_i;
          end
          
          // Calculate total waiting time
          for (int i = 0; i < n_r; i++) begin
            integer t_i = get_eating_time(i, current_asgn[i]);
            T = T + (max_t - t_i);
          end
          
          // Update best solution
          if (T < best_T) begin
            best_T = T;
            for (int i = 0; i < 4; i++) begin
              best_asgn[i] = current_asgn[i];
            end
          end
          
          // Check if all permutations processed
          if (perm_count >= total_perms_reg - 1) begin
            result <= best_T;
            state <= DONE;
          end else begin
            perm_count <= perm_count + 1;
          end
        end
        
        DONE: begin
          done <= 1'b1;
          if (!start) begin
            state <= IDLE;
            done <= 1'b0;
          end
        end
        
        default: state <= IDLE;
      endcase
    end
  end

endmodule