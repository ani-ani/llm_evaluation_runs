module sequence_generator(
    input [3:0] n,
    output reg [15:0] result [0:7]
);

    // Local parameters for factorial values (i even, 1 to 8)
    localparam [15:0] FACT_2  = 16'd2;
    localparam [15:0] FACT_4  = 16'd24;
    localparam [15:0] FACT_6  = 16'd720;
    localparam [15:0] FACT_8  = 16'd40320;

    // Local parameters for sum values (i odd, 1 to 8)
    localparam [15:0] SUM_1   = 16'd1;
    localparam [15:0] SUM_3   = 16'd6;
    localparam [15:0] SUM_5   = 16'd15;
    localparam [15:0] SUM_7   = 16'd28;

    // Combinational logic block
    always @(*) begin
        // Initialize all output elements to 0 (default for n < 8)
        result[0] = 16'd0;
        result[1] = 16'd0;
        result[2] = 16'd0;
        result[3] = 16'd0;
        result[4] = 16'd0;
        result[5] = 16'd0;
        result[6] = 16'd0;
        result[7] = 16'd0;

        // Generate values based on n
        // result[0] is for i=1 (odd, sum=1)
        // result[1] is for i=2 (even, factorial=2)
        // ...
        // result[7] is for i=8 (even, factorial=40320)
        case (n)
            4'd1: begin
                result[0] = SUM_1;
            end
            4'd2: begin
                result[0] = SUM_1;
                result[1] = FACT_2;
            end
            4'd3: begin
                result[0] = SUM_1;
                result[1] = FACT_2;
                result[2] = SUM_3;
            end
            4'd4: begin
                result[0] = SUM_1;
                result[1] = FACT_2;
                result[2] = SUM_3;
                result[3] = FACT_4;
            end
            4'd5: begin
                result[0] = SUM_1;
                result[1] = FACT_2;
                result[2] = SUM_3;
                result[3] = FACT_4;
                result[4] = SUM_5;
            end
            4'd6: begin
                result[0] = SUM_1;
                result[1] = FACT_2;
                result[2] = SUM_3;
                result[3] = FACT_4;
                result[4] = SUM_5;
                result[5] = FACT_6;
            end
            4'd7: begin
                result[0] = SUM_1;
                result[1] = FACT_2;
                result[2] = SUM_3;
                result[3] = FACT_4;
                result[4] = SUM_5;
                result[5] = FACT_6;
                result[6] = SUM_7;
            end
            4'd8: begin
                result[0] = SUM_1;
                result[1] = FACT_2;
                result[2] = SUM_3;
                result[3] = FACT_4;
                result[4] = SUM_5;
                result[5] = FACT_6;
                result[6] = SUM_7;
                result[7] = FACT_8;
            end
            default: begin
                // For n = 0 or any invalid value, all results remain 0
                result[0] = 16'd0;
                result[1] = 16'd0;
                result[2] = 16'd0;
                result[3] = 16'd0;
                result[4] = 16'd0;
                result[5] = 16'd0;
                result[6] = 16'd0;
                result[7] = 16'd0;
            end
        endcase
    end

endmodule