module add_string(
  input [63:0] prefix_bytes,
  input [7:0] list [0:3],
  output logic [287:0] formatted_strings
);
  always_comb begin
    for (int i=0; i<4; i++) begin
      formatted_strings[72*i +: 72] = {prefix_bytes[63:56], prefix_bytes[55:48], prefix_bytes[47:40],
                                      prefix_bytes[39:32], prefix_bytes[31:24], prefix_bytes[23:16],
                                      prefix_bytes[15:8], prefix_bytes[7:0], list[i]};
    end
  end
endmodule