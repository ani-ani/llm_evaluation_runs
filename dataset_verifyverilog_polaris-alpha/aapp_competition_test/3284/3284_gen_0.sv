module coprime_pairs_counter(
  input clk,               // clock
  input rst_n,             // active-low reset
  input start,             // start computation
  input [3:0] a,           // lower bound of x (4 bits)
  input [3:0] b,           // upper bound of x (4 bits)
  input [3:0] c,           // lower bound of y (4 bits)
  input [3:0] d,           // upper bound of y (4 bits)
  output reg [7:0] count,  // result count (8 bits)
  output reg done          // completion flag
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE       = 2'b00,
    COMPUTING  = 2'b01,
    DONE       = 2'b10
  } state_t;

  state_t state, next_state;

  // Iteration registers
  reg [3:0] x_reg, y_reg;

  // Latched bounds
  reg [3:0] a_reg, b_reg, c_reg, d_reg;

  // Combinational GCD wires
  wire [3:0] gcd_val;

  // Combinational GCD (Euclid's algorithm for 4-bit inputs)
  function automatic [3:0] gcd4;
    input [3:0] u;
    input [3:0] v;
    reg   [3:0] a_t, b_t;
    begin
      a_t = u;
      b_t = v;
      if (a_t == 0) begin
        gcd4 = b_t;
      end else if (b_t == 0) begin
        gcd4 = a_t;
      end else begin
        while (a_t != b_t) begin
          if (a_t > b_t)
            a_t = a_t - b_t;
          else
            b_t = b_t - a_t;
        end
        gcd4 = a_t;
      end
    end
  endfunction

  assign gcd_val = gcd4(x_reg, y_reg);

  // Next-state and control logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start && rst_n)
          next_state = COMPUTING;
      end
      COMPUTING: begin
        // Move to DONE after processing last pair
        if ((x_reg == b_reg) && (y_reg == d_reg))
          next_state = DONE;
      end
      DONE: begin
        // Wait for start deassert then reassert to restart
        if (!start)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= IDLE;
      a_reg   <= 4'd0;
      b_reg   <= 4'd0;
      c_reg   <= 4'd0;
      d_reg   <= 4'd0;
      x_reg   <= 4'd0;
      y_reg   <= 4'd0;
      count   <= 8'd0;
      done    <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done  <= 1'b0;
          count <= 8'd0;
          if (start) begin
            // Latch bounds at start
            a_reg <= a;
            b_reg <= b;
            c_reg <= c;
            d_reg <= d;
            // Initialize iterators
            x_reg <= a;
            y_reg <= c;
          end
        end

        COMPUTING: begin
          // Count if current pair is coprime
          if (gcd_val == 4'd1)
            count <= count + 8'd1;

          // Iterator update: y runs fastest
          if (y_reg == d_reg) begin
            y_reg <= c_reg;
            if (x_reg != b_reg)
              x_reg <= x_reg + 4'd1;
          end else begin
            y_reg <= y_reg + 4'd1;
          end

          // done will be asserted next cycle in DONE state
          done <= 1'b0;
        end

        DONE: begin
          // Hold final count, assert done
          done <= 1'b1;
          // Stay until start is deasserted; next_state logic handles transition
        end

        default: begin
          done  <= 1'b0;
          count <= 8'd0;
        end
      endcase
    end
  end

endmodule