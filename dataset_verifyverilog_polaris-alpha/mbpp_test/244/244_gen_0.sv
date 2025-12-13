module next_perfect_square (
  input  logic        clk,
  input  logic        rst_n,
  input  logic [15:0] N,
  input  logic        start,
  output logic [31:0] result,
  output logic        done
);

  // FSM encoding
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    SQRT  = 2'b01,
    SQUARE= 2'b10
  } state_t;

  state_t       state, next_state;
  logic [15:0]  N_reg;
  logic [4:0]   iter_cnt;       // up to 16 iterations
  logic [8:0]   x;              // candidate integer sqrt (0..256)
  logic [17:0]  x2;             // x*x fits in 18 bits
  logic [8:0]   floor_sqrt;     // floor(sqrt(N))
  logic [8:0]   next_int;       // floor_sqrt + 1
  logic [17:0]  square_val;     // next_int^2

  // Combinational: square of current x
  always_comb begin
    x2 = x * x;
  end

  // FSM next state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = SQRT;
        end
      end
      SQRT: begin
        // After completing 16 iterations, move to squaring step
        if (iter_cnt == 5'd16) begin
          next_state = SQUARE;
        end
      end
      SQUARE: begin
        // One cycle for squaring, then go back to IDLE
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      N_reg       <= 16'd0;
      iter_cnt    <= 5'd0;
      x           <= 9'd0;
      floor_sqrt  <= 9'd0;
      next_int    <= 9'd0;
      square_val  <= 18'd0;
      result      <= 32'd0;
      done        <= 1'b0;
    end else begin
      state <= next_state;

      // Default outputs each cycle
      done <= 1'b0;

      case (state)
        IDLE: begin
          iter_cnt   <= 5'd0;
          x          <= 9'd0;
          floor_sqrt <= 9'd0;
          square_val <= 18'd0;
          if (start) begin
            N_reg    <= N;
          end
        end

        SQRT: begin
          // Successive approximation by incrementing x
          // We capture floor_sqrt as the latest x with x^2 <= N_reg
          // Perform 16 iterations max (for 16-bit N, sqrt <= 255)
          if (x2 <= N_reg) begin
            floor_sqrt <= x;      // still valid candidate
            x          <= x + 9'd1;
          end else begin
            // once x^2 > N, keep x steady; floor_sqrt holds last valid
            x          <= x;
            floor_sqrt <= floor_sqrt;
          end

          // Increment iteration counter
          iter_cnt <= iter_cnt + 5'd1;
        end

        SQUARE: begin
          // Compute (floor_sqrt + 1)^2
          next_int   <= floor_sqrt + 9'd1;
          square_val <= (floor_sqrt + 9'd1) * (floor_sqrt + 9'd1);
          result     <= {14'd0, square_val}; // zero-extend to 32 bits
          done       <= 1'b1;                 // result valid this cycle
        end

        default: begin
          // Should not occur; safe defaults
          iter_cnt   <= 5'd0;
          x          <= 9'd0;
          floor_sqrt <= 9'd0;
          next_int   <= 9'd0;
          square_val <= 18'd0;
          result     <= 32'd0;
          done       <= 1'b0;
        end
      endcase
    end
  end

endmodule