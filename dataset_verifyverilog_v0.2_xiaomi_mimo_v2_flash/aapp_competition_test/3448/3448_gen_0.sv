module cable_car_planner (
    input [3:0] n,
    input [2:0] k,
    output valid,
    output reg [3:0] ms_0, me_0,
    output reg [3:0] ms_1, me_1,
    output reg [3:0] ms_2, me_2,
    output reg [3:0] ms_3, me_3,
    output reg [3:0] vs_0, ve_0,
    output reg [3:0] vs_1, ve_1,
    output reg [3:0] vs_2, ve_2,
    output reg [3:0] vs_3, ve_3
);

    // Feasibility check: 2*k <= n - 1
    // Using comparison logic: 2*k + 1 <= n
    wire [3:0] two_k_plus_one;
    assign two_k_plus_one = {k, 1'b1}; // Multiply k by 2 and add 1
    assign valid = (two_k_plus_one <= n);

    always @(*) begin
        // Default assignments to avoid latches
        ms_0 = 4'b0; me_0 = 4'b0;
        ms_1 = 4'b0; me_1 = 4'b0;
        ms_2 = 4'b0; me_2 = 4'b0;
        ms_3 = 4'b0; me_3 = 4'b0;
        vs_0 = 4'b0; ve_0 = 4'b0;
        vs_1 = 4'b0; ve_1 = 4'b0;
        vs_2 = 4'b0; ve_2 = 4'b0;
        vs_3 = 4'b0; ve_3 = 4'b0;

        if (valid) begin
            // Mobi cars: (1,2), (3,4), (5,6), (7,8)
            // ms[i] = 2*i + 1, me[i] = 2*i + 2
            ms_0 = 4'd1; me_0 = 4'd2;
            if (k > 1) begin ms_1 = 4'd3; me_1 = 4'd4; end
            if (k > 2) begin ms_2 = 4'd5; me_2 = 4'd6; end
            if (k > 3) begin ms_3 = 4'd7; me_3 = 4'd8; end

            // Vina cars: (1,n), (2,n-1), (3,n-2), (4,n-3)
            // vs[i] = 2*i + 1, ve[i] = n - i
            vs_0 = 4'd1; ve_0 = n;
            if (k > 1) begin vs_1 = 4'd2; ve_1 = n - 1; end
            if (k > 2) begin vs_2 = 4'd3; ve_2 = n - 2; end
            if (k > 3) begin vs_3 = 4'd4; ve_3 = n - 3; end
        end
    end

endmodule
