module bus_excursion ( input clk, input rst_n, input start, input [31:0] l, input [31:0] v1, input [31:0] v2, input [3:0] n, output reg [31:0] result, output reg done );
    reg [31:0] low, high, mid, temp_T, temp_S, product1, product2;
    reg [3:0] count;
    reg [3:0] K;
    reg [31:0] result_reg;
    reg done_reg;
    reg [2:0] state;

    always @(posedge clk) begin
        if (!rst_n) begin
            low <= 32'd0;
            high <= l;
            mid <= 32'd0;
            temp_T <= 32'd0;
            temp_S <= 32'd0;
            product1 <= 32'd0;
            product2 <= 32'd0;
            count <= 32'd0;
            K <= 32'd0;
            result_reg <= 32'd0;
            done_reg <= 1'b0;
            state <= 3'b0;
        end else begin
            if (start) begin
                if (state == 3'b0) begin
                    state <= 3'b1;
                    low <= 32'd0;
                    high <= l;
                    count <= 32'd0;
                end
            end
            if (state == 3'b1) begin
                if (count < 32) begin
                    mid <= (low + high) >> 1;
                    K <= 2*n - 1;
                    temp_T <= mid * K - l;
                    temp_S <= l - mid;
                    product1 <= temp_T * v1;
                    product2 <= temp_S * v2;
                    if (product1 > product2) begin
                        high <= mid;
                    end else begin
                        low <= mid;
                    end
                    count <= count + 1;
                end else begin
                    result_reg <= (mid / v2) + ((l - mid) / v1);
                    state <= 3'b2;
                    done_reg <= 1'b1;
                end
            end
            if (state == 3'b2) begin
                // retain values
            end
        end
    end

    assign result = result_reg;
    assign done = done_reg;
endmodule