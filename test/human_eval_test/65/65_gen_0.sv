module circular_shift_digits(
  input  [15:0] num,
  input  [3:0]  shift,
  output [15:0] shifted_digits
);

  // Extract BCD digits (assumed 0-9 each)
  wire [3:0] d0 = num[3:0];    // units (LSD, index 0)
  wire [3:0] d1 = num[7:4];    // tens  (index 1)
  wire [3:0] d2 = num[11:8];   // hundreds (index 2)
  wire [3:0] d3 = num[15:12];  // thousands (MSD for 4-digit, index 3)

  // Determine number of significant digits (num_digits)
  // Based on numeric value (0-9999), using BCD comparison
  wire ge_1000 = (d3 != 4'd0);

  wire ge_100 = (
    (!ge_1000) &&
    (d2 != 4'd0)
  ) || ge_1000;

  wire ge_10 = (
    (!ge_1000 && !ge_100) &&
    (d1 != 4'd0)
  ) || ge_100 || ge_1000;

  wire [1:0] num_digits = ge_1000 ? 2'd4 :
                           ge_100  ? 2'd3 :
                           ge_10   ? 2'd2 :
                                     2'd1;

  // Precompute index positions of significant digits (LSD-first): [d0,d1,d2,d3]
  // We will form result digits r0 (units) .. r3 (thousands)
  reg [3:0] r0, r1, r2, r3;

  // Helper wires for comparisons
  wire shift_ge_1 = (shift >= 4'd1);
  wire shift_ge_2 = (shift >= 4'd2);
  wire shift_ge_3 = (shift >= 4'd3);
  wire shift_ge_4 = (shift >= 4'd4);

  // shift >= num_digits conditions
  wire shift_ge_nd_1 = 1'b1; // always true for num_digits=1
  wire shift_ge_nd_2 = shift_ge_2 || (shift_ge_1 && !shift_ge_2 && (2'd2 <= 2'd1)); // simplified later
  // Instead of overcomplicating, do explicit per num_digits in the case

  always @* begin
    // default: pass-through
    r0 = d0;
    r1 = d1;
    r2 = d2;
    r3 = d3;

    case (num_digits)
      2'd1: begin
        // Only d0 is significant
        // If shift >= 1: reverse(only one digit) -> same
        // Else circular shift with length 1 -> same
        r0 = d0;
        // Higher digits preserved as-is
        r1 = d1;
        r2 = d2;
        r3 = d3;
      end

      2'd2: begin
        // Significant: [d0,d1]
        if (shift >= 4'd2) begin
          // Reverse first 2 digits: [d0,d1] -> [d1,d0]
          r0 = d1;
          r1 = d0;
        end else begin
          // Circular right shift by shift (0 or 1) over 2 digits
          case (shift[0])
            1'b0: begin
              // shift=0
              r0 = d0;
              r1 = d1;
            end
            1'b1: begin
              // shift=1
              r0 = d1; // new LSD
              r1 = d0;
            end
          endcase
        end
        // Non-significant upper digits preserved
        r2 = d2;
        r3 = d3;
      end

      2'd3: begin
        // Significant: [d0,d1,d2]
        if (shift >= 4'd3) begin
          // Reverse [d0,d1,d2] -> [d2,d1,d0]
          r0 = d2;
          r1 = d1;
          r2 = d0;
        end else begin
          // Circular right shift by shift (0-2) over 3 digits
          case (shift[1:0])
            2'd0: begin
              r0 = d0;
              r1 = d1;
              r2 = d2;
            end
            2'd1: begin
              // shift=1: [d0,d1,d2] -> [d2,d0,d1]
              r0 = d2;
              r1 = d0;
              r2 = d1;
            end
            2'd2: begin
              // shift=2: [d0,d1,d2] -> [d1,d2,d0]
              r0 = d1;
              r1 = d2;
              r2 = d0;
            end
            default: begin
              r0 = d0;
              r1 = d1;
              r2 = d2;
            end
          endcase
        end
        // Non-significant upper digit preserved
        r3 = d3;
      end

      default: begin
        // num_digits = 4: Significant: [d0,d1,d2,d3]
        if (shift >= 4'd4) begin
          // Reverse [d0,d1,d2,d3] -> [d3,d2,d1,d0]
          r0 = d3;
          r1 = d2;
          r2 = d1;
          r3 = d0;
        end else begin
          // Circular right shift by shift (0-3) over 4 digits
          case (shift[1:0])
            2'd0: begin
              r0 = d0;
              r1 = d1;
              r2 = d2;
              r3 = d3;
            end
            2'd1: begin
              // [d0,d1,d2,d3] -> [d3,d0,d1,d2]
              r0 = d3;
              r1 = d0;
              r2 = d1;
              r3 = d2;
            end
            2'd2: begin
              // [d0,d1,d2,d3] -> [d2,d3,d0,d1]
              r0 = d2;
              r1 = d3;
              r2 = d0;
              r3 = d1;
            end
            2'd3: begin
              // [d0,d1,d2,d3] -> [d1,d2,d3,d0]
              r0 = d1;
              r1 = d2;
              r2 = d3;
              r3 = d0;
            end
          endcase
        end
      end
    endcase
  end

  // Pack output: [15:12]=digit3(MSD), [11:8]=digit2, [7:4]=digit1, [3:0]=digit0(LSD)
  assign shifted_digits = {r3, r2, r1, r0};

endmodule