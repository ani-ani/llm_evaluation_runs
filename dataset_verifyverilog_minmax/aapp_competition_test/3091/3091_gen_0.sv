module kenken_section_solver (
  input [1:0] n,           // puzzle size (fixed 4)
  input [1:0] m,           // number of cells: 2 or 3
  input [4:0] t,           // target value
  input [1:0] op,          // 00:'+', 01:'-', 10:'*', 11:'/'
  input [1:0] pos0_row, pos0_col, // position 0
  input [1:0] pos1_row, pos1_col, // position 1
  input [1:0] pos2_row, pos2_col, // position 2 (unused when m=2)
  output reg [2:0] count
);

  // Helpers to compare positions
  function same_row (input [1:0] r1, c1, r2, c2);
    same_row = (r1 == r2);
  endfunction
  function same_col (input [1:0] r1, c1, r2, c2);
    same_col = (c1 == c2);
  endfunction

  // Check no duplicates in same row or column for 2 cells (a@pos0, b@pos1)
  function ok2 (input [1:0] a, b);
    reg row_conflict, col_conflict;
    row_conflict = same_row(pos0_row, pos0_col, pos1_row, pos1_col) && (a == b);
    col_conflict = same_col(pos0_row, pos0_col, pos1_row, pos1_col) && (a == b);
    ok2 = !(row_conflict || col_conflict);
  endfunction

  // Check no duplicates in same row or column for 3 cells (a@pos0, b@pos1, c@pos2)
  function ok3 (input [1:0] a, b, c);
    reg row01, col01, row02, col02, row12, col12;
    row01 = same_row(pos0_row, pos0_col, pos1_row, pos1_col) && (a == b);
    col01 = same_col(pos0_row, pos0_col, pos1_row, pos1_col) && (a == b);
    row02 = same_row(pos0_row, pos0_col, pos2_row, pos2_col) && (a == c);
    col02 = same_col(pos0_row, pos0_col, pos2_row, pos2_col) && (a == c);
    row12 = same_row(pos1_row, pos1_col, pos2_row, pos2_col) && (b == c);
    col12 = same_col(pos1_row, pos1_col, pos2_row, pos2_col) && (b == c);
    ok3 = !(row01 || col01 || row02 || col02 || row12 || col12);
  endfunction

  // Check operator result for 2 cells
  function op2_ok (input [1:0] a, b);
    reg op_is_add, op_is_sub, op_is_mul, op_is_div;
    op_is_add = (op == 2'b00);
    op_is_sub = (op == 2'b01);
    op_is_mul = (op == 2'b10);
    op_is_div = (op == 2'b11);
    // For '-' and '/', use absolute difference and integer division without remainder.
    op2_ok = 1'b0;
    if (op_is_add) begin
      if ((a + b) == t) op2_ok = 1'b1;
    end else if (op_is_sub) begin
      if ((a > b) ? ((a - b) == t) : ((b - a) == t)) op2_ok = 1'b1;
    end else if (op_is_mul) begin
      if ((a * b) == t) op2_ok = 1'b1;
    end else if (op_is_div) begin
      if ((b != 0) && (a % b == 0) && (a / b == t)) op2_ok = 1'b1;
    end
  endfunction

  // Check operator result for 3 cells (left-associative)
  function op3_ok (input [1:0] a, b, c);
    reg op_is_add, op_is_sub, op_is_mul, op_is_div;
    op_is_add = (op == 2'b00);
    op_is_sub = (op == 2'b01);
    op_is_mul = (op == 2'b10);
    op_is_div = (op == 2'b11);
    op3_ok = 1'b0;
    if (op_is_add) begin
      if (((a + b) + c) == t) op3_ok = 1'b1;
    end else if (op_is_sub) begin
      if ((((a > b) ? (a - b) : (b - a)) > c) ?
          (((((a > b) ? (a - b) : (b - a)) - c) == t)) :
          (((c - ((a > b) ? (a - b) : (b - a))) == t))) op3_ok = 1'b1;
    end else if (op_is_mul) begin
      if (((a * b) * c) == t) op3_ok = 1'b1;
    end else if (op_is_div) begin
      if ((b != 0) && ((a / b) * b == a) && (c != 0) && ((((a / b) / c) * c) == (a / b)) && ((a / b) / c) == t) op3_ok = 1'b1;
    end
  endfunction

  // Aggregation of all valid permutations
  always @(*) begin
    count = 3'd0;
    if (m == 2'd2) begin
      for (int a = 1; a <= 4; a++) begin
        for (int b = 1; b <= 4; b++) begin
          if (a != b) begin
            if (ok2(a, b) && op2_ok(a, b)) count = count + 1'b1;
          end
        end
      end
    end else begin // m == 3 (ignores pos2 when m=2)
      for (int a = 1; a <= 4; a++) begin
        for (int b = 1; b <= 4; b++) begin
          if (a != b) begin
            for (int c = 1; c <= 4; c++) begin
              if ((c != a) && (c != b)) begin
                if (ok3(a, b, c) && op3_ok(a, b, c)) count = count + 1'b1;
              end
            end
          end
        end
      end
    end
  end

endmodule
