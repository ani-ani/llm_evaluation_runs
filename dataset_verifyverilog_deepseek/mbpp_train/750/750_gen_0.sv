module list_tuple_append (
  input [2:0] input_size,
  input [7:0] input_list [5:0],
  input [7:0] tuple_element1,
  input [7:0] tuple_element2,
  output reg [7:0] output_list [7:0],
  output reg [3:0] output_size
);

  always_comb begin
    foreach (output_list[i]) output_list[i] = 8'b0;
    for (int i=0; i < input_size; i++) begin
      output_list[i] = input_list[i];
    end
    output_list[input_size] = tuple_element1;
    output_list[input_size + 1] = tuple_element2;
    output_size = input_size + 3'd2;
  end
endmodule