module rect_intersection_area (
  input clk,
  input rst_n,
  input start,
  input [15:0] w,
  input [15:0] h,
  input [15:0] alpha_deg,
  output reg [31:0] area,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PRECOMPUTE,
    CALCULATE,
    DONE
  } state_t;

  state_t state = IDLE;
  reg [9:0] cycle_count = 0;

  // Internal registers for computation
  reg [15:0] alpha_norm;
  reg [15:0] A, B;
  reg [15:0] t_scaled;
  reg [15:0] sin_alpha, cos_alpha, tan_alpha;
  reg [15:0] temp1, temp2, temp3, temp4;
  reg [31:0] area_temp;

  // Precomputed lookup tables for trig functions (Q16.16)
  reg [15:0] sin_lut [0:90];
  reg [15:0] cos_lut [0:90];
  reg [15:0] tan_lut [0:90];

  // Initialize lookup tables (simplified for synthesis)
  initial begin
    // In real implementation, these would be precomputed values
    // Here we just initialize to zero for synthesis
    for (int i = 0; i <= 90; i++) begin
      sin_lut[i] = 0;
      cos_lut[i] = 0;
      tan_lut[i] = 0;
    end
    // Example values (in real design, these would be accurate)
    sin_lut[0] = 0;
    sin_lut[30] = 16384; // sin(30°) = 0.5
    sin_lut[45] = 23170; // sin(45°) ≈ 0.7071
    sin_lut[60] = 27415; // sin(60°) ≈ 0.8660
    sin_lut[90] = 32768; // sin(90°) = 1.0

    cos_lut[0] = 32768; // cos(0°) = 1.0
    cos_lut[30] = 27415; // cos(30°) ≈ 0.8660
    cos_lut[45] = 23170; // cos(45°) ≈ 0.7071
    cos_lut[60] = 16384; // cos(60°) = 0.5
    cos_lut[90] = 0;

    tan_lut[0] = 0;
    tan_lut[30] = 16384; // tan(30°) ≈ 0.5774
    tan_lut[45] = 32768; // tan(45°) = 1.0
    tan_lut[60] = 57735; // tan(60°) ≈ 1.732
    tan_lut[90] = 0; // undefined, but we'll handle this case separately
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cycle_count <= 0;
      area <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PRECOMPUTE;
            cycle_count <= 0;
            done <= 0;
          end
        end

        PRECOMPUTE: begin
          if (cycle_count == 0) begin
            // Normalize angle
            if (alpha_deg > 90*65536) begin
              alpha_norm <= 180*65536 - alpha_deg;
            end else begin
              alpha_norm <= alpha_deg;
            end

            // Ensure A >= B
            if (w >= h) begin
              A <= w;
              B <= h;
            end else begin
              A <= h;
              B <= w;
            end
          end

          cycle_count <= cycle_count + 1;
          if (cycle_count == 10) begin
            state <= CALCULATE;
            cycle_count <= 0;
          end
        end

        CALCULATE: begin
          if (cycle_count == 0) begin
            // Special cases
            if (alpha_norm == 0) begin
              area_temp <= $signed({w, 16'h0}) * $signed({h, 16'h0});
              state <= DONE;
            end else if (alpha_norm == 90*65536) begin
              temp1 <= (w < h) ? w : h;
              area_temp <= $signed({temp1, 16'h0}) * $signed({temp1, 16'h0});
              state <= DONE;
            end else begin
              // General case
              // Compute tan(alpha/2)
              temp1 <= alpha_norm / 2;
              temp2 <= temp1 / 65536; // Convert to degrees
              if (temp2 > 90) temp2 = 90;
              tan_alpha <= tan_lut[temp2];

              // Compute t = tan(alpha/2)
              t_scaled <= tan_alpha;

              // Compute B/A
              temp3 <= (B << 16) / A; // Q16.16 division

              // Compare t and B/A
              if (t_scaled > temp3) begin
                // area = B*B / sin(alpha)
                temp1 <= alpha_norm / 65536;
                if (temp1 > 90) temp1 = 90;
                sin_alpha <= sin_lut[temp1];
                temp2 <= (B * B) << 16; // Q16.16
                area_temp <= $signed({temp2, 16'h0}) / $signed({sin_alpha, 16'h0});
              end else begin
                // area = A*B - ((A - B*t)^2 + (B - A*t)^2) * tan(alpha) / 4
                temp1 <= (A << 16) - (B * t_scaled); // A - B*t (Q16.16)
                temp2 <= (B << 16) - (A * t_scaled); // B - A*t (Q16.16)
                temp3 <= (temp1 * temp1) + (temp2 * temp2); // (A-B*t)^2 + (B-A*t)^2
                temp4 <= temp3 * tan_alpha; // Multiply by tan(alpha)
                temp1 <= (A * B) << 16; // A*B (Q16.16)
                area_temp <= $signed({temp1, 16'h0}) - ($signed({temp4, 16'h0}) / 4);
              end
            end
          end

          cycle_count <= cycle_count + 1;
          if (cycle_count == 10) begin
            state <= DONE;
          end
        end

        DONE: begin
          area <= area_temp;
          done <= 1;
          if (start) begin
            state <= IDLE;
            done <= 0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule