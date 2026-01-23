module symmetry_adder (
    input reg clk,
    input reg rst_n,
    input reg start,
    input reg [5:0] num_points,
    input reg [7:0][15:0] x_coords,
    input reg [7:0][15:0] y_coords,
    output reg [5:0] min_additions,
    output reg done
);

reg [2:0] state;
reg [5:0] min_point, min_line;

localparam IDLE = 3'd0, RESET = 3'd1, CALCULATE_POINT_SYM = 3'd2, 
            CALCULATE_LINE_SYM = 3'd3, FIND_MIN = 3'd4, DONE = 3'd5;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        min_point <= 8'd8;
        min_line <= 8'd8;
        done <= 1'b0;
    end else begin
        done <= 1'b0;
        case (state)
            IDLE: if (start) state <= RESET; else state <= IDLE;
            RESET: state <= CALCULATE_POINT_SYM;
            CALCULATE_POINT_SYM: state <= CALCULATE_LINE_SYM;
            CALCULATE_LINE_SYM: state <= FIND_MIN;
            FIND_MIN: begin
                min_additions <= min_point < min_line ? min_point : min_line;
                done <= 1'b1;
                state <= DONE;
            end
            DONE: begin
                min_additions <= min_additions;
                done <= 1'b1;
            end
        endcase
    end
end

endmodule