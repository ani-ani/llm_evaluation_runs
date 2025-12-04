module dict_value_check (
    input [31:0] entries,  // 4x8-bit dictionary values {entry3, entry2, entry1, entry0}
    input [7:0] n,         // Value to compare against
    output logic result    // 1 if all entries == n, else 0
);

  // Extract the 4 byte-wide entries from the packed array
  wire [7:0] entry0 = entries[7:0];
  wire [7:0] entry1 = entries[15:8];
  wire [7:0] entry2 = entries[23:16];
  wire [7:0] entry3 = entries[31:24];

  // Parallel comparisons
  wire eq0 = (entry0 == n);
  wire eq1 = (entry1 == n);
  wire eq2 = (entry2 == n);
  wire eq3 = (entry3 == n);

  // AND reduction of all equality results
  assign result = &{eq3, eq2, eq1, eq0};

endmodule