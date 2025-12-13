module string_concat(
  input  [3:0]        valid_mask,
  input  [3:0][31:0]  strings,
  output logic [127:0] concatenated
);

  logic [3:0] wr_ptr; // write pointer in bytes (0-15)
  integer i;

  always_comb begin
    concatenated = 128'b0;
    wr_ptr = 4'd0;

    // Process strings in order from LSB to MSB of valid_mask
    for (i = 0; i < 4; i = i + 1) begin
      if (valid_mask[i]) begin
        if (wr_ptr < 16) begin
          concatenated[8*wr_ptr +: 8] = strings[i][7:0];
          wr_ptr = wr_ptr + 1;
        end
        if (wr_ptr < 16) begin
          concatenated[8*wr_ptr +: 8] = strings[i][15:8];
          wr_ptr = wr_ptr + 1;
        end
        if (wr_ptr < 16) begin
          concatenated[8*wr_ptr +: 8] = strings[i][23:16];
          wr_ptr = wr_ptr + 1;
        end
        if (wr_ptr < 16) begin
          concatenated[8*wr_ptr +: 8] = strings[i][31:24];
          wr_ptr = wr_ptr + 1;
        end
      end
    end
  end

endmodule