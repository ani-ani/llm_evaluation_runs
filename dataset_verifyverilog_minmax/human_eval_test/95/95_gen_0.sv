module dict_case_checker #(
    parameter integer MAX_KEYS = 4,
    parameter integer KEY_WIDTH = 8
)(
    input reg [3:0] key_count,
    input reg [MAX_KEYS-1:0][KEY_WIDTH-1:0] keys,
    output logic is_case_consistent
);

logic [MAX_KEYS-1:0] is_letter;
logic [MAX_KEYS-1:0] is_upper;
logic [MAX_KEYS-1:0] is_lower;
logic [MAX_KEYS-1:0] key_valid;

genvar i;
generate
    for (i = 0; i < MAX_KEYS; i++) begin : per_key
        assign key_valid[i] = (i < key_count);
        assign is_letter[i] = key_valid[i] && (
            (keys[i] >= 8'h41 && keys[i] <= 8'h5A) ||
            (keys[i] >= 8'h61 && keys[i] <= 8'h7A)
        );
        assign is_upper[i] = key_valid[i] && (
            (keys[i] >= 8'h41 && keys[i] <= 8'h5A)
        );
        assign is_lower[i] = key_valid[i] && (
            (keys[i] >= 8'h61 && keys[i] <= 8'h7A)
        );
    end
endgenerate

logic any_non_letter;
logic any_upper;
logic any_lower;
logic any_valid;

assign any_non_letter = |(~is_letter & key_valid);
assign any_upper = |is_upper;
assign any_lower = |is_lower;
assign any_valid = (key_count != 0);

assign is_case_consistent = any_valid && ~any_non_letter && (any_upper != any_lower);

endmodule
