module polygon_area (
  input clk,
  input rst_n,
  input start,
  input [15:0] s,
  input [31:0] l,
  output reg [31:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    CALC_LSQ,
    CALC_TAN,
    CALC_DIV,
    DONE
  } state_t;

  state_t state, next_state;

  // Intermediate registers
  reg [31:0] l_sq;
  reg [31:0] tan_val;
  reg [31:0] numerator;
  reg [31:0] denominator;
  reg [31:0] quotient;
  reg [31:0] remainder;
  reg [31:0] count;

  // Lookup table for tan(π/s) in Q16.16 format
  reg [31:0] tan_lut [3:12];

  // Initialize lookup table
  initial begin
    tan_lut[3] = 32'h0001BB67; // tan(π/3)
    tan_lut[4] = 32'h00010000; // tan(π/4)
    tan_lut[5] = 32'h0000B9EF; // tan(π/5)
    tan_lut[6] = 32'h000093D7; // tan(π/6)
    tan_lut[7] = 32'h00007B63; // tan(π/7)
    tan_lut[8] = 32'h00006A28; // tan(π/8)
    tan_lut[9] = 32'h00005CC4; // tan(π/9)
    tan_lut[10] = 32'h00005337; // tan(π/10)
    tan_lut[11] = 32'h00004B5E; // tan(π/11)
    tan_lut[12] = 32'h0000449D; // tan(π/12)
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      result <= 32'h00000000;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = CALC_LSQ;
        end
      end
      CALC_LSQ: begin
        next_state = CALC_TAN;
      end
      CALC_TAN: begin
        next_state = CALC_DIV;
      end
      CALC_DIV: begin
        if (count == 32'h00000000) begin
          next_state = DONE;
        end
      end
      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      l_sq <= 32'h00000000;
      tan_val <= 32'h00000000;
      numerator <= 32'h00000000;
      denominator <= 32'h00000000;
      quotient <= 32'h00000000;
      remainder <= 32'h00000000;
      count <= 32'h00000000;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
        end
        CALC_LSQ: begin
          // Calculate l² (Q16.16 * Q16.16 gives Q32.32, shift right 16 to get Q16.16)
          l_sq <= (l * l) >>> 16;
        end
        CALC_TAN: begin
          // Read tan(π/s) from lookup table
          tan_val <= tan_lut[s];
          // Calculate numerator = s * l²
          numerator <= s * l_sq;
          // Calculate denominator = 4 * tan(π/s)
          denominator <= 4 * tan_val;
          // Initialize quotient and remainder for division
          quotient <= 32'h00000000;
          remainder <= numerator;
          count <= 32'h00000000;
        end
        CALC_DIV: begin
          // Iterative subtraction for division
          if (remainder >= denominator) begin
            remainder <= remainder - denominator;
            quotient <= quotient + 1;
          end else begin
            count <= count - 1;
            if (count != 32'h00000000) begin
              remainder <= remainder << 1;
              quotient <= quotient << 1;
            end
          end
          // When count reaches 0, division is complete
          if (count == 32'h00000000) begin
            result <= quotient;
          end
        end
        DONE: begin
          done <= 1'b1;
        end
        default: begin
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule