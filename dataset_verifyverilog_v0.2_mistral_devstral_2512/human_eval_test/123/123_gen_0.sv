module odd_collatz (
  input clk,
  input rst_n,
  input start,
  input [31:0] n,
  output reg [31:0] result,
  output reg done,
  output reg [3:0] count
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    GENERATE,
    CHECK_ODD,
    SORT,
    DONE
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [31:0] current;
  reg [31:0] next_val;
  reg [3:0] step_count;
  reg [3:0] odd_count;
  reg [3:0] sort_i, sort_j;
  reg [3:0] odd_list [0:7]; // Max 8 odd numbers (4-bit each)
  reg [3:0] temp;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      count <= 0;
      current <= 0;
      next_val <= 0;
      step_count <= 0;
      odd_count <= 0;
      sort_i <= 0;
      sort_j <= 0;
      for (int k = 0; k < 8; k++) odd_list[k] <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = GENERATE;
      end
      GENERATE: begin
        if (step_count >= 32 || current == 1) next_state = SORT;
        else next_state = CHECK_ODD;
      end
      CHECK_ODD: begin
        next_state = GENERATE;
      end
      SORT: begin
        if (sort_i >= odd_count - 1) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset handled in state transition
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            current <= n;
            step_count <= 0;
            odd_count <= 0;
            for (int k = 0; k < 8; k++) odd_list[k] <= 0;
          end
        end
        GENERATE: begin
          if (step_count < 32 && current != 1) begin
            if (current[0]) begin // Odd
              next_val <= (current * 3) + 1;
            end else begin // Even
              next_val <= current >> 1;
            end
            current <= next_val;
            step_count <= step_count + 1;
          end
        end
        CHECK_ODD: begin
          if (current[0] && odd_count < 8) begin
            odd_list[odd_count] <= current[3:0]; // Store 4 LSBs
            odd_count <= odd_count + 1;
          end
        end
        SORT: begin
          // Bubble sort implementation
          if (sort_j < odd_count - sort_i - 1) begin
            if (odd_list[sort_j] > odd_list[sort_j + 1]) begin
              temp <= odd_list[sort_j];
              odd_list[sort_j] <= odd_list[sort_j + 1];
              odd_list[sort_j + 1] <= temp;
            end
            sort_j <= sort_j + 1;
          end else begin
            sort_j <= 0;
            sort_i <= sort_i + 1;
          end
        end
        DONE: begin
          // Pack results
          result <= 0;
          for (int k = 0; k < odd_count; k++) begin
            result[(k*4)+3:k*4] <= odd_list[k];
          end
          count <= odd_count;
          done <= 1;
        end
      endcase
    end
  end

endmodule