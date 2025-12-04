module highest_power_2 (
  input clk,
  input rst_n,
  input start,
  input [5:0] n_in,
  output reg [5:0] result,
  output reg done
);

  // State machine states
  localparam IDLE = 1'b0;
  localparam COUNT = 1'b1;

  reg state, next_state;
  reg [5:0] cnt, cnt_next;
  wire is_pow2;

  // Combinational next-state logic
  always @(*) begin
    case (state)
      IDLE: begin
        cnt_next = 6'b0;
        if (start) begin
          next_state = COUNT;
        end else begin
          next_state = IDLE;
        end
      end
      COUNT: begin
        if (is_pow2) begin
          cnt_next = cnt;              // Hold final count
          next_state = IDLE;           // Will go to IDLE and raise done
        end else begin
          cnt_next = cnt - 1;          // Decrement
          next_state = COUNT;
        end
      end
      default: begin
        cnt_next = 6'b0;
        next_state = IDLE;
      end
    endcase
  end

  // Power-of-2 check: (i & (i-1)) == 0
  assign is_pow2 = (cnt & (cnt - 1)) == 0;

  // State and datapath registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cnt   <= 6'b0;
      result <= 6'b0;
      done  <= 1'b0;
    end else begin
      state <= next_state;
      cnt   <= cnt_next;
      if (state == IDLE && start) begin
        // Initialize counter with n_in at the start of calculation
        cnt <= n_in;
        // Clear outputs at the beginning of a new calculation
        result <= 6'b0;
        done   <= 1'b0;
      end else if (state == COUNT && next_state == IDLE) begin
        // On detection of power-of-2, capture result and assert done
        result <= cnt;
        done   <= 1'b1;
      end
      // When idle and not starting, keep done high until next start
      if (state == IDLE && !start) begin
        done <= done;
      end
    end
  end

endmodule