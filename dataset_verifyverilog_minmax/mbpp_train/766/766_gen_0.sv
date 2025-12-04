module pair_wise (
  input [2:0] size,
  input [31:0] data,
  output [55:0] pairs,
  output [2:0] valid_count
);

  function [3:0] get_slice (input [2:0] index);
    case (index)
      3'd0: get_slice = data[31:28];
      3'd1: get_slice = data[27:24];
      3'd2: get_slice = data[23:20];
      3'd3: get_slice = data[19:16];
      3'd4: get_slice = data[15:12];
      3'd5: get_slice = data[11:8];
      3'd6: get_slice = data[7:4];
      3'd7: get_slice = data[3:0];
      default: get_slice = 4'b0;
    endcase
  endfunction

  wire [3:0] e0 = get_slice(0);
  wire [3:0] e1 = get_slice(1);
  wire [3:0] e2 = get_slice(2);
  wire [3:0] e3 = get_slice(3);
  wire [3:0] e4 = get_slice(4);
  wire [3:0] e5 = get_slice(5);
  wire [3:0] e6 = get_slice(6);
  wire [3:0] e7 = get_slice(7);

  assign pairs[55:48] = (size > 1) ? {e0, e1} : 8'b0;
  assign pairs[47:40] = (size > 2) ? {e1, e2} : 8'b0;
  assign pairs[39:32] = (size > 3) ? {e2, e3} : 8'b0;
  assign pairs[31:24] = (size > 4) ? {e3, e4} : 8'b0;
  assign pairs[23:16] = (size > 5) ? {e4, e5} : 8'b0;
  assign pairs[15:8]  = (size > 6) ? {e5, e6} : 8'b0;
  assign pairs[7:0]   = (size > 7) ? {e6, e7} : 8'b0;

  assign valid_count = (size > 0) ? (size - 3'b1) : 3'b0;

endmodule
