module expected_area (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [3:0] k,
  input [15:0] x0, y0,
  input [15:0] x1, y1,
  input [15:0] x2, y2,
  input [15:0] x3, y3,
  input [15:0] x4, y4,
  output reg [31:0] result,
  output reg done
);

  // State definitions
  localparam [2:0] IDLE = 3'b000;
  localparam [2:0] CALC_TRIANGLES = 3'b001;
  localparam [2:0] ACCUMULATE = 3'b010;
  localparam [2:0] DIVIDE = 3'b011;
  localparam [2:0] DONE = 3'b100;

  reg [2:0] state = IDLE;
  reg [3:0] triangle_count = 0;
  reg [47:0] accumulator = 0;
  reg [31:0] temp_area = 0;
  reg [3:0] i = 0, j = 0, l = 0;
  reg [31:0] x_i, y_i, x_j, y_j, x_l, y_l;
  reg [31:0] term1, term2, term3, term4, term5, term6;
  reg [31:0] area_abs;
  reg [31:0] division_result = 0;
  reg [31:0] divisor = 10;
  reg [31:0] quotient = 0;
  reg [31:0] remainder = 0;
  reg [31:0] count = 0;

  // Vertex storage
  reg [15:0] x_reg [0:4];
  reg [15:0] y_reg [0:4];

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      triangle_count <= 0;
      accumulator <= 0;
      i <= 0;
      j <= 0;
      l <= 0;
      division_result <= 0;
      quotient <= 0;
      remainder <= 0;
      count <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            // Store vertices
            x_reg[0] <= x0; y_reg[0] <= y0;
            x_reg[1] <= x1; y_reg[1] <= y1;
            x_reg[2] <= x2; y_reg[2] <= y2;
            x_reg[3] <= x3; y_reg[3] <= y3;
            x_reg[4] <= x4; y_reg[4] <= y4;
            state <= CALC_TRIANGLES;
            triangle_count <= 0;
            accumulator <= 0;
            i <= 0;
            j <= 1;
            l <= 2;
          end
        end
        CALC_TRIANGLES: begin
          if (triangle_count < 10) begin
            // Compute shoelace formula for triangle (i,j,l)
            x_i = x_reg[i]; y_i = y_reg[i];
            x_j = x_reg[j]; y_j = y_reg[j];
            x_l = x_reg[l]; y_l = y_reg[l];

            // Compute terms (32-bit to prevent overflow)
            term1 = $signed(x_i) * $signed(y_j);
            term2 = $signed(x_j) * $signed(y_l);
            term3 = $signed(x_l) * $signed(y_i);
            term4 = $signed(x_j) * $signed(y_i);
            term5 = $signed(x_l) * $signed(y_j);
            term6 = $signed(x_i) * $signed(y_l);

            // Compute area (absolute value)
            temp_area = (term1 + term2 + term3) - (term4 + term5 + term6);
            area_abs = (temp_area[31] == 1) ? -temp_area : temp_area;

            // Accumulate (48-bit)
            accumulator = accumulator + {24'd0, area_abs};

            // Increment triangle count
            triangle_count <= triangle_count + 1;

            // Update indices for next triangle
            if (l < 4) begin
              l <= l + 1;
            end else if (j < 3) begin
              j <= j + 1;
              l <= j + 1;
            end else if (i < 3) begin
              i <= i + 1;
              j <= i + 1;
              l <= j + 1;
            end
          end else begin
            state <= ACCUMULATE;
          end
        end
        ACCUMULATE: begin
          // Divide by 2 (right shift by 1)
          accumulator = accumulator >>> 1;
          state <= DIVIDE;
        end
        DIVIDE: begin
          // Division by 10 using iterative subtraction
          if (count < 10) begin
            if (remainder >= divisor) begin
              remainder = remainder - divisor;
              quotient = quotient + 1;
            end
            count <= count + 1;
          end else begin
            division_result <= quotient;
            state <= DONE;
          end
        end
        DONE: begin
          result <= division_result;
          done <= 1;
        end
        default: begin
          state <= IDLE;
          done <= 0;
        end
      endcase
    end
  end

  // Initialize remainder with accumulator (upper 32 bits)
  always @(posedge clk) begin
    if (state == ACCUMULATE) begin
      remainder <= accumulator[47:16];
      quotient <= 0;
      count <= 0;
    end
  end

endmodule