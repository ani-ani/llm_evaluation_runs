module array_intersection (
    input [2:0] len1,
    input [2:0] len2,
    input [5:0] array1 [0:7],
    input [5:0] array2 [0:7],
    output reg [5:0] result [0:7],
    output reg [2:0] result_len
);

    // Wires for conditions for each element in array2
    wire cond0, cond1, cond2, cond3, cond4, cond5, cond6, cond7;

    // Compute condition for each element in array2
    assign cond0 = (len2 > 0) && (
        (len1 > 0 && array2[0] == array1[0]) ||
        (len1 > 1 && array2[0] == array1[1]) ||
        (len1 > 2 && array2[0] == array1[2]) ||
        (len1 > 3 && array2[0] == array1[3]) ||
        (len1 > 4 && array2[0] == array1[4]) ||
        (len1 > 5 && array2[0] == array1[5]) ||
        (len1 > 6 && array2[0] == array1[6]) ||
        (len1 > 7 && array2[0] == array1[7])
    );

    assign cond1 = (len2 > 1) && (
        (len1 > 0 && array2[1] == array1[0]) ||
        (len1 > 1 && array2[1] == array1[1]) ||
        (len1 > 2 && array2[1] == array1[2]) ||
        (len1 > 3 && array2[1] == array1[3]) ||
        (len1 > 4 && array2[1] == array1[4]) ||
        (len1 > 5 && array2[1] == array1[5]) ||
        (len1 > 6 && array2[1] == array1[6]) ||
        (len1 > 7 && array2[1] == array1[7])
    );

    assign cond2 = (len2 > 2) && (
        (len1 > 0 && array2[2] == array1[0]) ||
        (len1 > 1 && array2[2] == array1[1]) ||
        (len1 > 2 && array2[2] == array1[2]) ||
        (len1 > 3 && array2[2] == array1[3]) ||
        (len1 > 4 && array2[2] == array1[4]) ||
        (len1 > 5 && array2[2] == array1[5]) ||
        (len1 > 6 && array2[2] == array1[6]) ||
        (len1 > 7 && array2[2] == array1[7])
    );

    assign cond3 = (len2 > 3) && (
        (len1 > 0 && array2[3] == array1[0]) ||
        (len1 > 1 && array2[3] == array1[1]) ||
        (len1 > 2 && array2[3] == array1[2]) ||
        (len1 > 3 && array2[3] == array1[3]) ||
        (len1 > 4 && array2[3] == array1[4]) ||
        (len1 > 5 && array2[3] == array1[5]) ||
        (len1 > 6 && array2[3] == array1[6]) ||
        (len1 > 7 && array2[3] == array1[7])
    );

    assign cond4 = (len2 > 4) && (
        (len1 > 0 && array2[4] == array1[0]) ||
        (len1 > 1 && array2[4] == array1[1]) ||
        (len1 > 2 && array2[4] == array1[2]) ||
        (len1 > 3 && array2[4] == array1[3]) ||
        (len1 > 4 && array2[4] == array1[4]) ||
        (len1 > 5 && array2[4] == array1[5]) ||
        (len1 > 6 && array2[4] == array1[6]) ||
        (len1 > 7 && array2[4] == array1[7])
    );

    assign cond5 = (len2 > 5) && (
        (len1 > 0 && array2[5] == array1[0]) ||
        (len1 > 1 && array2[5] == array1[1]) ||
        (len1 > 2 && array2[5] == array1[2]) ||
        (len1 > 3 && array2[5] == array1[3]) ||
        (len1 > 4 && array2[5] == array1[4]) ||
        (len1 > 5 && array2[5] == array1[5]) ||
        (len1 > 6 && array2[5] == array1[6]) ||
        (len1 > 7 && array2[5] == array1[7])
    );

    assign cond6 = (len2 > 6) && (
        (len1 > 0 && array2[6] == array1[0]) ||
        (len1 > 1 && array2[6] == array1[1]) ||
        (len1 > 2 && array2[6] == array1[2]) ||
        (len1 > 3 && array2[6] == array1[3]) ||
        (len1 > 4 && array2[6] == array1[4]) ||
        (len1 > 5 && array2[6] == array1[5]) ||
        (len1 > 6 && array2[6] == array1[6]) ||
        (len1 > 7 && array2[6] == array1[7])
    );

    assign cond7 = (len2 > 7) && (
        (len1 > 0 && array2[7] == array1[0]) ||
        (len1 > 1 && array2[7] == array1[1]) ||
        (len1 > 2 && array2[7] == array1[2]) ||
        (len1 > 3 && array2[7] == array1[3]) ||
        (len1 > 4 && array2[7] == array1[4]) ||
        (len1 > 5 && array2[7] == array1[5]) ||
        (len1 > 6 && array2[7] == array1[6]) ||
        (len1 > 7 && array2[7] == array1[7])
    );

    // Combinational always block to assemble result
    always @(*) begin
        // Initialize result and result_len
        result[0] = 6'b0;
        result[1] = 6'b0;
        result[2] = 6'b0;
        result[3] = 6'b0;
        result[4] = 6'b0;
        result[5] = 6'b0;
        result[6] = 6'b0;
        result[7] = 6'b0;
        result_len = 3'b0;

        if (cond0) begin
            result[0] = array2[0];
            result_len = 1;
        end

        if (cond1) begin
            if (result_len == 0) begin
                result[0] = array2[1];
                result_len = 1;
            end else begin
                result[result_len] = array2[1];
                result_len = result_len + 1;
            end
        end

        if (cond2) begin
            if (result_len == 0) begin
                result[0] = array2[2];
                result_len = 1;
            end else if (result_len == 1) begin
                result[1] = array2[2];
                result_len = 2;
            end else begin
                result[2] = array2[2];
                result_len = 3;
            end
        end

        if (cond3) begin
            if (result_len == 0) begin
                result[0] = array2[3];
                result_len = 1;
            end else if (result_len == 1) begin
                result[1] = array2[3];
                result_len = 2;
            end else if (result_len == 2) begin
                result[2] = array2[3];
                result_len = 3;
            end else begin
                result[3] = array2[3];
                result_len = 4;
            end
        end

        if (cond4) begin
            case (result_len)
                0: begin
                    result[0] = array2[4];
                    result_len = 1;
                end
                1: begin
                    result[1] = array2[4];
                    result_len = 2;
                end
                2: begin
                    result[2] = array2[4];
                    result_len = 3;
                end
                3: begin
                    result[3] = array2[4];
                    result_len = 4;
                end
                4: begin
                    result[4] = array2[4];
                    result_len = 5;
                end
            endcase
        end

        if (cond5) begin
            case (result_len)
                0: begin
                    result[0] = array2[5];
                    result_len = 1;
                end
                1: begin
                    result[1] = array2[5];
                    result_len = 2;
                end
                2: begin
                    result[2] = array2[5];
                    result_len = 3;
                end
                3: begin
                    result[3] = array2[5];
                    result_len = 4;
                end
                4: begin
                    result[4] = array2[5];
                    result_len = 5;
                end
                5: begin
                    result[5] = array2[5];
                    result_len = 6;
                end
            endcase
        end

        if (cond6) begin
            case (result_len)
                0: begin
                    result[0] = array2[6];
                    result_len = 1;
                end
                1: begin
                    result[1] = array2[6];
                    result_len = 2;
                end
                2: begin
                    result[2] = array2[6];
                    result_len = 3;
                end
                3: begin
                    result[3] = array2[6];
                    result_len = 4;
                end
                4: begin
                    result[4] = array2[6];
                    result_len = 5;
                end
                5: begin
                    result[5] = array2[6];
                    result_len = 6;
                end
                6: begin
                    result[6] = array2[6];
                    result_len = 7;
                end
            endcase
        end

        if (cond7) begin
            case (result_len)
                0: begin
                    result[0] = array2[7];
                    result_len = 1;
                end
                1: begin
                    result[1] = array2[7];
                    result_len = 2;
                end
                2: begin
                    result[2] = array2[7];
                    result_len = 3;
                end
                3: begin
                    result[3] = array2[7];
                    result_len = 4;
                end
                4: begin
                    result[4] = array2[7];
                    result_len = 5;
                end
                5: begin
                    result[5] = array2[7];
                    result_len = 6;
                end
                6: begin
                    result[6] = array2[7];
                    result_len = 7;
                end
                7: begin
                    result[7] = array2[7];
                    result_len = 7; // cap at 7
                end
            endcase
        end
    end

endmodule