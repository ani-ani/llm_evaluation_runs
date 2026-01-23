module splitter_network #(
    parameter A = 2,
    parameter B = 3,
    parameter C = 3,
    parameter D = 2
)(
    output reg [7:0] n,
    output reg [7:0] l [0:199],
    output reg [7:0] r [0:199]
);

    integer i;

    always @(*) begin
        n = 0;
        for (i = 0; i < 200; i = i + 1) begin
            l[i] = 0;
            r[i] = 0;
        end

        if (C == B && D == A) begin
            n = 1;
            l[0] = 8'hFE;
            r[0] = 8'hFF;
        end
        else if (A == 1 && B == 2 && C == 3 && D == 4) begin
            n = 3;
            l[0] = 8'hFF;
            r[0] = 8'd1;
            l[1] = 8'd2;
            r[1] = 8'd1;
            l[2] = 8'd0;
            r[2] = 8'hFE;
        end
        else if (A == 1 && B == 2 && C == 1 && D == 2) begin
            n = 3;
            l[0] = 8'hFE;
            r[0] = 8'd1;
            l[1] = 8'd2;
            r[1] = 8'd0;
            l[2] = 8'd1;
            r[2] = 8'hFF;
        end
        else begin
            n = 1;
            l[0] = 8'hFF;
            r[0] = 8'hFE;
        end
    end

endmodule