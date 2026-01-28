module find_min_piles(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [7:0] strengths [0:7],
    output reg [3:0] result,
    output reg done
);

    localparam [3:0] S_IDLE = 4'd0;
    localparam [3:0] S_SORT = 4'd1;
    localparam [3:0] S_PROCESS = 4'd2;
    localparam [3:0] S_DONE = 4'd3;

    reg [3:0] state;
    reg [7:0] sorted [0:7];
    reg [3:0] pile_heights [0:7];
    reg [2:0] pass;
    reg [2:0] i;
    reg [2:0] current_box;
    reg [2:0] current_pile;
    reg [3:0] num_piles;
    reg found;

    integer j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            result <= 4'd0;
            done <= 1'b0;
            pass <= 3'd0;
            i <= 3'd0;
            current_box <= 3'd0;
            current_pile <= 3'd0;
            num_piles <= 4'd0;
            found <= 1'b0;
            for (j = 0; j < 8; j = j + 1) begin
                sorted[j] <= 8'd0;
                pile_heights[j] <= 4'd0;
            end
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        if (n == 4'd0) begin
                            result <= 4'd0;
                            done <= 1'b1;
                            state <= S_DONE;
                        end else begin
                            for (j = 0; j < 8; j = j + 1) begin
                                if (j < n)
                                    sorted[j] <= strengths[j];
                                else
                                    sorted[j] <= 8'd0;
                                pile_heights[j] <= 4'd0;
                            end
                            pass <= 3'd0;
                            i <= 3'd0;
                            num_piles <= 4'd0;
                            state <= S_SORT;
                        end
                    end
                end

                S_SORT: begin
                    if (pass < n - 1) begin
                        if (i < n - pass - 1) begin
                            if (sorted[i] > sorted[i + 1]) begin
                                sorted[i] <= sorted[i + 1];
                                sorted[i + 1] <= sorted[i];
                            end
                            i <= i + 1;
                        end else begin
                            i <= 3'd0;
                            pass <= pass + 1;
                        end
                    end else begin
                        current_box <= 3'd0;
                        state <= S_PROCESS;
                    end
                end

                S_PROCESS: begin
                    if (current_box < n) begin
                        current_pile <= 3'd0;
                        found <= 1'b0;
                        state <= S_PROCESS;
                        for (j = 0; j < num_piles; j = j + 1) begin
                            if (pile_heights[j] <= sorted[current_box]) begin
                                pile_heights[j] <= pile_heights[j] + 1;
                                found <= 1'b1;
                                current_box <= current_box + 1;
                            end
                        end
                        if (!found) begin
                            pile_heights[num_piles] <= 4'd1;
                            num_piles <= num_piles + 1;
                            current_box <= current_box + 1;
                        end
                    end else begin
                        result <= num_piles;
                        done <= 1'b1;
                        state <= S_DONE;
                    end
                end

                S_DONE: begin
                    if (!start)
                        state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule