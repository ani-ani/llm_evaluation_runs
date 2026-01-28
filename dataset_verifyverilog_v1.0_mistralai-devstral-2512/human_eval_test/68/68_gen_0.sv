module even_min_finder(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:15],
    input [3:0] len,
    output reg [7:0] result_val,
    output reg [3:0] result_idx,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [1:0] IDLE   = 2'd0;
    localparam [1:0] SCAN   = 2'd1;
    localparam [1:0] UPDATE = 2'd2;
    localparam [1:0] DONE   = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] i;
    reg [7:0] best_val;
    reg [3:0] best_idx;
    reg found;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            i <= 4'd0;
            best_val <= 8'd0;
            best_idx <= 4'd0;
            found <= 1'b0;
            result_val <= 8'hFF;
            result_idx <= 4'hF;
            done <= 1'b0;
            valid <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        next_state <= SCAN;
                        i <= 4'd0;
                        best_val <= 8'd0;
                        best_idx <= 4'd0;
                        found <= 1'b0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                SCAN: begin
                    if (i < len) begin
                        if (arr[i][0] == 1'b0) begin  // Even check
                            if (!found || arr[i] < best_val) begin
                                next_state <= UPDATE;
                            end else begin
                                next_state <= SCAN;
                                i <= i + 4'd1;
                            end
                        end else begin
                            next_state <= SCAN;
                            i <= i + 4'd1;
                        end
                    end else begin
                        next_state <= DONE;
                    end
                end

                UPDATE: begin
                    best_val <= arr[i];
                    best_idx <= i;
                    found <= 1'b1;
                    next_state <= SCAN;
                    i <= i + 4'd1;
                end

                DONE: begin
                    if (found) begin
                        result_val <= best_val;
                        result_idx <= best_idx;
                        valid <= 1'b1;
                    end else begin
                        result_val <= 8'hFF;
                        result_idx <= 4'hF;
                        valid <= 1'b0;
                    end
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule