module find_first_occurrence (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] target,
    input wire [7:0] arr [0:7],
    output reg [7:0] result,
    output reg done
);

    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] SEARCH   = 3'd1;
    localparam [2:0] CHECK    = 3'd2;
    localparam [2:0] UPDATE   = 3'd3;
    localparam [2:0] COMPLETE = 3'd4;

    localparam [7:0] NOT_FOUND = 8'hFF;
    localparam [3:0] MAX_ITER  = 4'd10;

    reg [2:0] state;
    reg [3:0] iteration_count;
    reg [3:0] left;
    reg [3:0] right;
    reg [3:0] mid;
    reg [7:0] result_index;
    reg found;
    reg [7:0] mid_val;
    reg [7:0] left_val;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            iteration_count <= 4'd0;
            left <= 4'd0;
            right <= 4'd7;
            mid <= 4'd0;
            result_index <= 8'hFF;
            found <= 1'b0;
            mid_val <= 8'd0;
            left_val <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    iteration_count <= 4'd0;
                    left <= 4'd0;
                    right <= 4'd7;
                    result_index <= 8'hFF;
                    found <= 1'b0;
                    if (start) begin
                        state <= SEARCH;
                    end
                end

                SEARCH: begin
                    iteration_count <= iteration_count + 4'd1;
                    if (left <= right && iteration_count < MAX_ITER) begin
                        mid <= (left + right) >> 1;
                        mid_val <= arr[(left + right) >> 1];
                        left_val <= arr[left];
                        state <= CHECK;
                    end else begin
                        state <= COMPLETE;
                    end
                end

                CHECK: begin
                    if (mid_val == target) begin
                        if (!found) begin
                            result_index <= {4'd0, mid};
                            found <= 1'b1;
                        end
                        if (mid > 4'd0) begin
                            right <= mid - 4'd1;
                            state <= SEARCH;
                        end else begin
                            state <= COMPLETE;
                        end
                    end else if (mid_val < target) begin
                        left <= mid + 4'd1;
                        state <= SEARCH;
                    end else begin
                        if (mid > 4'd0) begin
                            right <= mid - 4'd1;
                            state <= SEARCH;
                        end else begin
                            state <= COMPLETE;
                        end
                    end
                end

                COMPLETE: begin
                    done <= 1'b1;
                    if (found) begin
                        result <= result_index;
                    end else begin
                        result <= NOT_FOUND;
                    end
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule