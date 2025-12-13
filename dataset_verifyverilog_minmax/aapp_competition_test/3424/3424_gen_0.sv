module age_base_finder(
  input clk,          // clock
  input rst_n,        // active-low reset
  input start,        // start computation (pulse)
  input [15:0] y,     // age value (base 10)
  input [15:0] l,     // minimum acceptable value
  output reg [15:0] b, // largest valid base found
  output reg done      // high when computation completes
);

  // Internal state and datapath
  localparam IDLE = 1'b0;
  localparam SEARCH = 1'b1;

  reg state, next_state;
  reg [15:0] cbase;    // current base being tested
  reg [15:0] cbase_next;
  reg [15:0] latch_y;  // snapshot of y when start is asserted
  reg [15:0] latch_l;  // snapshot of l when start is asserted

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      b <= 16'd0;
      done <= 1'b0;
      cbase <= 16'd0;
      latch_y <= 16'd0;
      latch_l <= 16'd0;
    end else begin
      state <= next_state;
      b <= b;      // keep current output until completion
      done <= done;
      cbase <= cbase_next;
      latch_y <= latch_y;
      latch_l <= latch_l;
    end
  end

  always @(*) begin
    // Defaults
    next_state = state;
    cbase_next = cbase;
    b = b;
    done = done;

    case (state)
      IDLE: begin
        if (start) begin
          // Initialize search with min(y, 256)
          cbase_next = (y > 16'd255) ? 16'd255 : y;
          b = 16'd0;
        end else begin
          b = 16'd0;
          done = 1'b0;
        end
        next_state = start ? SEARCH : IDLE;
      end

      SEARCH: begin
        // Pipeline latch y/l to avoid timing issues if inputs change mid-search
        latch_y = y;
        latch_l = l;

        if (cbase > 16'd2) begin
          // One base per cycle: check digits and threshold in one pass
          // Stop at first failing base
          cbase_next = cbase - 1;

          // FSM ensures base >= 2 so operations are safe
          // Extract digits and compute base-10 value (if all digits are 0-9)
          if ((cbase > 1)) begin
            automatic logic [15:0] tmp = latch_y;
            automatic logic [19:0] sum = 20'd0; // 20-bit to avoid overflow (max 16*10^16 not reached here)
            automatic logic all_valid = 1'b1;
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
              if (tmp == 16'd0) begin
                // No more digits
                // Nothing to do; leading zeros are implicitly handled (0*10 + 0)
              end else begin
                automatic logic [15:0] digit = tmp % cbase;
                if (digit > 16'd9) all_valid = 1'b0;
                sum = sum * 20'd10 + digit;
                tmp = tmp / cbase;
              end
            end
            // Check all digits in [0,9] and threshold
            if (all_valid && (sum >= latch_l)) begin
              b = cbase;
              done = 1'b1;
              next_state = IDLE; // Complete immediately upon finding largest valid base
            end else begin
              b = b; // keep previous output (typically 0) until done
              done = done;
            end
          end
        end else begin
          // Exhaustive search completed, no base met both conditions
          b = 16'd0;
          done = 1'b1;
          cbase_next = cbase;
          next_state = IDLE;
        end
      end

      default: begin
        next_state = IDLE;
        cbase_next = 16'd0;
        b = 16'd0;
        done = 1'b0;
      end
    endcase
  end
endmodule
