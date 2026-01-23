module reality_show (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [2:0] l_i,
  input [12:0] s_i,
  input [12:0] c_v,
  input valid_i,
  input done_i,
  output reg [15:0] max_profit,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    SELECT,
    FIGHT,
    UPDATE,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [15:0] current_profit;
  reg [15:0] temp_profit;
  reg [15:0] best_profit;
  reg [2:0] candidate_count;
  reg [2:0] current_level;
  reg [2:0] level_count [0:15]; // Count per level (0 unused)
  reg [2:0] temp_level_count [0:15];
  reg [2:0] candidate_index;
  reg [2:0] fight_level;
  reg [2:0] carry;
  reg [2:0] temp_carry;
  reg accept_candidate;
  reg [2:0] cycle_count;

  // Initialize state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      max_profit <= 16'd0;
      done <= 1'b0;
      current_profit <= 16'd0;
      best_profit <= 16'd0;
      candidate_count <= 3'd0;
      candidate_index <= 3'd0;
      cycle_count <= 3'd0;
      for (int i = 0; i < 16; i++) begin
        level_count[i] <= 3'd0;
        temp_level_count[i] <= 3'd0;
      end
    end else begin
      current_state <= next_state;
    end
  end

  // State machine logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = SELECT;
          current_profit = 16'd0;
          best_profit = 16'd0;
          candidate_count = 3'd0;
          candidate_index = 3'd0;
          cycle_count = 3'd0;
          for (int i = 0; i < 16; i++) begin
            level_count[i] = 3'd0;
          end
        end
      end

      SELECT: begin
        if (valid_i) begin
          // Try accepting candidate
          temp_profit = current_profit - s_i;
          temp_level_count[l_i] = level_count[l_i] + 1;
          next_state = FIGHT;
          accept_candidate = 1'b1;
        end else if (done_i) begin
          next_state = DONE;
        end
      end

      FIGHT: begin
        // Process fights iteratively
        fight_level = 1'b1;
        carry = 3'd0;
        while (fight_level < 16) begin
          temp_carry = level_count[fight_level] + carry;
          if (temp_carry >= 2) begin
            carry = temp_carry / 2;
            level_count[fight_level] = temp_carry % 2;
          end else begin
            carry = 3'd0;
            level_count[fight_level] = temp_carry;
          end
          fight_level = fight_level + 1;
        end
        next_state = UPDATE;
      end

      UPDATE: begin
        // Calculate profit from fights
        temp_profit = temp_profit + (c_v * level_count[current_level]);
        if (temp_profit > best_profit) begin
          best_profit = temp_profit;
        end
        candidate_index = candidate_index + 1;
        if (candidate_index < n) begin
          next_state = SELECT;
        end else begin
          next_state = DONE;
        end
      end

      DONE: begin
        max_profit = best_profit;
        done = 1'b1;
        next_state = IDLE;
      end
    endcase
  end

  // Cycle counter for constraint
  always @(posedge clk) begin
    if (current_state != IDLE && current_state != DONE) begin
      cycle_count <= cycle_count + 1;
      if (cycle_count == 255) begin
        next_state = DONE;
      end
    end else begin
      cycle_count <= 3'd0;
    end
  end

endmodule