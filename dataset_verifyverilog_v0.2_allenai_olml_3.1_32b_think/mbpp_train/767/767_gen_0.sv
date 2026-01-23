module pair_sum_counter (
    input [7:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
    input [8:0] target_sum,
    input valid,
    output reg [3:0] pair_count,
    output reg result_valid
);

localparam NUM_ELEMENTS = 8;

// Create array of the 8 elements
wire [7:0] arr [NUM_ELEMENTS];
assign arr[0] = arr_0;
assign arr[1] = arr_1;
assign arr[2] = arr_2;
assign arr[3] = arr_3;
assign arr[4] = arr_4;
assign arr[5] = arr_5;
assign arr[6] = arr_6;
assign arr[7] = arr_7;

// Output assignments
assign result_valid = valid;

always @(*) begin
    integer i, j;
    pair_count = 0;
    for (i=0; i < NUM_ELEMENTS; i++) begin
        for (j = i+1; j < NUM_ELEMENTS; j++) begin
            if ( ( (arr[i] << 1) >> 1 ) + ( (arr[j] << 1) >> 1 ) == target_sum ) begin
                pair_count += 1;
            end
        end
    end
end

endmodule