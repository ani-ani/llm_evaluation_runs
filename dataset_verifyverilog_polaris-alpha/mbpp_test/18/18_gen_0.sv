module string_filter(
  input  [127:0] str1,
  input  [127:0] str2,
  output reg [127:0] filtered_str
);

  // Presence bitmap for all 256 ASCII values
  reg [255:0] presence;

  // Extract characters from str1 and str2
  wire [7:0] s1 [0:15];
  wire [7:0] s2 [0:15];

  genvar gi;
  generate
    for (gi = 0; gi < 16; gi = gi + 1) begin : GEN_CHAR_EXTRACT
      assign s1[gi] = str1[8*gi +: 8];
      assign s2[gi] = str2[8*gi +: 8];
    end
  endgenerate

  // Keep flags for characters in str1 (1 = keep, 0 = remove)
  reg keep [0:15];

  integer i;
  integer j;
  integer k;

  always @* begin
    // Build presence bitmap from str2
    presence = 256'b0;
    for (i = 0; i < 16; i = i + 1) begin
      presence[s2[i]] = 1'b1;
    end

    // Determine which characters to keep from str1
    for (i = 0; i < 16; i = i + 1) begin
      // Keep if character not present in str2
      keep[i] = ~presence[s1[i]];
    end

    // Pack kept characters contiguously from LSB
    filtered_str = 128'b0;
    k = 0; // index of next output character position
    for (i = 0; i < 16; i = i + 1) begin
      if (keep[i]) begin
        if (k < 16) begin
          filtered_str[8*k +: 8] = s1[i];
          k = k + 1;
        end
      end
    end

    // Unused bytes already zeroed by initialization of filtered_str
  end

endmodule