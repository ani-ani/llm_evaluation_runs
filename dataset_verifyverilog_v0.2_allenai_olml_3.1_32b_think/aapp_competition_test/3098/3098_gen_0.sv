module expected_area (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] k,
    input [15:0] x0, y0, x1, y1, x2, y2, x3, y3, x4, y4,
    output reg [31:0] result,
    output reg done
);

reg [3:0] n_reg;
reg [15:0] x0_reg, y0_reg, x1_reg, y1_reg, x2_reg, y2_reg, x3_reg, y3_reg, x4_reg, y4_reg;
reg input_sampled;
reg [6:0] counter;
reg [31:0] result_reg;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        n_reg <= 4'd0;
x0_reg <= 16'd0; y0_reg <=16'd0; x1_reg <=16'd0; y1_reg <=16'd0;
x2_reg <=16'd0; y2_reg <=16'd0; x3_reg <=16'd0; y3_reg <=16'd0;
x4_reg <=16'd0; y4_reg <=16'd0;
        input_sampled <= 0;
        counter <= 8'd0;
        result_reg <= 32'd0;
        done <=0;
    end else if (start) begin
        if (!input_sampled) begin
            n_reg <= n;
x0_reg <= x0; y0_reg <= y0;
x1_reg <= x1; y1_reg <= y1;
x2_reg <= x2; y2_reg <= y2;
x3_reg <= x3; y3_reg <= y3;
x4_reg <= x4; y4_reg <= y4;
            input_sampled <= 1;
            counter <= 8'd79;
        end
    end
end

always @(posedge clk) begin
    if (input_sampled) begin
        if (counter > 0) counter <= counter -1;
        else begin
            done <=1;
        end
    end
end

function automatic [31:0] calculate_expected_area;
    input [3:0] n,
    input [15:0] x0, y0, x1, y1, x2, y2, x3, y3, x4, y4);
begin
    integer total_sum;
    integer sum_terms;
    integer area_triangle;
    total_sum =0;
    if (n ==3) begin
        integer signed xi = (integer signed)x0;
        integer signed yi = (integer signed)y0;
        integer signed xj = (integer signed)x1;
        integer signed yj = (integer signed)y1;
        integer signed xk = (integer signed)x2;
        integer signed yk = (integer signed)y2;
        sum_terms = xi*yj + xj*yk + xk*yi - xj*yi - xk*yj - xi*yk;
        area_triangle = (sum_terms >=0 ? sum_terms : -sum_terms) /2;
        total_sum = area_triangle;
    end
    integer expected_value = total_sum /1;
    return expected_value >>15;
endfunction

assign result = calculate_expected_area(n_reg, x0_reg, y0_reg, x1_reg, y1_reg, x2_reg, y2_reg, x3_reg, y3_reg, x4_reg, y4_reg);

endmodule