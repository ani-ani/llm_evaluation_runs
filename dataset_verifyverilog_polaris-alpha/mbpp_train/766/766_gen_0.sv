module pair_wise(
  input  [2:0]  size,
  input  [31:0] data,
  output [55:0] pairs,
  output [2:0]  valid_count
);

  // valid_count = size - 1 (for size >= 1 as per spec)
  assign valid_count = (size > 0) ? (size - 3'd1) : 3'd0;

  // Helper function to extract element i (0..7) from data
  // elem0 = data[31:28], elem1 = data[27:24], ..., elem7 = data[3:0]
  function automatic [3:0] get_elem;
    input [2:0] idx;
    begin
      get_elem = data[31 - (idx*4) -: 4];
    end
  endfunction

  // Generate the 7 possible consecutive pairs (combinational)
  // pair[i] = {elem_i, elem_{i+1}} for i = 0..6
  wire [7:0] pair0 = {get_elem(3'd0), get_elem(3'd1)};
  wire [7:0] pair1 = {get_elem(3'd1), get_elem(3'd2)};
  wire [7:0] pair2 = {get_elem(3'd2), get_elem(3'd3)};
  wire [7:0] pair3 = {get_elem(3'd3), get_elem(3'd4)};
  wire [7:0] pair4 = {get_elem(3'd4), get_elem(3'd5)};
  wire [7:0] pair5 = {get_elem(3'd5), get_elem(3'd6)};
  wire [7:0] pair6 = {get_elem(3'd6), get_elem(3'd7)};

  // Pack pairs: pairs[55:48]=pair0, ..., pairs[7:0]=pair6
  assign pairs = {pair0, pair1, pair2, pair3, pair4, pair5, pair6};

endmodule