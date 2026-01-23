module theorem_proof_minimizer (
  input clk,
  input rst_n,
  input start,
  input [4:0] num_theorems,
  input [5:0] proof_count [0:19],
  input [31:0] proof_length [0:199],
  input [4:0] proof_dep_count [0:199],
  input [4:0] proof_deps [0:199][0:19],
  output reg [31:0] min_length,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    LOAD_DATA,
    COMPUTE_COSTS,
    CHECK_DONE,
    OUTPUT_RESULT,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal storage for proof data
  reg [5:0] proof_count_mem [0:19];
  reg [31:0] proof_length_mem [0:199];
  reg [4:0] proof_dep_count_mem [0:199];
  reg [4:0] proof_deps_mem [0:199][0:19];

  // DP array for minimum costs
  reg [31:0] cost [0:19];

  // Counters and control signals
  reg [4:0] theorem_counter;
  reg [8:0] proof_counter;
  reg [4:0] dep_counter;
  reg [31:0] current_cost;
  reg [31:0] sum_deps;
  reg [31:0] temp_cost;
  reg [31:0] min_temp;
  reg cycle_detected;
  reg [4:0] cycle_check_counter;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 0;
      min_length <= 0;
      theorem_counter <= 0;
      proof_counter <= 0;
      dep_counter <= 0;
      current_cost <= 0;
      sum_deps <= 0;
      temp_cost <= 0;
      min_temp <= 0;
      cycle_detected <= 0;
      cycle_check_counter <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = LOAD_DATA;
      end
      LOAD_DATA: begin
        if (theorem_counter == num_theorems - 1 && proof_counter == proof_count[num_theorems - 1] - 1) begin
          next_state = COMPUTE_COSTS;
        end
      end
      COMPUTE_COSTS: begin
        if (theorem_counter == num_theorems - 1 && proof_counter == proof_count[theorem_counter] - 1) begin
          next_state = CHECK_DONE;
        end
      end
      CHECK_DONE: begin
        if (theorem_counter == num_theorems - 1) begin
          next_state = OUTPUT_RESULT;
        end
      end
      OUTPUT_RESULT: begin
        next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Data loading
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset internal storage
      for (int i = 0; i < 20; i++) begin
        proof_count_mem[i] <= 0;
        for (int j = 0; j < 20; j++) begin
          proof_deps_mem[i][j] <= 0;
        end
      end
      for (int i = 0; i < 200; i++) begin
        proof_length_mem[i] <= 0;
        proof_dep_count_mem[i] <= 0;
      end
    end else if (current_state == LOAD_DATA) begin
      // Load proof data
      if (proof_counter < proof_count[theorem_counter]) begin
        proof_length_mem[proof_counter] <= proof_length[proof_counter];
        proof_dep_count_mem[proof_counter] <= proof_dep_count[proof_counter];
        for (int i = 0; i < 20; i++) begin
          proof_deps_mem[proof_counter][i] <= proof_deps[proof_counter][i];
        end
        proof_counter <= proof_counter + 1;
      end else begin
        proof_counter <= 0;
        theorem_counter <= theorem_counter + 1;
      end
    end
  end

  // Cost computation
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Initialize cost array to infinity
      for (int i = 0; i < 20; i++) begin
        cost[i] <= 32'hFFFFFFFF;
      end
    end else if (current_state == COMPUTE_COSTS) begin
      // Compute cost for current theorem
      if (proof_counter < proof_count_mem[theorem_counter]) begin
        // Calculate sum of dependencies
        if (dep_counter < proof_dep_count_mem[proof_counter]) begin
          if (proof_deps_mem[proof_counter][dep_counter] != 31) begin
            sum_deps <= sum_deps + cost[proof_deps_mem[proof_counter][dep_counter]];
          end
          dep_counter <= dep_counter + 1;
        end else begin
          // Check for cycles
          cycle_detected <= 0;
          for (int i = 0; i < proof_dep_count_mem[proof_counter]; i++) begin
            if (proof_deps_mem[proof_counter][i] == theorem_counter) begin
              cycle_detected <= 1;
            end
          end

          if (!cycle_detected) begin
            temp_cost <= proof_length_mem[proof_counter] + sum_deps;
            if (temp_cost < cost[theorem_counter]) begin
              cost[theorem_counter] <= temp_cost;
            end
          end

          // Reset for next proof
          sum_deps <= 0;
          dep_counter <= 0;
          proof_counter <= proof_counter + 1;
        end
      end else begin
        // Move to next theorem
        proof_counter <= 0;
        theorem_counter <= theorem_counter + 1;
      end
    end
  end

  // Check done
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset
    end else if (current_state == CHECK_DONE) begin
      if (theorem_counter < num_theorems) begin
        theorem_counter <= theorem_counter + 1;
      end
    end
  end

  // Output result
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      min_length <= 0;
    end else if (current_state == OUTPUT_RESULT) begin
      min_length <= cost[0];
      done <= 1;
    end else if (current_state == DONE) begin
      if (!start) begin
        done <= 0;
      end
    end
  end

endmodule