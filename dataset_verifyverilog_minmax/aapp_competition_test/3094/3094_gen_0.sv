module permutation_square_count(
  input clk, // Clock signal
  input rst_n, // Active-low reset
  input start, // Start computation
  input [2:0] n, // Permutation size (1-8)
  input [2:0] t_0, // Element 1 (chair assignments)
  input [2:0] t_1, // Element 2
  input [2:0] t_2, // Element 3
  input [2:0] t_3, // Element 4
  input [2:0] t_4, // Element 5
  input [2:0] t_5, // Element 6
  input [2:0] t_6, // Element 7
  input [2:0] t_7, // Element 8
  output reg [31:0] result, // Computed count (mod 1e9+7)
  output reg done // High when computation complete
);

  // State definitions
  localparam IDLE = 3'b000;
  localparam INIT = 3'b001;
  localparam FIND_CYCLES = 3'b010;
  localparam TRAVERSE_CYCLE = 3'b011;
  localparam COMPUTE = 3'b100;
  localparam DONE = 3'b101;

  // Internal variables
  reg [2:0] state;
  reg [2:0] n_reg;
  reg [2:0] perm [0:7];
  reg [7:0] visited;
  reg [2:0] i;
  reg [2:0] current_cycle_start;
  reg [2:0] current_element;
  reg [3:0] cycle_length;
  reg [34:0] product35;
  reg [31:0] mod_product;

  // Constants for modular arithmetic
  localparam MOD1 = 35'd1000000007;
  localparam MOD2 = 35'd2000000014;
  localparam MOD3 = 35'd3000000021;
  localparam MOD4 = 35'd4000000028;
  localparam MOD5 = 35'd5000000035;
  localparam MOD6 = 35'd6000000042;
  localparam MOD7 = 35'd7000000049;

  // State machine
  always @(posedge clk) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 32'd0;
      done <= 1'b0;
      visited <= 8'd0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT;
          end
        end

        INIT: begin
          // Capture inputs
          perm[0] <= t_0;
          perm[1] <= t_1;
          perm[2] <= t_2;
          perm[3] <= t_3;
          perm[4] <= t_4;
          perm[5] <= t_5;
          perm[6] <= t_6;
          perm[7] <= t_7;
          n_reg <= n;
          result <= 32'd1;
          done <= 1'b0;
          visited <= 8'd0;
          i <= 3'd0;
          state <= FIND_CYCLES;
        end

        FIND_CYCLES: begin
          if (i < n_reg) begin
            if (visited[i] == 1'b0) begin
              // Start new cycle
              current_cycle_start <= i;
              current_element <= i;
              cycle_length <= 4'd1;
              visited[i] <= 1'b1;
              state <= TRAVERSE_CYCLE;
            end else begin
              i <= i + 1;
            end
          end else begin
            state <= DONE;
          end
        end

        TRAVERSE_CYCLE: begin
          if (perm[current_element] == current_cycle_start) begin
            state <= COMPUTE;
          end else if (visited[perm[current_element]] == 1'b1) begin
            state <= COMPUTE;
          end else begin
            visited[perm[current_element]] <= 1'b1;
            current_element <= perm[current_element];
            cycle_length <= cycle_length + 1;
          end
        end

        COMPUTE: begin
          // Calculate product
          if (cycle_length[0] == 1) begin
            product35 = {1'b0, result} * {1'b0, cycle_length};
          end else begin
            product35 = {1'b0, result} * {1'b0, (cycle_length >> 1)};
          end

          // Modular reduction
          if (product35 >= MOD7) begin
            mod_product = product35 - MOD7;
          end else if (product35 >= MOD6) begin
            mod_product = product35 - MOD6;
          end else if (product35 >= MOD5) begin
            mod_product = product35 - MOD5;
          end else if (product35 >= MOD4) begin
            mod_product = product35 - MOD4;
          end else if (product35 >= MOD3) begin
            mod_product = product35 - MOD3;
          end else if (product35 >= MOD2) begin
            mod_product = product35 - MOD2;
          end else if (product35 >= MOD1) begin
            mod_product = product35 - MOD1;
          end else begin
            mod_product = product35;
          end

          result <= mod_product;
          state <= FIND_CYCLES;
        end

        DONE: begin
          done <= 1'b1;
          // Stay in DONE state until reset
        end
      endcase
    end
  end
endmodule