module max_list_finder (input logic [3:0][3:0][4:0] lists,
input logic [3:0][4:0] valid_lengths,
output logic [1:0] max_length,
output logic [3:0][4:0] max_list);
  logic [1:0] selected_index;
  logic [4:0] max_val;
  always_comb begin
    max_val = '0;
    selected_index = '0;
    for (int i = 0; i < 4; i++) begin
      if (valid_lengths[i] > max_val) begin
        max_val = valid_lengths[i];
        selected_index = i[1:0];
      end
    end
  end
  assign max_length = max_val[1:0];
  assign max_list = lists[selected_index];
endmodule