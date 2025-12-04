module trim_tuples (
  input clk,
  input rst_n,
  input start,
  input [1:0] K,
  input [19:0] tuple_in,
  output reg [11:0] tuple_out,
  output reg done
);

  logic [11:0] next_tuple_out;
  logic done_next;
  
  always_comb begin
    done_next = start;
    next_tuple_out = 12'h0;
    if (start) begin
      logic [3:0] elem0, elem1, elem2, elem3, elem4;
      {elem0, elem1, elem2, elem3, elem4} = tuple_in;
      case(K)
        2'h0: next_tuple_out = {elem0, elem1, elem2};
        2'h1: next_tuple_out = {elem1, elem2, elem3};
        2'h2: next_tuple_out = {8'h0, elem2};
        default: next_tuple_out = {elem0, elem1, elem2};
      endcase
    end
  end
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tuple_out <= 12'h0;
      done <= 1'b0;
    end else begin
      tuple_out <= next_tuple_out;
      done <= done_next;
    end
  end
endmodule