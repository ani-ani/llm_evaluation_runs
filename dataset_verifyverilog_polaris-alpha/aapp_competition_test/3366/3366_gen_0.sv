module collatz_sum(
  input clk,
  input rst_n,
  input start,
  input [15:0] L,
  input [15:0] R,
  output reg [20:0] S,
  output reg done
);

  // State encoding
  localparam IDLE        = 2'b00;
  localparam COMPUTE_FX  = 2'b01;

  localparam MAX_ITER = 6'd32;

  reg [1:0]  state, next_state;
  reg [15:0] current_X, next_current_X;
  reg [15:0] x_val, next_x_val;
  reg [5:0]  iter_cnt, next_iter_cnt;
  reg [5:0]  fX_cnt, next_fX_cnt;
  reg [20:0] next_S;
  reg        start_d;

  // Edge detect for start
  wire start_pulse = start & ~start_d;

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      current_X  <= 16'd0;
      x_val      <= 16'd0;
      iter_cnt   <= 6'd0;
      fX_cnt     <= 6'd0;
      S          <= 21'd0;
      done       <= 1'b0;
      start_d    <= 1'b0;
    end else begin
      state      <= next_state;
      current_X  <= next_current_X;
      x_val      <= next_x_val;
      iter_cnt   <= next_iter_cnt;
      fX_cnt     <= next_fX_cnt;
      S          <= next_S;
      done       <= (next_state == IDLE && state != IDLE) ? 1'b1 : (start_pulse ? 1'b0 : done);
      start_d    <= start;
    end
  end

  // Combinational next-state and datapath
  always @* begin
    // default assignments
    next_state      = state;
    next_current_X  = current_X;
    next_x_val      = x_val;
    next_iter_cnt   = iter_cnt;
    next_fX_cnt     = fX_cnt;
    next_S          = S;

    case (state)
      IDLE: begin
        if (start_pulse) begin
          next_S          = 21'd0;
          next_current_X  = L;
          next_x_val      = L;
          next_iter_cnt   = 6'd0;
          next_fX_cnt     = 6'd0;
          next_state      = COMPUTE_FX;
        end
      end

      COMPUTE_FX: begin
        if ((x_val == 16'd1) || (iter_cnt == MAX_ITER)) begin
          // Add f(X) and move to next X
          next_S = S + fX_cnt;
          if (current_X == R) begin
            // All done, go to IDLE; done flagged via sequential logic
            next_state = IDLE;
          end else begin
            // Setup for next X
            next_current_X = current_X + 16'd1;
            next_x_val     = current_X + 16'd1;
            next_iter_cnt  = 6'd0;
            next_fX_cnt    = 6'd0;
            next_state     = COMPUTE_FX;
          end
        end else begin
          // Perform one Collatz-like step and count
          if (x_val[0] == 1'b0) begin
            // even: X /= 2
            next_x_val = x_val >> 1;
          end else begin
            // odd: X += 1
            next_x_val = x_val + 16'd1;
          end
          next_iter_cnt = iter_cnt + 6'd1;
          next_fX_cnt   = fX_cnt + 6'd1;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule