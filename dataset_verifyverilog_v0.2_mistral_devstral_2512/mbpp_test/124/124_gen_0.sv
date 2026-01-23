module complex_angle (
  input clk,
  input rst_n,
  input start,
  input signed [15:0] a,
  input signed [15:0] b,
  output reg signed [31:0] angle,
  output reg done
);

  // Constants for CORDIC algorithm
  localparam int ITERATIONS = 16;
  localparam int Q_FORMAT = 16;

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CALCULATING,
    DONE
  } state_t;

  // Internal registers
  reg [1:0] state;
  reg signed [31:0] x, y;
  reg signed [31:0] z;
  reg [4:0] iteration;
  reg signed [31:0] atan_table [0:ITERATIONS-1];

  // Initialize atan lookup table (precomputed values in Q16.16 format)
  initial begin
    atan_table[0]  = 16'b0110010100010000; // atan(2^-0) = 0.7853981634
    atan_table[1]  = 16'b0011001100110011; // atan(2^-1) = 0.4636476090
    atan_table[2]  = 16'b0001101100110101; // atan(2^-2) = 0.2449786631
    atan_table[3]  = 16'b0000110110110111; // atan(2^-3) = 0.1243549945
    atan_table[4]  = 16'b0000011011011100; // atan(2^-4) = 0.0624188099
    atan_table[5]  = 16'b0000001101101110; // atan(2^-5) = 0.0312398334
    atan_table[6]  = 16'b0000000110110111; // atan(2^-6) = 0.0156237286
    atan_table[7]  = 16'b0000000011011011; // atan(2^-7) = 0.0078123411
    atan_table[8]  = 16'b0000000001101101; // atan(2^-8) = 0.0039062301
    atan_table[9]  = 16'b0000000000110110; // atan(2^-9) = 0.0019531226
    atan_table[10] = 16'b0000000000011011; // atan(2^-10) = 0.0009765622
    atan_table[11] = 16'b0000000000001101; // atan(2^-11) = 0.0004882812
    atan_table[12] = 16'b0000000000000110; // atan(2^-12) = 0.0002441406
    atan_table[13] = 16'b0000000000000011; // atan(2^-13) = 0.0001220703
    atan_table[14] = 16'b0000000000000001; // atan(2^-14) = 0.0000610352
    atan_table[15] = 16'b0000000000000000; // atan(2^-15) = 0.0000305176
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      angle <= 0;
      iteration <= 0;
      x <= 0;
      y <= 0;
      z <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            // Initialize values based on quadrant
            if (a === 0 && b === 0) begin
              angle <= 0;
              done <= 1;
              state <= DONE;
            end else begin
              // Scale inputs to Q16.16 format
              x <= a << Q_FORMAT;
              y <= b << Q_FORMAT;
              z <= 0;
              
              // Adjust for quadrant
              if (a[15]) begin // a is negative
                if (b[15]) begin // b is negative (quadrant III)
                  x <= -x;
                  y <= -y;
                  z <= -32'h0001921F; // -pi
                end else begin // b is positive (quadrant II)
                  x <= -x;
                  z <= 32'h0001921F; // pi
                end
              end else begin // a is positive
                if (b[15]) begin // b is negative (quadrant IV)
                  y <= -y;
                  z <= 0;
                end // else quadrant I, no adjustment needed
              end
              
              iteration <= 0;
              state <= CALCULATING;
              done <= 0;
            end
          end
        end
        
        CALCULATING: begin
          if (iteration < ITERATIONS) begin
            // CORDIC iteration
            if (y[31]) begin // y is negative
              x <= x + (y >>> iteration);
              y <= y - (x >>> iteration);
              z <= z - atan_table[iteration];
            end else begin
              x <= x - (y >>> iteration);
              y <= y + (x >>> iteration);
              z <= z + atan_table[iteration];
            end
            iteration <= iteration + 1;
          end else begin
            // Final adjustment for quadrant
            if (a[15] && !b[15]) begin // quadrant II
              angle <= z;
            end else if (a[15] && b[15]) begin // quadrant III
              angle <= z - 32'h0001921F; // -pi
            end else if (!a[15] && b[15]) begin // quadrant IV
              angle <= z;
            end else begin // quadrant I
              angle <= z;
            end
            state <= DONE;
            done <= 1;
          end
        end
        
        DONE: begin
          if (start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule