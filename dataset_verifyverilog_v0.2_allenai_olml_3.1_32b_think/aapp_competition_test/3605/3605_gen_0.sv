module tree_shopping (
    input clk,
    input rst_n,
    input start,
    input [7:0] tree_heights [0:7],
    output reg [7:0] min_diff,
    output reg done
);
    localparam IDLE = 2'b00;
    localparam FETCH = 2'b01;
    localparam UPDATE = 2'b10;
    localparam NEXT = 2'b11;
    reg [1:0] state;
    reg [2:0] window_idx;
    reg [2:0] i;
    reg [7:0] curr_min;
    reg [7:0] curr_max;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            min_diff <= 8'hFF;
            window_idx <= 0;
            i <= 0;
            curr_min <= 0;
            curr_max <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= FETCH;
                        window_idx <= 0;
                        min_diff <= 8'hFF;
                        i <= 0;
                        curr_min <= tree_heights[0];
                        curr_max <= tree_heights[0];
                    end
                end
                FETCH: begin
                    if (i < 2) begin
                        if (window_idx + i + 1 < 8) begin
                            if (tree_heights[window_idx + i + 1] < curr_min)
                                curr_min <= tree_heights[window_idx + i + 1];
                            if (tree_heights[window_idx + i + 1] > curr_max)
                                curr_max <= tree_heights[window_idx + i + 1];
                        end
                        i <= i + 1;
                    end else begin
                        state <= UPDATE;
                        i <= 0;
                    end
                end
                UPDATE: begin
                    if (curr_max - curr_min < min_diff)
                        min_diff <= curr_max - curr_min;
                    state <= NEXT;
                end
                NEXT: begin
                    if (window_idx < 5) begin
                        window_idx <= window_idx + 1;
                        curr_min <= tree_heights[window_idx];
                        curr_max <= tree_heights[window_idx];
                        state <= FETCH;
                        i <= 0;
                    end else begin
                        state <= DONE;
                    end
                end
                DONE: begin
                    done <= 1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end
endmodule