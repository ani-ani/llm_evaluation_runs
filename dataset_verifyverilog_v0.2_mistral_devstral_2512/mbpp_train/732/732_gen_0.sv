module replace_specialchar (
  input [127:0] text_in,
  input [7:0] valid_len,
  output [127:0] text_out,
  output [7:0] out_len
);

  // Process each byte in parallel
  genvar i;
  generate
    for (i = 0; i < 16; i = i + 1) begin : byte_processor
      always_comb begin
        case (text_in[(i*8)+7 : i*8])
          8'h20: text_out[(i*8)+7 : i*8] = 8'h3A; // space to colon
          8'h2C: text_out[(i*8)+7 : i*8] = 8'h3A; // comma to colon
          8'h2E: text_out[(i*8)+7 : i*8] = 8'h3A; // dot to colon
          default: text_out[(i*8)+7 : i*8] = text_in[(i*8)+7 : i*8]; // pass through
        endcase
      end
    end
  endgenerate

  // Output length is same as input length
  assign out_len = valid_len;

endmodule