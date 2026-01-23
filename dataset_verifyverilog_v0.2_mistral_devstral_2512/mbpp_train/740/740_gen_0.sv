module tuple_to_dict (
  input [7:0] tuple_data [0:7],
  input [2:0] valid_count,
  output reg [7:0] key_0,
  output reg [7:0] key_1,
  output reg [7:0] key_2,
  output reg [7:0] key_3,
  output reg [7:0] val_0,
  output reg [7:0] val_1,
  output reg [7:0] val_2,
  output reg [7:0] val_3,
  output reg [2:0] pair_count
);

  always @* begin
    pair_count = valid_count >> 1;

    // Initialize all outputs to 0
    key_0 = 8'b0; key_1 = 8'b0; key_2 = 8'b0; key_3 = 8'b0;
    val_0 = 8'b0; val_1 = 8'b0; val_2 = 8'b0; val_3 = 8'b0;

    // Process valid pairs
    if (valid_count >= 2) begin
      key_0 = tuple_data[0];
      val_0 = tuple_data[1];
    end
    if (valid_count >= 4) begin
      key_1 = tuple_data[2];
      val_1 = tuple_data[3];
    end
    if (valid_count >= 6) begin
      key_2 = tuple_data[4];
      val_2 = tuple_data[5];
    end
    if (valid_count >= 8) begin
      key_3 = tuple_data[6];
      val_3 = tuple_data[7];
    end
  end
endmodule