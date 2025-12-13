module kenken_section_solver(
  input  [1:0] n,
  input  [1:0] m,
  input  [4:0] t,
  input  [1:0] op,
  input  [1:0] pos0_row,
  input  [1:0] pos0_col,
  input  [1:0] pos1_row,
  input  [1:0] pos1_col,
  input  [1:0] pos2_row,
  input  [1:0] pos2_col,
  output [2:0] count
);

  // Digits are 1..4. We brute-force all permutations for m=2 or m=3.
  // For m=2: 4*3 = 12 permutations.
  // For m=3: 4*3*2 = 24 permutations.

  // Helper localparams for operations
  localparam OP_ADD = 2'b00;
  localparam OP_SUB = 2'b01;
  localparam OP_MUL = 2'b10;
  localparam OP_DIV = 2'b11;

  // Combinational logic
  reg [2:0] count_r;
  assign count = count_r;

  // Check uniqueness constraint: no duplicated digits in same row or column.
  function automatic bit unique_ok_m2(
    input [1:0] d0,
    input [1:0] d1,
    input [1:0] r0,
    input [1:0] c0,
    input [1:0] r1,
    input [1:0] c1
  );
    unique_ok_m2 = 1'b1;
    if ((r0 == r1) || (c0 == c1)) begin
      if (d0 == d1)
        unique_ok_m2 = 1'b0;
    end
  endfunction

  function automatic bit unique_ok_m3(
    input [1:0] d0,
    input [1:0] d1,
    input [1:0] d2,
    input [1:0] r0,
    input [1:0] c0,
    input [1:0] r1,
    input [1:0] c1,
    input [1:0] r2,
    input [1:0] c2
  );
    bit ok;
    ok = 1'b1;

    // (0,1)
    if ((r0 == r1) || (c0 == c1)) begin
      if (d0 == d1) ok = 1'b0;
    end
    // (0,2)
    if (ok && ((r0 == r2) || (c0 == c2))) begin
      if (d0 == d2) ok = 1'b0;
    end
    // (1,2)
    if (ok && ((r1 == r2) || (c1 == c2))) begin
      if (d1 == d2) ok = 1'b0;
    end

    unique_ok_m3 = ok;
  endfunction

  // Operation checks for m=2
  function automatic bit op_ok_m2(
    input [1:0] d0,
    input [1:0] d1,
    input [4:0] target,
    input [1:0] op_sel
  );
    int v0, v1;
    int res;
    bit ok;
    begin
      v0 = d0 + 1; // map 0..3 -> 1..4
      v1 = d1 + 1;
      ok = 1'b0;
      case (op_sel)
        OP_ADD: begin
          res = v0 + v1;
          if (res == target) ok = 1'b1;
        end
        OP_SUB: begin
          res = (v0 >= v1) ? (v0 - v1) : (v1 - v0);
          if (res == target) ok = 1'b1;
        end
        OP_MUL: begin
          res = v0 * v1;
          if (res == target) ok = 1'b1;
        end
        OP_DIV: begin
          if ((v0 >= v1) && (v1 != 0) && (v0 % v1 == 0)) begin
            res = v0 / v1;
          end else if ((v1 > v0) && (v0 != 0) && (v1 % v0 == 0)) begin
            res = v1 / v0;
          end else begin
            res = -1;
          end
          if (res == target) ok = 1'b1;
        end
        default: ok = 1'b0;
      endcase
      op_ok_m2 = ok;
    end
  endfunction

  // Operation checks for m=3
  // For + and *: use all 3 digits.
  // For - and /: consider all orderings of applying binary op across 3 digits
  // (since result must be independent of ordering by specification via search).
  function automatic bit op_ok_m3(
    input [1:0] d0,
    input [1:0] d1,
    input [1:0] d2,
    input [4:0] target,
    input [1:0] op_sel
  );
    int v0, v1, v2;
    int res;
    bit ok;
    begin
      v0 = d0 + 1;
      v1 = d1 + 1;
      v2 = d2 + 1;
      ok = 1'b0;
      case (op_sel)
        OP_ADD: begin
          res = v0 + v1 + v2;
          if (res == target) ok = 1'b1;
        end
        OP_MUL: begin
          res = v0 * v1 * v2;
          if (res == target) ok = 1'b1;
        end
        OP_SUB: begin
          // Evaluate all permutations of applying absolute difference pairwise:
          // t == |a - b - c| in any order is ambiguous; instead, follow KenKen style:
          // commonly cage uses all numbers with any ordering of minus such that
          // a - b - c = target for some permutation (no absolute at final).
          // But spec only defines abs when m=2. For m=3, we implement standard
          // puzzle approach: check if any permutation over (x,y,z) with
          // ((x - y) - z) == target.
          int x0, x1, x2;
          // (v0,v1,v2)
          x0 = v0 - v1 - v2;
          if (x0 == target) ok = 1'b1;
          // (v0,v2,v1)
          if (!ok) begin x0 = v0 - v2 - v1; if (x0 == target) ok = 1'b1; end
          // (v1,v0,v2)
          if (!ok) begin x0 = v1 - v0 - v2; if (x0 == target) ok = 1'b1; end
          // (v1,v2,v0)
          if (!ok) begin x0 = v1 - v2 - v0; if (x0 == target) ok = 1'b1; end
          // (v2,v0,v1)
          if (!ok) begin x0 = v2 - v0 - v1; if (x0 == target) ok = 1'b1; end
          // (v2,v1,v0)
          if (!ok) begin x0 = v2 - v1 - v0; if (x0 == target) ok = 1'b1; end
        end
        OP_DIV: begin
          // For division: check if for any permutation (x,y,z)
          // x / y / z is integer at each step and equals target.
          int num;
          // (v0,v1,v2)
          if (v1 != 0 && v2 != 0 && (v0 % v1 == 0) && ((v0 / v1) % v2 == 0)) begin
            num = (v0 / v1) / v2;
            if (num == target) ok = 1'b1;
          end
          // (v0,v2,v1)
          if (!ok && v2 != 0 && v1 != 0 && (v0 % v2 == 0) && ((v0 / v2) % v1 == 0)) begin
            num = (v0 / v2) / v1;
            if (num == target) ok = 1'b1;
          end
          // (v1,v0,v2)
          if (!ok && v0 != 0 && v2 != 0 && (v1 % v0 == 0) && ((v1 / v0) % v2 == 0)) begin
            num = (v1 / v0) / v2;
            if (num == target) ok = 1'b1;
          end
          // (v1,v2,v0)
          if (!ok && v2 != 0 && v0 != 0 && (v1 % v2 == 0) && ((v1 / v2) % v0 == 0)) begin
            num = (v1 / v2) / v0;
            if (num == target) ok = 1'b1;
          end
          // (v2,v0,v1)
          if (!ok && v0 != 0 && v1 != 0 && (v2 % v0 == 0) && ((v2 / v0) % v1 == 0)) begin
            num = (v2 / v0) / v1;
            if (num == target) ok = 1'b1;
          end
          // (v2,v1,v0)
          if (!ok && v1 != 0 && v0 != 0 && (v2 % v1 == 0) && ((v2 / v1) % v0 == 0)) begin
            num = (v2 / v1) / v0;
            if (num == target) ok = 1'b1;
          end
        end
        default: ok = 1'b0;
      endcase
      op_ok_m3 = ok;
    end
  endfunction

  integer i, j, k;
  reg [1:0] d0, d1, d2;
  reg valid;

  always @* begin
    count_r = 3'd0;

    // Problem specifies n = 4 only, but we don't hard fail for other values.

    if (m == 2) begin
      // Enumerate all ordered pairs (d0, d1) from digits 0..3 -> 1..4
      for (i = 0; i < 4; i = i + 1) begin
        for (j = 0; j < 4; j = j + 1) begin
          if (i != j) begin
            d0 = i[1:0];
            d1 = j[1:0];

            // Check uniqueness constraints across cells
            valid = unique_ok_m2(d0, d1,
                                 pos0_row, pos0_col,
                                 pos1_row, pos1_col);

            // Check operation condition
            if (valid) begin
              if (op_ok_m2(d0, d1, t, op)) begin
                count_r = count_r + 1'b1;
              end
            end
          end
        end
      end
    end else if (m == 3) begin
      // Enumerate all ordered triplets (d0, d1, d2) from digits 0..3 -> 1..4
      for (i = 0; i < 4; i = i + 1) begin
        for (j = 0; j < 4; j = j + 1) begin
          if (j != i) begin
            for (k = 0; k < 4; k = k + 1) begin
              if ((k != i) && (k != j)) begin
                d0 = i[1:0];
                d1 = j[1:0];
                d2 = k[1:0];

                // Check uniqueness constraints across cells
                valid = unique_ok_m3(d0, d1, d2,
                                     pos0_row, pos0_col,
                                     pos1_row, pos1_col,
                                     pos2_row, pos2_col);

                // Check operation condition
                if (valid) begin
                  if (op_ok_m3(d0, d1, d2, t, op)) begin
                    count_r = count_r + 1'b1;
                  end
                end
              end
            end
          end
        end
      end
    end else begin
      // For m not 2 or 3: no valid arrangements per spec
      count_r = 3'd0;
    end
  end

endmodule