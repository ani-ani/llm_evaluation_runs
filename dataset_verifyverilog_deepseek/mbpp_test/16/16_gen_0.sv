module text_lowercase_underscore(input [127:0] text, output reg valid);
  wire [7:0] chars [0:15];
  genvar i;
  generate
    for (i=0; i<16; i=i+1) begin : char_gen
      assign chars[i] = text[127 - i*8 -: 8];
    end
  endgenerate

  reg [15:0] is_underscore;
  reg [15:0] is_letter;
  reg all_chars_valid;
  reg [4:0] underscore_count;
  reg [3:0] underscore_pos;
  reg found_underscore;
  reg pos_valid;
  reg pre_valid;
  reg post_valid;

  integer j,k;

  always_comb begin
    for (j=0; j<16; j=j+1) begin
      is_underscore[j] = (chars[j] == 8'h5F);
      is_letter[j] = (chars[j] >= 8'h61) && (chars[j] <= 8'h7A);
    end

    all_chars_valid = 1'b1;
    for (j=0; j<16; j=j+1) begin
      if (!(is_underscore[j] || is_letter[j])) all_chars_valid = 1'b0;
    end

    underscore_count = 0;
    for (j=0; j<16; j=j+1) begin
      underscore_count += is_underscore[j];
    end

    found_underscore = 1'b0;
    underscore_pos = 0;
    for (j=0; j<16; j=j+1) begin
      if (is_underscore[j] && !found_underscore) begin
        underscore_pos = j;
        found_underscore = 1'b1;
      end
    end

    pos_valid = (underscore_pos != 0) && (underscore_pos != 15);

    pre_valid = 1'b1;
    for (k=0; k < underscore_pos; k=k+1) begin
      if (!is_letter[k]) pre_valid = 1'b0;
    end

    post_valid = 1'b1;
    for (k=underscore_pos+1; k < 16; k=k+1) begin
      if (!is_letter[k]) post_valid = 1'b0;
    end

    valid = all_chars_valid && (underscore_count == 1) && pos_valid && pre_valid && post_valid;
  end
endmodule