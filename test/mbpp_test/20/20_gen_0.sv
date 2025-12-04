module woodall_checker(
  input  logic        clk,
  input  logic        rst_n,
  input  logic [15:0] x_in,
  input  logic        start,
  output logic        is_woodall,
  output logic        done
);

  typedef enum logic [2:0] {
    IDLE        = 3'd0,
    CHECK_EVEN  = 3'd1,
    ADD_ONE     = 3'd2,
    DIVIDE      = 3'd3,
    CHECK_EQUAL = 3'd4,
    DONE_ST     = 3'd5
  } state_t;

  state_t       state, next_state;
  logic [15:0]  x_reg;       // captured input
  logic [15:0]  x_work;      // working x value
  logic [15:0]  p;           // division count
  logic         is_woodall_next;
  logic         done_next;

  // State and outputs registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      x_reg       <= 16'd0;
      x_work      <= 16'd0;
      p           <= 16'd0;
      is_woodall  <= 1'b0;
      done        <= 1'b0;
    end else begin
      state       <= next_state;
      is_woodall  <= is_woodall_next;
      done        <= done_next;

      // Datapath updates
      case (state)
        IDLE: begin
          if (start) begin
            x_reg  <= x_in;
            x_work <= 16'd0;
            p      <= 16'd0;
          end
        end

        CHECK_EVEN: begin
          // No datapath update needed here; decisions in next_state logic
        end

        ADD_ONE: begin
          x_work <= x_reg + 16'd1;
          p      <= 16'd0;
        end

        DIVIDE: begin
          // Perform one step of divide-by-2 loop per cycle
          if ((x_work[0] == 1'b0) && (x_work != 16'd0) && (p <= x_work)) begin
            x_work <= x_work >> 1;
            p      <= p + 16'd1;
          end
        end

        CHECK_EQUAL: begin
          // No further datapath update; comparison done in next_state logic
        end

        DONE_ST: begin
          // Hold results until next start or reset
        end

        default: ;
      endcase
    end
  end

  // Next-state and output combinational logic
  always_comb begin
    next_state       = state;
    is_woodall_next  = is_woodall;
    done_next        = done;

    case (state)
      IDLE: begin
        // Clear outputs by default in IDLE
        is_woodall_next = 1'b0;
        done_next       = 1'b0;
        if (start) begin
          next_state = CHECK_EVEN;
        end
      end

      CHECK_EVEN: begin
        // x_reg already captured
        // If x_in == 0 or even, not Woodall
        if ((x_reg == 16'd0) || (x_reg[0] == 1'b0)) begin
          is_woodall_next = 1'b0;
          done_next       = 1'b1;
          next_state      = DONE_ST;
        end else begin
          next_state = ADD_ONE;
        end
      end

      ADD_ONE: begin
        // Move to divide loop
        is_woodall_next = 1'b0;
        done_next       = 1'b0;
        next_state      = DIVIDE;
      end

      DIVIDE: begin
        // Continue while x_work is even and non-zero, and p <= x_work
        if ((x_work != 16'd0) && (x_work[0] == 1'b0) && (p <= x_work)) begin
          // Stay in DIVIDE to continue shifting next cycle
          next_state      = DIVIDE;
          is_woodall_next = 1'b0;
          done_next       = 1'b0;
        end else begin
          // Stop conditions reached: x_work odd or zero, or p > x_work
          next_state = CHECK_EQUAL;
        end
      end

      CHECK_EQUAL: begin
        // Termination condition: if p > x_work, not Woodall
        // Otherwise true if final x_work equals p
        if (p > x_work) begin
          is_woodall_next = 1'b0;
        end else if (p == x_work) begin
          is_woodall_next = 1'b1;
        end else begin
          is_woodall_next = 1'b0;
        end
        done_next  = 1'b1;
        next_state = DONE_ST;
      end

      DONE_ST: begin
        // Hold result until new start
        if (start) begin
          // Start new computation
          done_next       = 1'b0;
          is_woodall_next = 1'b0;
          next_state      = CHECK_EVEN;
        end else begin
          next_state = DONE_ST;
        end
      end

      default: begin
        next_state       = IDLE;
        is_woodall_next  = 1'b0;
        done_next        = 1'b0;
      end
    endcase
  end

endmodule