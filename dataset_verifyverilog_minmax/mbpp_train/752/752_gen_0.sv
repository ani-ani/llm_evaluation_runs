module jacobsthal_calculator(
    input reg clk,
    input reg rst_n,
    input reg start,
    input reg [3:0] n,
    output reg [15:0] result,
    output reg done
);

  // Internal signals
  reg [1:0] state;
  reg [3:0] i;
  reg [3:0] n_reg;
  reg [15:0] j_prev, j_curr;
  reg [15:0] next_j_prev, next_j_curr;
  reg [3:0] i_next;
  reg [1:0] next_state;
  reg done_next;

  localparam IDLE = 2'b00;
  localparam CALC = 2'b01;

  always_comb begin
    // Default assignments
    next_state = state;
    i_next = i;
    next_j_prev = j_prev;
    next_j_curr = j_curr;
    done_next = 1'b0;

    case (state)
      IDLE: begin
        if (start) begin
          next_state = CALC;
          // i, j_prev, j_curr will be set in the sequential block
        end
      end
      CALC: begin
        if (i == 4'b0) begin
          next_j_curr = 16'b0;
          next_j_prev = 16'b0;
        end else if (i == 4'b1) begin
          next_j_curr = 16'b1;
          next_j_prev = 16'b0;
        end else begin
          next_j_curr = j_curr + (j_prev << 1);
          next_j_prev = j_curr;
        end

        i_next = i + 1;

        if (i == n_reg) begin
          done_next = 1'b1;
          next_state = IDLE;
        end else begin
          done_next = 1'b0;
          next_state = CALC;
        end
      end
      default: begin
        next_state = IDLE;
      end
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= 4'b0;
      n_reg <= 4'b0;
      j_prev <= 16'b0;
      j_curr <= 16'b0;
      result <= 16'b0;
      done <= 1'b0;
    end else begin
      // Capture n on start in IDLE
      if (state == IDLE && start) begin
        n_reg <= n;
        i <= 4'b0;
        j_prev <= 16'b0;
        j_curr <= 16'b0;
      end

      // Update state and registers
      state <= next_state;
      i <= i_next;
      j_prev <= next_j_prev;
      j_curr <= next_j_curr;
      result <= next_j_curr;
      done <= done_next;
    end
  end

endmodule