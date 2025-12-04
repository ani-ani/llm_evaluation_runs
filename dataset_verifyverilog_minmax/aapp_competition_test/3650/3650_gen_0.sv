module sliding_blocks_check(
  input [1:0] init_r, init_c,
  input [3:0][1:0] target_r, target_c,
  input [1:0] block_count,
  output reg possible
);

  // Helper: clear straight path between (r1,c1) and (r2,c2) along row or column with no other blocks in between.
  // Occupying cells are: (r0,c0) and all targets in [0:block_count-1].
  function automatic logic path_clear(
    input [1:0] r1, c1, r2, c2,
    input [1:0] r0, c0,
    input [3:0][1:0] tr, tc,
    input [1:0] bcnt
  );
    logic [1:0] r_min, r_max, c_min, c_max;
    logic same_row, same_col, i, o1, o2, o3;
    integer k;
    begin
      same_row = (r1 == r2);
      same_col = (c1 == c2);
      if (!same_row && !same_col) begin
        path_clear = 1'b0; return;
      end
      if (same_row) begin
        r_min = (c1 < c2) ? c1 : c2;
        r_max = (c1 < c2) ? c2 : c1;
        o1 = 1'b0; // exclude end points
        o2 = (tr[0]==r1 && tc[0]>=r_min && tc[0]<=r_max && !(tr[0]==r2 && tc[0]==c2) && !(tr[0]==r1 && tc[0]==c1));
        o3 = (tr[1]==r1 && tc[1]>=r_min && tc[1]<=r_max && !(tr[1]==r2 && tc[1]==c2) && !(tr[1]==r1 && tc[1]==c1));
        for (k=2; k<4; k++) begin
          o1 = o1 || (tr[k]==r1 && tc[k]>=r_min && tc[k]<=r_max && !(tr[k]==r2 && tc[k]==c2) && !(tr[k]==r1 && tc[k]==c1));
        end
        o1 = o1 || o2 || o3;
      end else begin // same column
        r_min = (r1 < r2) ? r1 : r2;
        r_max = (r1 < r2) ? r2 : r1;
        o1 = 1'b0; // exclude end points
        o2 = (tr[0]>=r_min && tr[0]<=r_max && tc[0]==c1 && !(tr[0]==r2 && tc[0]==c2) && !(tr[0]==r1 && tc[0]==c1));
        o3 = (tr[1]>=r_min && tr[1]<=r_max && tc[1]==c1 && !(tr[1]==r2 && tc[1]==c2) && !(tr[1]==r1 && tc[1]==c1));
        for (k=2; k<4; k++) begin
          o1 = o1 || (tr[k]>=r_min && tr[k]<=r_max && tc[k]==c1 && !(tr[k]==r2 && tc[k]==c2) && !(tr[k]==r1 && tc[k]==c1));
        end
        o1 = o1 || o2 || o3;
      end
      // Occupied by initial block between endpoints (only matters if it is strictly between)
      i = 1'b0;
      if (same_row) begin
        i = (r0==r1 && ((c0>c_min && c0<c_max) || (c0>c_max && c0<c_min)));
      end else begin
        i = (c0==c1 && ((r0>r_min && r0<r_max) || (r0>r_max && r0<r_min)));
      end
      path_clear = !(i || o1);
    end
  endfunction

  // Checks:
  // 1) No target overlaps the initial block
  // 2) Every target has a clear line-of-sight to the initial block (row or column)
  // 3) No cycles: a valid structure is a tree if and only if each target can see the initial block (as above),
  //    because the only possible edge set is to the initial block; any extra edge would require non-aligned targets
  //    which are not reachable, and two aligned targets would create a cycle otherwise.
  logic no_overlap, all_reachable, ok, ok0, ok1, ok2, ok3;
  integer j;

  always @* begin
    no_overlap = 1'b1;
    for (j=0; j<4; j++) begin
      if (j < block_count) begin
        if (target_r[j]==init_r && target_c[j]==init_c) no_overlap = 1'b0;
      end
    end

    all_reachable = 1'b1;
    for (j=0; j<4; j++) begin
      if (j < block_count) begin
        if (!path_clear(target_r[j], target_c[j], init_r, init_c, init_r, init_c, target_r, target_c, block_count)) begin
          all_reachable = 1'b0;
        end
      end
    end

    ok  = no_overlap && all_reachable;
    ok0 = (block_count==0) ? 1'b1 : path_clear(target_r[0], target_c[0], init_r, init_c, init_r, init_c, target_r, target_c, block_count);
    ok1 = (block_count<=1) ? 1'b1 : path_clear(target_r[1], target_c[1], init_r, init_c, init_r, init_c, target_r, target_c, block_count);
    ok2 = (block_count<=2) ? 1'b1 : path_clear(target_r[2], target_c[2], init_r, init_c, init_r, init_c, target_r, target_c, block_count);
    ok3 = (block_count<=3) ? 1'b1 : path_clear(target_r[3], target_c[3], init_r, init_c, init_r, init_c, target_r, target_c, block_count);

    possible = ok && ok0 && ok1 && ok2 && ok3;
  end

endmodule
