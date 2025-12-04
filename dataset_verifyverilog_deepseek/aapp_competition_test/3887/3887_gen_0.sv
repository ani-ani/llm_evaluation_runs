module rebus_solver(
  input clk,
  input rst_n,
  input start,
  input [3:0] num_terms,
  input [15:0] n,
  input [15:0] sign_pattern,
  output reg [15:0] solution [0:15],
  output reg possible,
  output reg done
);

  typedef enum logic [1:0] {IDLE, PROCESS} state_t;
  state_t state;

  reg [3:0] term_counter;
  reg signed [16:0] diff_reg;
  wire [15:0] mask = (16'hffff >> (16 - num_terms));
  wire [4:0] pop_count = $countones(sign_pattern & mask);
  wire signed [5:0] min_sum = (pop_count << 1) - signed'({1'b0, num_terms});
  wire signed [16:0] initial_diff = signed'({1'b0, n}) - min_sum;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      possible <= 1'b0;
      foreach (solution[i]) solution[i] <= 16'b0;
      term_counter <= 4'b0;
      diff_reg <= 17'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            foreach (solution[i]) solution[i] <= (i < num_terms) ? 16'd1 : 16'd0;
            diff_reg <= initial_diff;
            term_counter <= 4'd0;
            done <= 1'b0;
            possible <= (initial_diff >= 0);
            state <= (initial_diff < 0) ? IDLE : PROCESS;
            done <= (initial_diff < 0);
          end
        end

        PROCESS: begin
          if (term_counter < num_terms) begin
            if (sign_pattern[term_counter] && (diff_reg > 0)) begin
              automatic logic [15:0] delta = (diff_reg >= (n-1)) ? (n-1) : diff_reg[15:0];
              solution[term_counter] <= 16'd1 + delta;
              diff_reg <= diff_reg - signed'({1'b0, delta});
            end
            term_counter <= term_counter + 1;
          end

          if (term_counter == num_terms - 1 || num_terms == 0) begin
            possible <= (diff_reg == 0);
            done <= 1'b1;
            state <= IDLE;
          end
        end
      endcase
    end
  end
endmodule