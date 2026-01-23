module check_all_empty(
    input [7:0] dicts [0:7],
    output all_empty
);

    // Combinational logic using reduction NOR
    // all_empty is 1 if all elements are zero, otherwise 0
    assign all_empty = ~(|{dicts[0], dicts[1], dicts[2], dicts[3], dicts[4], dicts[5], dicts[6], dicts[7]});

endmodule