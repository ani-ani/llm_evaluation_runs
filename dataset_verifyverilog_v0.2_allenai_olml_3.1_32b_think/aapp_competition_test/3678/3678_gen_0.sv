module loop_validator (
    input clk,
    input rst_n,
    input start,
    input [2:0] n_in,
    input [7:0] point_x [0:7],
    input [7:0] point_y [0:7],
    output reg valid,
    output reg done
);

always @(negedge rst_n) begin
    valid <= 0;
    done <= 0;
end

always @(posedge clk) begin
    valid <= valid;
    done <= done;
end

endmodule