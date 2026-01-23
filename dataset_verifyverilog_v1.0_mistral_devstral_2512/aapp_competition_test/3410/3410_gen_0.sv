module score_calculator(
    input [3:0] N,
    input [63:0] x0,
    input [63:0] x1,
    input [63:0] x2,
    input [63:0] x3,
    input [63:0] x4,
    input [63:0] x5,
    input [63:0] x6,
    input [63:0] x7,
    input [63:0] y0,
    input [63:0] y1,
    input [63:0] y2,
    input [63:0] y3,
    input [63:0] y4,
    input [63:0] y5,
    input [63:0] y6,
    input [63:0] y7,
    output reg [63:0] result
);

    reg [63:0] x [0:7];
    reg [63:0] y [0:7];

    always @(*) begin
        x[0] = x0;
        x[1] = x1;
        x[2] = x2;
        x[3] = x3;
        x[4] = x4;
        x[5] = x5;
        x[6] = x6;
        x[7] = x7;
        y[0] = y0;
        y[1] = y1;
        y[2] = y2;
        y[3] = y3;
        y[4] = y4;
        y[5] = y5;
        y[6] = y6;
        y[7] = y7;
    end

    always @(*) begin
        result = 64'd0;
        if (N >= 3) begin
            integer i, j, k;
            for (i = 0; i < N; i = i + 1) begin
                for (j = i + 1; j < N; j = j + 1) begin
                    for (k = j + 1; k < N; k = k + 1) begin
                        result = (result + twice_area(i, j, k)) % 64'd1000003;
                    end
                end
            end
        end
    end

    function automatic [63:0] twice_area;
        input [2:0] i, j, k;
        reg signed [63:0] x1, y1, x2, y2, x3, y3;
        reg signed [63:0] area;
        reg [63:0] abs_area;
    begin
        x1 = x[i];
        y1 = y[i];
        x2 = x[j];
        y2 = y[j];
        x3 = x[k];
        y3 = y[k];
        area = (x2 - x1) * (y3 - y1) - (x3 - x1) * (y2 - y1);
        if (area < 0)
            abs_area = -area;
        else
            abs_area = area;
        twice_area = abs_area;
    end
    endfunction

endmodule