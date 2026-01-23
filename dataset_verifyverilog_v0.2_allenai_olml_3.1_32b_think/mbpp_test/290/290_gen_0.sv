module max_length_finder(
    input [3:0][2:0] lengths,
    input [3:0][7:0][7:0] lists,
    output [2:0] max_length,
    output [7:0][7:0] max_list,
    output valid
);

  reg [2:0] max_len;
  reg [2:0] max_index;
  reg [7:0][7:0] max_list_reg;
  reg valid_out;

  always @(*) begin
    max_len = 0;
    max_index = 3;

    if (lengths[0] > max_len || (lengths[0] == max_len && 0 < max_index)) begin
      max_len = lengths[0];
      max_index = 0;
    end
    if (lengths[1] > max_len || (lengths[1] == max_len && 1 < max_index)) begin
      max_len = lengths[1];
      max_index = 1;
    end
    if (lengths[2] > max_len || (lengths[2] == max_len && 2 < max_index)) begin
      max_len = lengths[2];
      max_index = 2;
    end
    if (lengths[3] > max_len || (lengths[3] == max_len && 3 < max_index)) begin
      max_len = lengths[3];
      max_index = 3;
    end

    valid_out = lengths[0] | lengths[1] | lengths[2] | lengths[3];

    max_length = max_len;
    if (valid_out)
      max_list_reg = lists[max_index];
    else
      max_list_reg = 0;
    max_list = max_list_reg;
    valid = valid_out;
  end
endmodule