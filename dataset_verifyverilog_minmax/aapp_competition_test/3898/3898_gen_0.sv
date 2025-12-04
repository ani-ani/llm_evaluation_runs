module statue_rotator(
  input [7:0][2:0] a,
  input [7:0][2:0] b,
  output reg possible
);
  logic [2:0] a_nz [0:6];
  logic [2:0] b_nz [0:6];
  integer pos_b;
  integer i;

  // Build a_nz and b_nz by removing the single 0 and rotating to start after the 0
  // (wrapping around). If 0 is not found, sets possible=0 later via nz_count.
  always @* begin
    pos_b = -1;
    possible = 1'b0;

    // Build a_nz (non-zero, rotated)
    // nz_count: number of non-zero elements encountered (0..7)
    // it runs from 0 to 7 so that we stop after collecting 7 non-zero elements
    // or after scanning 8 positions.
    for (i = 0; i < 8; i = i + 1) begin
      if (a[(i + 1) % 8] != 3'd0) begin
        a_nz[i] = a[(i + 1) % 8];
      end
    end

    // Build b_nz (non-zero, rotated)
    for (i = 0; i < 8; i = i + 1) begin
      if (b[(i + 1) % 8] != 3'd0) begin
        b_nz[i] = b[(i + 1) % 8];
      end
    end

    // Find the position of b_nz[0] in a_nz
    for (i = 0; i < 7; i = i + 1) begin
      if (a_nz[i] == b_nz[0]) begin
        pos_b = i;
        break;
      end
    end

    // If not found, possible=0
    if (pos_b < 0) begin
      possible = 1'b0;
    end else begin
      // Rotate a_nz to start at pos_b and compare to b_nz
      // possible stays 1 only if all positions match
      for (i = 0; i < 7; i = i + 1) begin
        if (a_nz[(pos_b + i) % 7] != b_nz[i]) begin
          possible = 1'b0;
        end
      end
    end
  end
endmodule
