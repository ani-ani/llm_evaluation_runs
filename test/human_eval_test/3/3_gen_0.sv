module balance_checker(
  input              clk,
  input              rst_n,
  input              start,
  input      [7:0]   ops [0:7],
  input      [2:0]   op_count,
  output reg         below_zero_flag,
  output reg         done
);

  // Internal signals
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    RUN   = 2'b01,
    DONE  = 2'b10
  } state_t;

  state_t        state, next_state;
  reg [2:0]      idx;                 // operation index
  reg [2:0]      count_reg;           // latched op_count
  reg signed [11:0] balance;          // 12-bit signed balance
  wire signed [7:0] current_op;       // current operation

  assign current_op = (idx < count_reg) ? ops[idx] : 8'sd0;

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = (op_count == 3'd0) ? DONE : RUN;
      end
      RUN: begin
        if (idx == count_reg) // completed all operations
          next_state = DONE;
      end
      DONE: begin
        if (!start) // wait for start to deassert before returning to IDLE
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state            <= IDLE;
      idx              <= 3'd0;
      count_reg        <= 3'd0;
      balance          <= 12'sd0;
      below_zero_flag  <= 1'b0;
      done             <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            count_reg       <= op_count;
            balance         <= 12'sd0;
            below_zero_flag <= 1'b0;
            idx             <= 3'd0;
            if (op_count == 3'd0) begin
              done <= 1'b1; // immediate completion when no operations
            end
          end
        end

        RUN: begin
          if (idx < count_reg) begin
            // Perform signed addition
            balance <= balance + {{4{current_op[7]}}, current_op};

            // Check for negative balance based on current cycle result
            if ($signed(balance + {{4{current_op[7]}}, current_op}) < 0)
              below_zero_flag <= 1'b1;

            idx <= idx + 3'd1;
          end

          // When we've just processed the last operation, set done next cycle via state
          done <= 1'b0;
        end

        DONE: begin
          done <= 1'b1;
          // Hold balance and flags until next start sequence
        end

        default: begin
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule