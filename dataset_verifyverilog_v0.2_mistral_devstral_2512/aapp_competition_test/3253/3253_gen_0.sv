module election_winner (
  input clk,
  input rst_n,
  input start,
  input [7:0] total_delegates,
  input [7:0] state_delegates_0, state_delegates_1, state_delegates_2,
  input [15:0] state_c_0, state_c_1, state_c_2,
  input [15:0] state_f_0, state_f_1, state_f_2,
  input [15:0] state_u_0, state_u_1, state_u_2,
  output reg [31:0] result,
  output reg done,
  output reg impossible
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    PARSE,
    CALCULATE_COSTS,
    SORT,
    SELECT,
    DONE
  } state_t;
  state_t current_state, next_state;

  // Internal registers
  reg [15:0] c [0:2], f [0:2], u [0:2];
  reg [7:0] delegates [0:2];
  reg [31:0] cost [0:2];
  reg [31:0] sorted_cost [0:2];
  reg [7:0] sorted_delegates [0:2];
  reg [31:0] total_cost;
  reg [7:0] total_del;
  reg [7:0] required_del;
  reg [31:0] temp;
  reg [7:0] i, j, k;
  reg [31:0] sum_delegates;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 0;
      impossible <= 0;
      result <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = PARSE;
      end
      PARSE: next_state = CALCULATE_COSTS;
      CALCULATE_COSTS: next_state = SORT;
      SORT: next_state = SELECT;
      SELECT: next_state = DONE;
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all internal registers
      for (i = 0; i < 3; i = i + 1) begin
        c[i] <= 0;
        f[i] <= 0;
        u[i] <= 0;
        delegates[i] <= 0;
        cost[i] <= 0;
        sorted_cost[i] <= 0;
        sorted_delegates[i] <= 0;
      end
      total_cost <= 0;
      total_del <= 0;
      required_del <= 0;
      sum_delegates <= 0;
      i <= 0;
      j <= 0;
      k <= 0;
    end else begin
      case (current_state)
        PARSE: begin
          // Load inputs
          c[0] <= state_c_0;
          c[1] <= state_c_1;
          c[2] <= state_c_2;
          f[0] <= state_f_0;
          f[1] <= state_f_1;
          f[2] <= state_f_2;
          u[0] <= state_u_0;
          u[1] <= state_u_1;
          u[2] <= state_u_2;
          delegates[0] <= state_delegates_0;
          delegates[1] <= state_delegates_1;
          delegates[2] <= state_delegates_2;
          
          // Calculate total delegates needed
          sum_delegates <= delegates[0] + delegates[1] + delegates[2];
          required_del <= (sum_delegates >> 1) + 1;
        end
        
        CALCULATE_COSTS: begin
          // Calculate cost for each state
          for (i = 0; i < 3; i = i + 1) begin
            if (c[i] >= f[i] + u[i]) begin
              cost[i] <= 0; // Already won
            end else begin
              temp <= (f[i] - c[i] + u[i] + 2) << 16; // Q16.16 format
              cost[i] <= temp >> 1; // Divide by 2
            end
          end
        end
        
        SORT: begin
          // Bubble sort for 3 elements (max 3 passes)
          if (i < 3) begin
            for (j = 0; j < 2 - i; j = j + 1) begin
              if (cost[j] > cost[j + 1]) begin
                // Swap costs
                temp <= cost[j];
                cost[j] <= cost[j + 1];
                cost[j + 1] <= temp;
                
                // Swap delegates
                k <= delegates[j];
                delegates[j] <= delegates[j + 1];
                delegates[j + 1] <= k;
              end
            end
            i <= i + 1;
          end else begin
            // Copy to sorted arrays
            for (j = 0; j < 3; j = j + 1) begin
              sorted_cost[j] <= cost[j];
              sorted_delegates[j] <= delegates[j];
            end
            i <= 0;
          end
        end
        
        SELECT: begin
          if (i < 3) begin
            if (total_del < required_del) begin
              total_del <= total_del + sorted_delegates[i];
              total_cost <= total_cost + sorted_cost[i];
            end
            i <= i + 1;
          end else begin
            if (total_del < required_del) begin
              impossible <= 1;
              result <= 0;
            end else begin
              impossible <= 0;
              result <= total_cost >> 8; // Divide by 256 for final scaling
            end
            done <= 1;
            i <= 0;
          end
        end
        
        DONE: begin
          if (!start) begin
            done <= 0;
            impossible <= 0;
          end
        end
      endcase
    end
  end

endmodule