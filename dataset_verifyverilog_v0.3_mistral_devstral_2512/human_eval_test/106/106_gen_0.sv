module sequence_generator(
    input [3:0] n,
    output [15:0] result [0:7]
);

    reg [15:0] i;
    reg [15:0] factorial;
    reg [15:0] sum;
    reg [15:0] temp_result;

    always @(*) begin
        // Initialize all outputs to 0
        result[0] = 16'd0;
        result[1] = 16'd0;
        result[2] = 16'd0;
        result[3] = 16'd0;
        result[4] = 16'd0;
        result[5] = 16'd0;
        result[6] = 16'd0;
        result[7] = 16'd0;

        case (n)
            4'd1: begin
                // i=1 (odd): sum = 1
                result[0] = 16'd1;
            end
            4'd2: begin
                // i=1 (odd): sum = 1
                result[0] = 16'd1;
                // i=2 (even): factorial = 2
                result[1] = 16'd2;
            end
            4'd3: begin
                // i=1 (odd): sum = 1
                result[0] = 16'd1;
                // i=2 (even): factorial = 2
                result[1] = 16'd2;
                // i=3 (odd): sum = 6
                result[2] = 16'd6;
            end
            4'd4: begin
                // i=1 (odd): sum = 1
                result[0] = 16'd1;
                // i=2 (even): factorial = 2
                result[1] = 16'd2;
                // i=3 (odd): sum = 6
                result[2] = 16'd6;
                // i=4 (even): factorial = 24
                result[3] = 16'd24;
            end
            4'd5: begin
                // i=1 (odd): sum = 1
                result[0] = 16'd1;
                // i=2 (even): factorial = 2
                result[1] = 16'd2;
                // i=3 (odd): sum = 6
                result[2] = 16'd6;
                // i=4 (even): factorial = 24
                result[3] = 16'd24;
                // i=5 (odd): sum = 15
                result[4] = 16'd15;
            end
            4'd6: begin
                // i=1 (odd): sum = 1
                result[0] = 16'd1;
                // i=2 (even): factorial = 2
                result[1] = 16'd2;
                // i=3 (odd): sum = 6
                result[2] = 16'd6;
                // i=4 (even): factorial = 24
                result[3] = 16'd24;
                // i=5 (odd): sum = 15
                result[4] = 16'd15;
                // i=6 (even): factorial = 720
                result[5] = 16'd720;
            end
            4'd7: begin
                // i=1 (odd): sum = 1
                result[0] = 16'd1;
                // i=2 (even): factorial = 2
                result[1] = 16'd2;
                // i=3 (odd): sum = 6
                result[2] = 16'd6;
                // i=4 (even): factorial = 24
                result[3] = 16'd24;
                // i=5 (odd): sum = 15
                result[4] = 16'd15;
                // i=6 (even): factorial = 720
                result[5] = 16'd720;
                // i=7 (odd): sum = 28
                result[6] = 16'd28;
            end
            4'd8: begin
                // i=1 (odd): sum = 1
                result[0] = 16'd1;
                // i=2 (even): factorial = 2
                result[1] = 16'd2;
                // i=3 (odd): sum = 6
                result[2] = 16'd6;
                // i=4 (even): factorial = 24
                result[3] = 16'd24;
                // i=5 (odd): sum = 15
                result[4] = 16'd15;
                // i=6 (even): factorial = 720
                result[5] = 16'd720;
                // i=7 (odd): sum = 28
                result[6] = 16'd28;
                // i=8 (even): factorial = 40320
                result[7] = 16'd40320;
            end
            default: begin
                // For n=0 or n>8, all outputs remain 0
            end
        endcase
    end

endmodule