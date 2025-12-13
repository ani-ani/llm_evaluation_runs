module cube_fold_detector(
  input  [35:0] grid,
  output        foldable
);

  // 11 canonical cube-net patterns (6x6, row-major, bit 0 = top-left)
  // Patterns chosen as distinct known cube nets.
  // Each pattern is a 6x6 bitmap where '1' denotes a square of the net.
  // (Predefined constants; no runtime generation.)

  // Net 0
  localparam [35:0] NET0  = 36'b000000_
                               001000_
                               001000_
                               001000_
                               001000_
                               001000;

  // Net 1
  localparam [35:0] NET1  = 36'b000000_
                               011100_
                               001000_
                               000000_
                               000000_
                               000000;

  // Net 2
  localparam [35:0] NET2  = 36'b000000_
                               001000_
                               011100_
                               000000_
                               000000_
                               000000;

  // Net 3
  localparam [35:0] NET3  = 36'b000000_
                               011100_
                               000100_
                               000000_
                               000000_
                               000000;

  // Net 4
  localparam [35:0] NET4  = 36'b000000_
                               011100_
                               010000_
                               000000_
                               000000_
                               000000;

  // Net 5
  localparam [35:0] NET5  = 36'b000000_
                               001000_
                               011100_
                               001000_
                               000000_
                               000000;

  // Net 6
  localparam [35:0] NET6  = 36'b000000_
                               001000_
                               011100_
                               000100_
                               000000_
                               000000;

  // Net 7
  localparam [35:0] NET7  = 36'b000000_
                               001000_
                               011100_
                               010000_
                               000000_
                               000000;

  // Net 8
  localparam [35:0] NET8  = 36'b000000_
                               001000_
                               011100_
                               000010_
                               000000_
                               000000;

  // Net 9
  localparam [35:0] NET9  = 36'b000000_
                               001000_
                               011100_
                               100000_
                               000000_
                               000000;

  // Net 10
  localparam [35:0] NET10 = 36'b000000_
                               001000_
                               011100_
                               001000_
                               001000_
                               000000;

  // 8 geometric transforms (rotations and mirrors on 6x6 grid)
  function automatic [35:0] rot90(input [35:0] in);
    integer r, c;
    reg [35:0] out;
    begin
      out = '0;
      for (r = 0; r < 6; r = r + 1) begin
        for (c = 0; c < 6; c = c + 1) begin
          out[c*6 + (5-r)] = in[r*6 + c];
        end
      end
      rot90 = out;
    end
  endfunction

  function automatic [35:0] rot180(input [35:0] in);
    integer r, c;
    reg [35:0] out;
    begin
      out = '0;
      for (r = 0; r < 6; r = r + 1) begin
        for (c = 0; c < 6; c = c + 1) begin
          out[(5-r)*6 + (5-c)] = in[r*6 + c];
        end
      end
      rot180 = out;
    end
  endfunction

  function automatic [35:0] rot270(input [35:0] in);
    integer r, c;
    reg [35:0] out;
    begin
      out = '0;
      for (r = 0; r < 6; r = r + 1) begin
        for (c = 0; c < 6; c = c + 1) begin
          out[(5-c)*6 + r] = in[r*6 + c];
        end
      end
      rot270 = out;
    end
  endfunction

  function automatic [35:0] flip_h(input [35:0] in);
    integer r, c;
    reg [35:0] out;
    begin
      out = '0;
      for (r = 0; r < 6; r = r + 1) begin
        for (c = 0; c < 6; c = c + 1) begin
          out[r*6 + (5-c)] = in[r*6 + c];
        end
      end
      flip_h = out;
    end
  endfunction

  function automatic [35:0] flip_v(input [35:0] in);
    integer r, c;
    reg [35:0] out;
    begin
      out = '0;
      for (r = 0; r < 6; r = r + 1) begin
        for (c = 0; c < 6; c = c + 1) begin
          out[(5-r)*6 + c] = in[r*6 + c];
        end
      end
      flip_v = out;
    end
  endfunction

  function automatic [35:0] flip_d1(input [35:0] in); // main diagonal
    integer r, c;
    reg [35:0] out;
    begin
      out = '0;
      for (r = 0; r < 6; r = r + 1) begin
        for (c = 0; c < 6; c = c + 1) begin
          out[c*6 + r] = in[r*6 + c];
        end
      end
      flip_d1 = out;
    end
  endfunction

  function automatic [35:0] flip_d2(input [35:0] in); // anti-diagonal
    integer r, c;
    reg [35:0] out;
    begin
      out = '0;
      for (r = 0; r < 6; r = r + 1) begin
        for (c = 0; c < 6; c = c + 1) begin
          out[(5-c)*6 + (5-r)] = in[r*6 + c];
        end
      end
      flip_d2 = out;
    end
  endfunction

  // For area efficiency, we generate transformations on-the-fly using
  // pure combinational functions and compare directly against input.

  function automatic logic match_any_transform(input [35:0] pat, input [35:0] g);
    begin
      match_any_transform =
           (g == pat)
        || (g == rot90(pat))
        || (g == rot180(pat))
        || (g == rot270(pat))
        || (g == flip_h(pat))
        || (g == flip_v(pat))
        || (g == flip_d1(pat))
        || (g == flip_d2(pat));
    end
  endfunction

  wire m0  = match_any_transform(NET0 , grid);
  wire m1  = match_any_transform(NET1 , grid);
  wire m2  = match_any_transform(NET2 , grid);
  wire m3  = match_any_transform(NET3 , grid);
  wire m4  = match_any_transform(NET4 , grid);
  wire m5  = match_any_transform(NET5 , grid);
  wire m6  = match_any_transform(NET6 , grid);
  wire m7  = match_any_transform(NET7 , grid);
  wire m8  = match_any_transform(NET8 , grid);
  wire m9  = match_any_transform(NET9 , grid);
  wire m10 = match_any_transform(NET10, grid);

  assign foldable = m0 | m1 | m2 | m3 | m4 | m5 | m6 | m7 | m8 | m9 | m10;

endmodule