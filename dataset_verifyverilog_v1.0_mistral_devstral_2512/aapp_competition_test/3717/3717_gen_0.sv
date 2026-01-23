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
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK_ALL = 2'd1;
    localparam [1:0] CHECK_EXCEPT = 2'd2;
    
    // Constants
    localparam signed [31:0] NEG_INF = 32'h80000000;
    localparam signed [31:0] POS_INF = 32'h7FFFFFFF;
    
    // Registers
    reg [1:0] state;
    reg [7:0] i, j;
    reg signed [31:0] all_max_x1, all_min_x2, all_max_y1, all_min_y2;
    reg signed [31:0] except_max_x1, except_min_x2, except_max_y1, except_min_y2;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_x <= 32'd0;
            result_y <= 32'd0;
            i <= 8'd0;
            j <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        if (n > 1) begin
                            // Initialize for checking all rectangles
                            all_max_x1 <= x1[0];
                            all_min_x2 <= x2[0];
                            all_max_y1 <= y1[0];
                            all_min_y2 <= y2[0];
                            i <= 1;
                            state <= CHECK_ALL;
                        end else begin
                            // For n=1, just output first rectangle's corner
                            result_x <= x1[0];
                            result_y <= y1[0];
                            done <= 1'b1;
                        end
                    end
                end
                
                CHECK_ALL: begin
                    if (i < n) begin
                        // Update intersection of all rectangles
                        if (x1[i] > all_max_x1) all_max_x1 <= x1[i];
                        if (x2[i] < all_min_x2) all_min_x2 <= x2[i];
                        if (y1[i] > all_max_y1) all_max_y1 <= y1[i];
                        if (y2[i] < all_min_y2) all_min_y2 <= y2[i];
                        i <= i + 8'd1;
                    end else begin
                        // Check if all rectangles intersect
                        if (all_max_x1 <= all_min_x2 && all_max_y1 <= all_min_y2) begin
                            result_x <= all_max_x1;
                            result_y <= all_max_y1;
                            done <= 1'b1;
                            state <= IDLE;
                        end else begin
                            // Start checking by removing each rectangle
                            j <= 8'd0;
                            state <= CHECK_EXCEPT;
                        end
                    end
                end
                
                CHECK_EXCEPT: begin
                    if (j < n) begin
                        // Initialize intersection except rectangle j
                        except_max_x1 <= NEG_INF;
                        except_min_x2 <= POS_INF;
                        except_max_y1 <= NEG_INF;
                        except_min_y2 <= POS_INF;
                        
                        // Compute intersection of all except j
                        integer k;
                        for (k = 0; k < 16; k = k + 1) begin
                            if (k != j && k < n) begin
                                if (x1[k] > except_max_x1) except_max_x1 <= x1[k];
                                if (x2[k] < except_min_x2) except_min_x2 <= x2[k];
                                if (y1[k] > except_max_y1) except_max_y1 <= y1[k];
                                if (y2[k] < except_min_y2) except_min_y2 <= y2[k];
                            end
                        end
                        
                        // Check intersection after this cycle
                        if (except_max_x1 <= except_min_x2 && except_max_y1 <= except_min_y2) begin
                            result_x <= except_max_x1;
                            result_y <= except_max_y1;
                            done <= 1'b1;
                            state <= IDLE;
                        end else begin
                            j <= j + 8'd1;
                        end
                    end else begin
                        // Should not happen per problem statement
                        result_x <= 32'd0;
                        result_y <= 32'd0;
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule