module compare_arrays(
    input [7:0] score [0:7],
    input [7:0] guess [0:7],
    output [7:0] result [0:7]
);

    integer i;
    always @(*) begin
        for (i = 0; i < 8; i = i + 1) begin
            if (score[i] == guess[i]) begin
                result[i] = 8'd0;
            end else begin
                if (score[i] > guess[i]) begin
                    result[i] = score[i] - guess[i];
                end else begin
                    result[i] = guess[i] - score[i];
                end
            end
        end
    end

endmodule