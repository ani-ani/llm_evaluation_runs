module complex_to_polar (
  input clk,
  input rst_n,
  input start,
  input signed [31:0] real_in,
  input signed [31:0] imag_in,
  output reg [31:0] magnitude,
  output reg [31:0] angle,
  output reg done
);

  // State definitions
  localparam [2:0] IDLE = 3'b000;
  localparam [2:0] SQR_REAL = 3'b001;
  localparam [2:0] SQR_IMAG = 3'b010;
  localparam [2:0] SUM_SQRS = 3'b011;
  localparam [2:0] SQRT_ITER = 3'b100;
  localparam [2:0] ATAN = 3'b101;
  localparam [2:0] DONE = 3'b110;

  reg [2:0] state = IDLE;
  reg [31:0] real_sqr, imag_sqr;
  reg [31:0] sum_sqrs;
  reg [31:0] sqrt_y;
  reg [31:0] atan_val;
  reg [4:0] iter_count = 0;

  // Constants
  localparam PI_Q16 = 32'h0003243F; // π in Q16.16 (3.14159 * 65536 ≈ 205887)
  localparam PI_HALF_Q16 = 32'h0001921F; // π/2 in Q16.16

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      magnitude <= 32'h00000000;
      angle <= 32'h00000000;
      done <= 1'b0;
      iter_count <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= SQR_REAL;
            done <= 1'b0;
          end
        end

        SQR_REAL: begin
          // Compute real² in Q16.16 format
          real_sqr <= (real_in * real_in) >>> 16;
          state <= SQR_IMAG;
        end

        SQR_IMAG: begin
          // Compute imag² in Q16.16 format
          imag_sqr <= (imag_in * imag_in) >>> 16;
          state <= SUM_SQRS;
        end

        SUM_SQRS: begin
          // Sum of squares (real² + imag²)
          sum_sqrs <= real_sqr + imag_sqr;
          // Initial guess for sqrt: y = x/2
          sqrt_y <= sum_sqrs >>> 1;
          iter_count <= 0;
          state <= SQRT_ITER;
        end

        SQRT_ITER: begin
          if (iter_count < 20) begin
            // Newton-Raphson iteration: y = (y + x/y) / 2
            // x/y in Q16.16: (sum_sqrs << 16) / sqrt_y
            // To avoid division, we can use: y_new = (y + (x << 16)/y) >>> 1
            // But for hardware, we'll do it step by step
            reg [63:0] temp;
            temp = $signed({32'h00000000, sum_sqrs}) / sqrt_y;
            sqrt_y <= (sqrt_y + temp[47:16]) >>> 1;
            iter_count <= iter_count + 1;
          end else begin
            magnitude <= sqrt_y;
            state <= ATAN;
          end
        end

        ATAN: begin
          // Compute angle using atan2 approximation
          if (real_in == 0 && imag_in == 0) begin
            angle <= 32'h00000000; // Undefined, default to 0
          end else if (real_in == 0) begin
            // imag != 0
            if (imag_in[31]) begin
              angle <= -PI_HALF_Q16; // -π/2
            end else begin
              angle <= PI_HALF_Q16; // +π/2
            end
          end else if (imag_in == 0) begin
            // real != 0
            if (real_in[31]) begin
              angle <= PI_Q16; // π
            end else begin
              angle <= 32'h00000000; // 0
            end
          end else begin
            // General case: atan2(imag, real)
            reg signed [31:0] ratio;
            reg [31:0] abs_real, abs_imag;
            reg sign_real, sign_imag;

            abs_real = real_in[31] ? -real_in : real_in;
            abs_imag = imag_in[31] ? -imag_in : imag_in;
            sign_real = real_in[31];
            sign_imag = imag_in[31];

            // Compute ratio = imag/real in Q16.16
            ratio = (imag_in << 16) / real_in;

            // Approximate atan(ratio) using polynomial approximation
            // atan(x) ≈ x - x^3/3 + x^5/5 - x^7/7 for |x| < 1
            reg [31:0] x, x2, x3, x5, x7;
            x = ratio;
            x2 = (x * x) >>> 16;
            x3 = (x2 * x) >>> 16;
            x5 = (x3 * x2) >>> 16;
            x7 = (x5 * x2) >>> 16;

            // atan(x) = x - (x3 >>> 2) + (x5 >>> 3) - (x7 >>> 3)
            atan_val = x - (x3 >>> 2) + (x5 >>> 3) - (x7 >>> 3);

            // Quadrant adjustment
            if (sign_real && !sign_imag) begin
              // Quadrant II: angle = atan(ratio) + π
              angle <= atan_val + PI_Q16;
            end else if (sign_real && sign_imag) begin
              // Quadrant III: angle = atan(ratio) - π
              angle <= atan_val - PI_Q16;
            end else if (!sign_real && sign_imag) begin
              // Quadrant IV: angle = atan(ratio)
              angle <= atan_val;
            end else begin
              // Quadrant I: angle = atan(ratio)
              angle <= atan_val;
            end
          end
          state <= DONE;
        end

        DONE: begin
          done <= 1'b1;
          if (start) begin
            state <= SQR_REAL;
            done <= 1'b0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule