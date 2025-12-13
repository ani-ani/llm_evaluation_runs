module water_height_calculator(
  input  clk,
  input  rst_n,
  input  start,
  input  [3:0]  N_vertices,
  input  [31:0] D_depth,      // Q16.16
  input  [31:0] L_liters,     // Q16.16 (used as volume units)
  input  signed [11:0] vertices [0:7][0:1], // [i][0]=x, [i][1]=y]
  output reg [31:0] height,   // Q16.16
  output reg done
);

  // Fixed-point parameters
  localparam int Q      = 16;
  localparam int ITER   = 16;

  // State
  reg [4:0]  iter_cnt;
  reg [31:0] low_h;
  reg [31:0] high_h;
  reg [31:0] mid_h;
  reg        busy;

  // Internal wires/regs for area computation
  integer i_idx;
  reg signed [27:0] vi_y_q;       // vertex y in Q16.16
  reg signed [27:0] vj_y_q;
  reg signed [27:0] vi_x_q;
  reg signed [27:0] vj_x_q;
  reg signed [32:0] dy;           // mid_h - vi_y_q
  reg signed [32:0] dy_next;      // vj_y_q - vi_y_q
  reg [63:0]        seg_contrib;  // partial area contribution (unsigned magnitude)
  reg [63:0]        total_area;   // accumulated area in Q16.16

  // Combinational: compute area up to height h (Q16.16)
  // Assumes polygon convex and ordered; water area is intersection of polygon with y <= h.
  // For simplicity and determinism, implement a bounded loop.
  function automatic [63:0] area_at_height(input [31:0] h_q16);
    integer k;
    integer nv;
    reg signed [27:0] x1_q, y1_q, x2_q, y2_q;
    reg signed [63:0] a_seg;
    reg signed [63:0] acc;
    reg signed [32:0] dy1, dy2;
    reg signed [47:0] base_q;
    reg signed [63:0] h_minus_y1;
    reg signed [63:0] h_minus_y2;
    reg signed [63:0] tri1;
    reg signed [63:0] tri2;
    reg signed [63:0] trap;
    begin
      nv = N_vertices;
      acc = 64'sd0;
      if (nv < 3) begin
        area_at_height = 64'd0;
      end else begin
        for (k = 0; k < 8; k = k + 1) begin
          if (k < nv) begin
            // current vertex
            x1_q = {vertices[k][0], Q{1'b0}}; // x * 2^Q
            y1_q = {vertices[k][1], Q{1'b0}}; // y * 2^Q
            // next vertex index
            if (k == nv-1) begin
              x2_q = {vertices[0][0], Q{1'b0}};
              y2_q = {vertices[0][1], Q{1'b0}};
            end else begin
              x2_q = {vertices[k+1][0], Q{1'b0}};
              y2_q = {vertices[k+1][1], Q{1'b0}};
            end

            // Clip edge to [min(y1,y2), min(max(y1,y2), h)] with respect to water surface y=h.
            // We compute signed area contribution for portion with y <= h.

            // Case 1: both vertices above h -> no contribution
            if ((y1_q >= h_q16) && (y2_q >= h_q16)) begin
              a_seg = 64'sd0;

            // Case 2: both vertices below or on h -> full edge contribution
            end else if ((y1_q <= h_q16) && (y2_q <= h_q16)) begin
              // Trapezoid area under the edge down to y=0 is irrelevant; we need up to h.
              // To approximate water intersection area, we treat x as constant along y (vertical slices).
              // Effective contribution: 0.5 * (x1 + x2) * (min(h,y_max) - min(h,y_min))
              // Here both <= h, so height range = ( (y1+y2)/2 w.r.t 0 ), but we only need up to those y.
              // For deterministic implementation, approximate with vertical projection from 0:

              dy1 = y1_q; // distance from 0
              dy2 = y2_q;
              // Use absolute of average x times vertical span between y1 and y2.
              base_q = (x1_q + x2_q) >>> 1; // average x
              trap   = base_q * (dy2 - dy1); // Q16.16 * Q16.16 -> Q32.32
              a_seg  = trap >>> Q;           // back to Q16.16

            // Case 3: edge crosses h: one below, one above
            end else begin
              // Find intersection point with y = h.
              // t = (h - y1)/(y2 - y1) in Q16.16
              dy1 = h_q16 - y1_q;        // Q16.16
              dy2 = y2_q - y1_q;         // Q16.16
              if (dy2 == 0) begin
                a_seg = 64'sd0;
              end else begin
                // t_q = (dy1 << Q) / dy2; -> Q16.16
                // x_int = x1 + t_q*(x2 - x1) >> Q
                reg signed [63:0] t_q;
                reg signed [63:0] x_int_q;
                reg signed [27:0] dx_q;
                dx_q   = x2_q - x1_q;
                t_q    = ( ( { {32{dy1[32]}}, dy1 } ) <<< Q ) / dy2; // extend & shift
                x_int_q= x1_q + ( (dx_q * t_q) >>> Q );

                if (y1_q < h_q16) begin
                  // keep portion from y1 to h
                  h_minus_y1 = h_q16 - y1_q; // Q16.16
                  base_q     = (x1_q + x_int_q) >>> 1;
                  tri1       = base_q * h_minus_y1; // Q32.32
                  a_seg      = tri1 >>> Q;          // Q16.16
                end else begin
                  // keep portion from y2 to h
                  h_minus_y2 = h_q16 - y2_q; // Q16.16 (negative since y2<h in this branch swapped)
                  base_q     = (x2_q + x_int_q) >>> 1;
                  tri2       = base_q * h_minus_y2; // Q32.32
                  a_seg      = tri2 >>> Q;          // Q16.16
                end
              end
            end

            acc = acc + a_seg;
          end
        end

        // Return absolute value as area magnitude
        if (acc < 0) area_at_height = -acc; else area_at_height = acc;
      end
    end
  endfunction

  // Sequential binary search controller
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      iter_cnt <= 5'd0;
      low_h    <= 32'd0;
      high_h   <= 32'd0;
      mid_h    <= 32'd0;
      busy     <= 1'b0;
      done     <= 1'b0;
      height   <= 32'd0;
    end else begin
      done <= 1'b0;

      if (start && !busy) begin
        // Initialize binary search range [0, D_depth]
        low_h    <= 32'd0;
        high_h   <= D_depth;
        iter_cnt <= 5'd0;
        busy     <= 1'b1;
      end else if (busy) begin
        // Perform one binary search iteration per cycle
        mid_h = (low_h + high_h) >> 1;

        // Compute area at mid_h
        total_area = area_at_height(mid_h); // Q16.16

        // Compare D_depth * area(mid_h) with L_liters
        // volume_est = D_depth * total_area >> Q
        // Both D_depth and total_area are Q16.16 -> product Q32.32
        // Shift right Q to get Q16.16
        seg_contrib = ( ( ( {32'd0, D_depth} ) * total_area ) >> Q );

        if (seg_contrib > L_liters) begin
          // too much volume => lower height
          high_h <= mid_h;
        end else begin
          // too little volume => raise height
          low_h <= mid_h;
        end

        iter_cnt <= iter_cnt + 1'b1;

        if (iter_cnt == (ITER-1)) begin
          // Final iteration complete; choose low_h as result
          height <= low_h;
          done   <= 1'b1;
          busy   <= 1'b0;
        end
      end
    end
  end

endmodule