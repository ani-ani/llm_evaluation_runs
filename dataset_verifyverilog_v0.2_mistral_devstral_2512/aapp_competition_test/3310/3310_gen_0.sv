module restaurant_occupancy (
  input clk,
  input rst_n,
  input start,
  input [2:0] n_in,
  input [2:0] t_in,
  input [2:0] g_in,
  input [7:0] capacity_0,
  input [7:0] capacity_1,
  input [7:0] capacity_2,
  input [7:0] capacity_3,
  input [7:0] capacity_4,
  input [7:0] capacity_5,
  input [7:0] capacity_6,
  input [7:0] capacity_7,
  output reg [31:0] expected_occupancy,
  output reg done
);

  // State definitions
  localparam [2:0] IDLE = 3'b000;
  localparam [2:0] INIT = 3'b001;
  localparam [2:0] COMPUTE_PROB = 3'b010;
  localparam [2:0] UPDATE_EXPECTATION = 3'b011;
  localparam [2:0] DONE = 3'b100;

  // DP table: 256 states (8 tables), 9 hours (0-8)
  reg [31:0] prob [0:8][0:255]; // Q16.16 probabilities
  reg [31:0] exp_occupancy [0:8][0:255]; // Q16.16 expected occupancy

  // State machine
  reg [2:0] state = IDLE;
  reg [2:0] current_hour = 0;
  reg [7:0] current_state = 0;
  reg [2:0] current_group_size = 0;

  // Counters
  reg [7:0] state_counter = 0;
  reg [2:0] hour_counter = 0;
  reg [2:0] group_counter = 0;

  // Temporary registers
  reg [31:0] temp_prob;
  reg [31:0] temp_exp;
  reg [7:0] temp_capacity [0:7];
  reg [7:0] temp_group_size;
  reg [7:0] temp_table_index;
  reg found_table;

  // Initialize capacities
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      temp_capacity[0] <= 8'd0;
      temp_capacity[1] <= 8'd0;
      temp_capacity[2] <= 8'd0;
      temp_capacity[3] <= 8'd0;
      temp_capacity[4] <= 8'd0;
      temp_capacity[5] <= 8'd0;
      temp_capacity[6] <= 8'd0;
      temp_capacity[7] <= 8'd0;
    end else begin
      temp_capacity[0] <= capacity_0;
      temp_capacity[1] <= capacity_1;
      temp_capacity[2] <= capacity_2;
      temp_capacity[3] <= capacity_3;
      temp_capacity[4] <= capacity_4;
      temp_capacity[5] <= capacity_5;
      temp_capacity[6] <= capacity_6;
      temp_capacity[7] <= capacity_7;
    end
  end

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_hour <= 0;
      current_state <= 0;
      current_group_size <= 0;
      state_counter <= 0;
      hour_counter <= 0;
      group_counter <= 0;
      done <= 0;
      expected_occupancy <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT;
          end
        end
        INIT: begin
          // Initialize DP table for hour 0
          prob[0][0] <= 32'h10000; // Q16.16: 1.0
          exp_occupancy[0][0] <= 0;
          for (integer i = 1; i < 256; i = i + 1) begin
            prob[0][i] <= 0;
            exp_occupancy[0][i] <= 0;
          end
          state <= COMPUTE_PROB;
          hour_counter <= 0;
          state_counter <= 0;
          group_counter <= 0;
        end
        COMPUTE_PROB: begin
          if (hour_counter < t_in) begin
            if (state_counter < 256) begin
              if (group_counter < g_in) begin
                // Process current group size
                temp_group_size = group_counter + 1;
                temp_prob = prob[hour_counter][state_counter];
                temp_exp = exp_occupancy[hour_counter][state_counter];

                // Find smallest unoccupied table that fits
                found_table = 0;
                temp_table_index = 0;
                for (integer i = 0; i < 8; i = i + 1) begin
                  if ((state_counter[i] == 0) && (temp_capacity[i] >= temp_group_size)) begin
                    found_table = 1;
                    temp_table_index = i;
                    break;
                  end
                end

                if (found_table) begin
                  // New state with table occupied
                  integer new_state = state_counter | (1 << temp_table_index);
                  prob[hour_counter + 1][new_state] = prob[hour_counter + 1][new_state] + (temp_prob / (g_in + 1));
                  exp_occupancy[hour_counter + 1][new_state] = exp_occupancy[hour_counter + 1][new_state] + (temp_exp / (g_in + 1)) + (temp_group_size << 16) / (g_in + 1);
                end else begin
                  // State unchanged
                  prob[hour_counter + 1][state_counter] = prob[hour_counter + 1][state_counter] + (temp_prob / (g_in + 1));
                  exp_occupancy[hour_counter + 1][state_counter] = exp_occupancy[hour_counter + 1][state_counter] + (temp_exp / (g_in + 1));
                end

                group_counter <= group_counter + 1;
              end else begin
                group_counter <= 0;
                state_counter <= state_counter + 1;
              end
            end else begin
              state_counter <= 0;
              hour_counter <= hour_counter + 1;
            end
          end else begin
            state <= UPDATE_EXPECTATION;
          end
        end
        UPDATE_EXPECTATION: begin
          // Sum all probabilities and expected values at hour t_in
          reg [31:0] total_exp = 0;
          for (integer i = 0; i < 256; i = i + 1) begin
            total_exp = total_exp + exp_occupancy[t_in][i];
          end
          expected_occupancy <= total_exp;
          state <= DONE;
          done <= 1;
        end
        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
        default: state <= IDLE;
      endcase
    end
  end

endmodule