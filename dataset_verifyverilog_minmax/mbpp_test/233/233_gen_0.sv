module cylinder_lateral_area (
  input clk,
  input rst_n,
  input start,
  input [15:0] radius,
  input [15:0] height,
  output reg [63:0] result,
  output reg done
);

  // State definitions
  localparam IDLE = 2'b00;
  localparam STAGE1 = 2'b01;
  localparam STAGE2 = 2'b10;

  reg [1:0] state;
  reg [63:0] mult1_reg;
  reg [15:0] captured_radius;
  reg [15:0] captured_height;

  // Precomputed 2*pi in Q16.16 format: 0x6487E (6.2830)
  localparam [63:0] TWO_PI = 64'h000000000006487E;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 64'h0;
      mult1_reg <= 64'h0;
      captured_radius <= 16'h0;
      captured_height <= 16'h0;
      done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            captured_radius <= radius;
            captured_height <= height;
            state <= STAGE1;
          end
          done <= 1'b0;
        end

        STAGE1: begin
          // Stage 1: Multiply 2π × radius (64-bit result)
          mult1_reg <= TWO_PI * {48'b0, captured_radius};
          state <= STAGE2;
        end

        STAGE2: begin
          // Stage 2: Multiply intermediate result × height
          // Multiplication produces 80-bit result; keep upper 64 bits
          result <= (mult1_reg * {48'b0, captured_height}) >> 16;
          done <= 1'b1;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule