module max_or_k_operations (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [3:0] k,
  input [2:0] x,
  input [31:0] a [0:7],
  output reg [31:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CALC_PREFIX,
    CALC_SUFFIX,
    CALC_MUL,
    CALC_OR,
    DONE
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [31:0] prefix [0:7];
  reg [31:0] suffix [0:7];
  reg [31:0] mul;
  reg [31:0] current_candidate;
  reg [31:0] max_candidate;
  reg [2:0] i;
  reg [2:0] j;
  reg [3:0] k_counter;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      result <= 32'b0;
      i <= 3'b0;
      j <= 3'b0;
      k_counter <= 4'b0;
      mul <= 32'b1;
      current_candidate <= 32'b0;
      max_candidate <= 32'b0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = CALC_PREFIX;
      end
      CALC_PREFIX: begin
        if (i == n - 1) next_state = CALC_SUFFIX;
      end
      CALC_SUFFIX: begin
        if (j == 0) next_state = CALC_MUL;
      end
      CALC_MUL: begin
        if (k_counter == k) next_state = CALC_OR;
      end
      CALC_OR: begin
        if (i == n - 1) next_state = DONE;
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
      // Reset handled in state machine
    end else begin
      case (state)
        CALC_PREFIX: begin
          if (i == 0) begin
            prefix[i] <= a[i];
          end else begin
            prefix[i] <= prefix[i-1] | a[i];
          end
          i <= i + 1;
        end
        CALC_SUFFIX: begin
          if (j == n - 1) begin
            suffix[j] <= a[j];
          end else begin
            suffix[j] <= suffix[j+1] | a[j];
          end
          j <= j - 1;
        end
        CALC_MUL: begin
          if (k_counter == 0) begin
            mul <= x;
          end else begin
            mul <= mul * x;
          end
          k_counter <= k_counter + 1;
        end
        CALC_OR: begin
          if (n == 1) begin
            current_candidate <= a[0] * mul;
          end else if (i == 0) begin
            current_candidate <= (a[i] * mul) | suffix[i+1];
          end else if (i == n - 1) begin
            current_candidate <= prefix[i-1] | (a[i] * mul);
          end else begin
            current_candidate <= prefix[i-1] | (a[i] * mul) | suffix[i+1];
          end
          if (current_candidate > max_candidate) begin
            max_candidate <= current_candidate;
          end
          i <= i + 1;
        end
        DONE: begin
          result <= max_candidate;
          done <= 1'b1;
        end
      endcase
    end
  end

  // Initialize registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int idx = 0; idx < 8; idx = idx + 1) begin
        prefix[idx] <= 32'b0;
        suffix[idx] <= 32'b0;
      end
    end else if (state == IDLE && start) begin
      i <= 3'b0;
      j <= n - 1;
      k_counter <= 4'b0;
      mul <= 32'b1;
      current_candidate <= 32'b0;
      max_candidate <= 32'b0;
      done <= 1'b0;
    end
  end

endmodule