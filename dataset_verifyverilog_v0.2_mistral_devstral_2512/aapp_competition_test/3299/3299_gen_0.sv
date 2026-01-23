module magic_checkerboard_2x2 (
    input clk,
    input rst_n,
    input start,
    input [3:0] grid_00, grid_01, grid_10, grid_11,
    output reg [7:0] result,
    output reg done
);
    
    reg [3:0] v10, v01, v11; // Values for positions (1,0), (0,1), (1,1)
    reg [11:0] iteration_count; // 15*15*15 = 3375 < 2^12
    reg searching;
    
    wire [3:0] c00 = grid_00;
    wire [3:0] c01 = (grid_01 == 4'd0) ? v01 : grid_01;
    wire [3:0] c10 = (grid_10 == 4'd0) ? v10 : grid_10;
    wire [3:0] c11 = (grid_11 == 4'd0) ? v11 : grid_11;
    
    wire valid;
    wire [7:0] current_sum;
    
    assign current_sum = c00 + c01 + c10 + c11;
    
    assign valid = (c00 > 0) && (c01 > 0) && (c10 > 0) && (c11 > 0) &&
                   (c00 < c01) && (c10 < c11) &&
                   (c00 < c10) && (c01 < c11) &&
                   (c00[0] ^ c11[0]);
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 8'hFF; // -1
            done <= 0;
            searching <= 0;
            iteration_count <= 0;
            v10 <= 1; v01 <= 1; v11 <= 1;
        end else begin
            if (start && !searching) begin
                searching <= 1;
                done <= 0;
                result <= 8'hFF;
                v10 <= 1; v01 <= 1; v11 <= 1;
                iteration_count <= 0;
            end else if (searching) begin
                if (iteration_count < 12'd3375) begin
                    if (valid) begin
                        if (result == 8'hFF || current_sum < result) begin
                            result <= current_sum;
                        end
                    end
                    
                    if (v10 < 15) begin
                        v10 <= v10 + 1;
                    end else begin
                        v10 <= 1;
                        if (v01 < 15) begin
                            v01 <= v01 + 1;
                        end else begin
                            v01 <= 1;
                            if (v11 < 15) begin
                                v11 <= v11 + 1;
                            end
                        end
                    end
                    iteration_count <= iteration_count + 1;
                end else begin
                    searching <= 0;
                    done <= 1;
                end
            end else begin
                done <= 0;
            end
        end
    end
endmodule