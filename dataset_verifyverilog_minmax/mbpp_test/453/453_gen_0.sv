module sum_even_factors(
  input clk,
  input rst_n,
  input start,
  input [15:0] n_in,
  output reg [31:0] sum,
  output reg done
);

  // State encoding
  localparam IDLE = 3'b000;
  localparam INIT = 3'b001;
  localparam CHECK_DIVISOR = 3'b010;
  localparam CALC_EXP = 3'b011;
  localparam CALC_TERM = 3'b100;
  localparam UPDATE_DIVISOR = 3'b101;
  localparam FINAL_MULT = 3'b110;
  localparam DONE = 3'b111;

  reg [2:0] state, next_state;
  reg [15:0] divisor, working_n, m, k_power2, exp;
  reg [31:0] term_reg, sum_even;
  reg [4:0] i;   // for the term calculation loop, up to 16

  // State register
  always @(posedge clk) begin
     if (rst_n == 1'b0) begin
        state <= IDLE;
     end else begin
        state <= next_state;
     end
  end

  // Combinational logic for next_state
  always @(*) begin
     next_state = state;
     case (state)
        IDLE: begin
           if (start) 
              next_state = INIT;
        end
        INIT: begin
           if (n_in[0] == 1'b1) begin
              // Immediately set to DONE on next cycle
              next_state = DONE;
           end else begin
              // Factor out the 2's
              m = n_in;
              k_power2 = 0;
              while (m % 2 == 0) begin
                 m = m / 2;
                 k_power2 = k_power2 + 1;
              end
              // Now m is odd
              next_state = CHECK_DIVISOR;
           end
        end
        CHECK_DIVISOR: begin
           if (divisor * divisor > working_n) begin
              next_state = FINAL_MULT;
           end else if (working_n % divisor == 0) begin
              next_state = CALC_EXP;
           end else begin
              next_state = UPDATE_DIVISOR;
           end
        end
        CALC_EXP: begin
           if (working_n % divisor == 0) begin
              // Stay in this state to count exponent
           end else begin
              next_state = CALC_TERM;
           end
        end
        CALC_TERM: begin
           if (i <= exp) begin
              // Stay in this state to calculate term
           end else begin
              next_state = UPDATE_DIVISOR;
           end
        end
        UPDATE_DIVISOR: begin
           next_state = CHECK_DIVISOR;
        end
        FINAL_MULT: begin
           next_state = DONE;
        end
        DONE: begin
           if (!start) 
              next_state = IDLE;
        end
        default: next_state = IDLE;
     endcase
  end

  // Output assignments and state-dependent actions
  always @(posedge clk) begin
     if (rst_n == 1'b0) begin
        sum <= 0;
        done <= 0;
        working_n <= 0;
        divisor <= 0;
        exp <= 0;
        term_reg <= 0;
        i <= 0;
        m <= 0;
        k_power2 <= 0;
        sum_even <= 0;
     end else begin
        case (state)
           IDLE: begin
              sum <= 0;
              done <= 0;
           end
           INIT: begin
              if (n_in[0] == 1'b1) begin
                 sum <= 0;
                 done <= 0;   // will be overridden in DONE state next cycle
              end else begin
                 // Factor out the 2's and initialize
                 m = n_in;
                 k_power2 = 0;
                 while (m % 2 == 0) begin
                    m = m / 2;
                    k_power2 = k_power2 + 1;
                 end
                 working_n = m;
                 divisor = 3;
                 exp = 0;
                 i = 0;
                 term_reg = 0;
                 sum = 1;
              end
           end
           CHECK_DIVISOR: begin
              // State transitions are handled in next_state logic
           end
           CALC_EXP: begin
              if (working_n % divisor == 0) begin
                 working_n = working_n / divisor;
                 exp = exp + 1;
              end else begin
                 // Initialize for term calculation
                 term_reg = 0;
                 i = 0;
              end
           end
           CALC_TERM: begin
              if (i <= exp) begin
                 term_reg = term_reg + (divisor ** i);
                 i = i + 1;
              end else begin
                 sum = sum * term_reg;
              end
           end
           UPDATE_DIVISOR: begin
              divisor = divisor + 2;   // next odd divisor
           end
           FINAL_MULT: begin
              if (working_n >= 2) begin
                 sum = sum * (1 + working_n);
              end
              // even divisor adjustment: sum_even = 2 * ( (1 << k_power2) - 1 ) * sum;
              sum_even = 2 * ( ( (32'b1 << k_power2) - 32'b1 ) * sum );
           end
           DONE: begin
              if (n_in[0] == 1'b1) begin
                 sum <= 0;
                 done <= 1;
              end else begin
                 sum <= sum_even;
                 done <= 1;
              end
           end
        endcase
     end
  end

endmodule