module add_string (
  input [63:0] prefix_bytes,
  input [7:0] list [0:3],
  output logic [287:0] formatted_strings
);
  // Segment 0: {prefix_bytes, list[0]}
  assign formatted_strings[72*0 +: 72] = {
    prefix_bytes[63:56], prefix_bytes[55:48], prefix_bytes[47:40], prefix_bytes[39:32],
    prefix_bytes[31:24], prefix_bytes[23:16], prefix_bytes[15:8],  prefix_bytes[7:0],
    list[0]
  };

  // Segment 1: {prefix_bytes, list[1]}
  assign formatted_strings[72*1 +: 72] = {
    prefix_bytes[63:56], prefix_bytes[55:48], prefix_bytes[47:40], prefix_bytes[39:32],
    prefix_bytes[31:24], prefix_bytes[23:16], prefix_bytes[15:8],  prefix_bytes[7:0],
    list[1]
  };

  // Segment 2: {prefix_bytes, list[2]}
  assign formatted_strings[72*2 +: 72] = {
    prefix_bytes[63:56], prefix_bytes[55:48], prefix_bytes[47:40], prefix_bytes[39:32],
    prefix_bytes[31:24], prefix_bytes[23:16], prefix_bytes[15:8],  prefix_bytes[7:0],
    list[2]
  };

  // Segment 3: {prefix_bytes, list[3]}
  assign formatted_strings[72*3 +: 72] = {
    prefix_bytes[63:56], prefix_bytes[55:48], prefix_bytes[47:40], prefix_bytes[39:32],
    prefix_bytes[31:24], prefix_bytes[23:16], prefix_bytes[15:8],  prefix_bytes[7:0],
    list[3]
  };
endmodule