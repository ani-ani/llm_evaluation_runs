module elementwise_subtractor
  (input  logic signed [6:0] tuple1 [3:0],
   input  logic signed [6:0] tuple2 [3:0],
   output logic signed [6:0] result [3:0]
  );

  for (genvar i = 0; i < 4; i++) begin : gen
    assign result[i] = tuple1[i] - tuple2[i];
  end

endmodule