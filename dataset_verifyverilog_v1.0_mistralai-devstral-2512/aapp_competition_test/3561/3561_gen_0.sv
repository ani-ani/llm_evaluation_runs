module wolf_sheep_cabbage(
    input [7:0] W,
    input [7:0] S,
    input [7:0] C,
    input [7:0] K,
    output reg result,
    output reg done
);

    always @(*) begin
        // Default values
        result = 1'b0;
        done = 1'b1;

        // Case 1: K=0 is impossible
        if (K == 8'd0) begin
            result = 1'b0;
        end
        // Case 2: K >= total items
        else if (K >= (W + S + C)) begin
            result = 1'b1;
        end
        // Case 3: K=1
        else if (K == 8'd1) begin
            // Only possible if no sheep, or no wolves and no cabbages
            if (S == 8'd0 || (W == 8'd0 && C == 8'd0)) begin
                result = 1'b1;
            end
        end
        // Case 4: K=2
        else if (K == 8'd2) begin
            // If all three items present, check if counts are manageable
            if (W > 8'd0 && S > 8'd0 && C > 8'd0) begin
                // With K=2, we can handle if no single item exceeds capacity
                // and we can separate items appropriately
                if (W <= 8'd2 && S <= 8'd2 && C <= 8'd2) begin
                    result = 1'b1;
                end
            end else begin
                // If not all three items present, it's generally solvable
                result = 1'b1;
            end
        end
        // Case 5: K>=3
        else begin
            // With K>=3, standard solution exists
            result = 1'b1;
        end
    end

endmodule