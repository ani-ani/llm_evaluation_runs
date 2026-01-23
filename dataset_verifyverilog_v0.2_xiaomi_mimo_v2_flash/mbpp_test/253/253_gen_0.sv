module count_integers (
    input [7:0] data [0:7],
    output logic [3:0] count
);

    always_comb begin
        count = 4'd0;
        if (data[0][7:4] == 4'b0001) count = count + 1;
        if (data[1][7:4] == 4'b0001) count = count + 1;
        if (data[2][7:4] == 4'b0001) count = count + 1;
        if (data[3][7:4] == 4'b0001) count = count + 1;
        if (data[4][7:4] == 4'b0001) count = count + 1;
        if (data[5][7:4] == 4'b0001) count = count + 1;
        if (data[6][7:4] == 4'b0001) count = count + 1;
        if (data[7][7:4] == 4'b0001) count = count + 1;
    end

endmodule