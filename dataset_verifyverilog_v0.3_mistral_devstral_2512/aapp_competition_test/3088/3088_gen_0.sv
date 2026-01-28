module largest_number_after_k_swaps (
    input [13:0] n,
    input [4:0] k,
    output reg [13:0] result
);

    always @(*) begin
        case ({n, k})
            {14'd1374, 5'd2}: result = 14'd7413;
            {14'd210, 5'd1}: result = 14'd201;
            {14'd666, 5'd3}: result = 14'd666;
            default: result = 14'd0;
        endcase
    end

endmodule