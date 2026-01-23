module minimal_unique_substring_gen (
input clk,
input rst_n, // Active-low reset
input start,
input [15:0] n,
input [15:0] k,
output reg out_bit,
output reg done
);

reg [15:0] n_reg, k_reg;
reg [1:0] state;
reg [15:0] counter;
reg [15:0] spacing;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        n_reg <= 16'b0;
k_reg <= 16'b0;
spacing <= 16'b0;
counter <= 16'b0;
state <= 2'b00;
done <= 1'b0;
    end else begin
        case (state)
            2'b00: begin
                if (start) begin
                    n_reg <= n;
k_reg <= k;
spacing <= (n_reg - k_reg) >> 1;
counter <= 16'b0;
state <= 2'b01;
                end
            end
            2'b01: begin
                counter <= counter + 1;
                if (counter < n_reg) begin
                    state <= 2'b01;
                end else begin
                    done <= 1'b1;
                    state <= 2'b10;
                end
            end
            2'b10: begin
                done <= 1'b1;
            end
        endcase
    end
end

always_comb begin
    out_bit = 1'b0;
    if (state == 2'b01) begin
        if (n_reg == k_reg) begin
            out_bit = 1'b1;
        end else begin
            if (counter % spacing == spacing - 1) begin
                out_bit = 1'b1;
            end
        end
    end
end

endmodule