module arrange_solver_4 (
    input clk,
    input rst_n,
    input start,
    input [3:0] perm_in [3:0],
    input [1:0] swap_1,
    input [1:0] swap_2
);
    reg [3:0] current_perm [3:0];
    reg [7:0] min_swaps;
    reg done;
    reg valid;
    reg [2:0] state;

    always @(posedge clk) begin
        if (!rst_n) begin
            current_perm <= perm_in;
            min_swaps <= 8'b0;
            done <= 1'b0;
            valid <= 1'b0;
            state <= 3'b000;
        end else begin
            case (state)
                3'b000: // idle
                    if (start) begin
                        if (current_perm[0] == 4'd1 && current_perm[1] == 4'd2 && current_perm[2] == 4'd3 && current_perm[3] == 4'd4) begin
                            min_swaps <= 8'b0;
                            done <= 1'b1;
                            valid <= 1'b1;
                        end else begin
                            min_swaps <= 8'b0;
                            done <= 1'b0;
                            valid <= 1'b0;
                        end
                        state <= 3'b100; // done
                    end
                endcase
        end
    end

    assign done = done;
    assign valid = valid;
    assign min_swaps = min_swaps;

endmodule