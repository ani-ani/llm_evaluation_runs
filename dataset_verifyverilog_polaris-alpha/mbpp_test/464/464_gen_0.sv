module dict_value_check (
    input [31:0] entries,  // 4x8-bit dictionary values {entry3, entry2, entry1, entry0}
    input [7:0]  n,        // Value to compare against
    output       result    // 1 if all entries == n, else 0
);

    wire cmp0 = (entries[7:0]   == n);
    wire cmp1 = (entries[15:8]  == n);
    wire cmp2 = (entries[23:16] == n);
    wire cmp3 = (entries[31:24] == n);

    assign result = cmp0 & cmp1 & cmp2 & cmp3;

endmodule