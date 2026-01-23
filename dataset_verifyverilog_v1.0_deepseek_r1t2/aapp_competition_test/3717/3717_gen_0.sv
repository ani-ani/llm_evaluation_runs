module find_common_point (
    input clk,
    input rst_n,
    input start,
    input [31:0] x1 [0:15],
    input [31:0] y1 [0:15],
    input [31:0] x2 [0:15],
    input [31:0] y2 [0:15],
    input [7:0] n,
    output reg [31:0] result_x,
    output reg [31:0] result_y,
    output reg done
);
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_ALL = 3'd1;
    localparam [2:0] CHECK_EXCEPT_INIT = 3'd2;
    localparam [2:0] CHECK_EXCEPT_LOOP = 3'd3;
    localparam [2:0] CHECK_EXCEPT_EVAL = 3'd4;
    
    reg [2:0] state;
    
    // Constants
    localparam signed [31:0] NEG_INF = 32'h80000000;
    localparam signed [31:0] POS_INF = 32'h7FFFFFFF;
    
    // Registers
    reg signed [31:0] all_max_x1, all_min_x2, all_max_y1, all_min_y2;
    reg signed [31:0] except_max_x1, except_min_x2, except_max_y1, except_min_y2;
    reg [7:0] i, j, k;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_x <= 32'd0;
            result_y <= 32'd0;
            i <= 8'd0;
            j <= 8'd0;
            k <= 8'd0;
            all_max_x1 <= NEG_INF;
            all_min_x2 <= POS_INF;
            all_max_y1 <= NEG_INF;
            all_min_y2 <= POS_INF;
            except_max_x1 <= NEG_INF;
            except_min_x2 <= POS_INF;
            except_max_y1 <= NEG_INF;
            except_min_y2 <= POS_INF;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        if (n == 8'd1) begin
                            result_x <= x1[0];
                            result_y <= y1[0];
                            done <= 1'b1;
                            state <= IDLE;
                        end else begin
                            all_max_x1 <= x1[0];
                            all_min_x2 <= x2[0];
                            all_max_y1 <= y1[0];
                            all_min_y2 <= y2[0];
                            i <= 8'd1;
                            state <= CHECK_ALL;
                        end
                    end
                end
                
                CHECK_ALL: begin
                    if (i < n) begin
                        if (x1[i] > all_max_x1) all_max_x1 <= x1[i];
                        if (x2[i] < all_min_x2) all_min_x2 <= x2[i];
                        if (y1[i] > all_max_y1) all_max_y1 <= y1[i];
                        if (y2[i] < all_min_y2) all_min_y2 <= y2[i];
                        i <= i + 8'd1;
                    end else begin
                        if (all_max_x1 <= all_min_x2 && all_max_y1 <= all_min_y2) begin
                            result_x <= all_max_x1;
                            result_y <= all_max_y1;
                            done <= 1'b1;
                            state <= IDLE;
                        end else begin
                            j <= 8'd0;
                            state <= CHECK_EXCEPT_INIT;
                        end
                    end
                end
                
                CHECK_EXCEPT_INIT: begin
                    except_max_x1 <= NEG_INF;
                    except_min_x2 <= POS_INF;
                    except_max_y1 <= NEG_INF;
                    except_min_y2 <= POS_INF;
                    k <= 8'd0;
                    done <= 1'b0;
                    state <= CHECK_EXCEPT_LOOP;
                end
                
                CHECK_EXCEPT_LOOP: begin
                    if (k < n) begin
                        if (k != j) begin
                            if (x1[k] > except_max_x1) except_max_x1 <= x1[k];
                            if (x2[k] < except_min_x2) except_min_x2 <= x2[k];
                            if (y1[k] > except_max_y1) except_max_y1 <= y1[k];
                            if (y2[k] < except_min_y2) except_min_y2 <= y2[k];
                        end
                        k <= k + 8'd1;
                    end else begin
                        state <= CHECK_EXCEPT_EVAL;
                    end
                end
                
                CHECK_EXCEPT_EVAL: begin
                    if (except_max_x1 <= except_min_x2 && except_max_y1 <= except_min_y2) begin
                        result_x <= except_max_x1;
                        result_y <= except_max_y1;
                        done <= 1'b1;
                        state <= IDLE;
                    end else begin
                        j <= j + 8'd1;
                        if (j < n) begin
                            state <= CHECK_EXCEPT_INIT;
                        end else begin
                            result_x <= 32'd0;
                            result_y <= 32'd0;
                            done <= 1'b1;
                            state <= IDLE;
                        end
                    end
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
endmodule