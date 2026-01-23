module josip_painter(
    input clk,
    input rst_n,
    input start,
    input [2:0] target_addr,
    input [7:0] target_row,
    input target_write_en,
    output reg [6:0] min_diff,
    output reg done
);

reg [7:0] target_grid [7:0];

localparam IDLE = 2'd0,
        COMPUTE = 2'd1,
        DONE = 2'd2;

reg [1:0] state;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= 2'b00;
        min_diff <= 8'b0;
        done <= 0;
    end else begin
        if (state == 2'b00) begin
            if (start) begin
                state <= 2'b01;
            end
        end else if (state == 2'b01) begin
            min_diff <= 8'b0;
            done <= 1;
            state <= 2'b10;
        end else if (state == 2'b10) begin
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (target_write_en) begin
        target_grid[target_addr][7:0] <= target_row;
    end
end

endmodule