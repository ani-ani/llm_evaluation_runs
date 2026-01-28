module majority_element (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    input wire [3:0] n,
    input wire [7:0] x,
    output reg result,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] SEARCH  = 2'd1;
    localparam [1:0] CHECK   = 2'd2;
    localparam [1:0] FINISH  = 2'd3;
    
    reg [1:0] state;
    reg [3:0] low, high, mid;
    reg [7:0] target;
    reg [3:0] arr_len;
    reg found_flag;
    reg [3:0] found_idx;
    reg [7:0] max_cycles;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            result    <= 1'b0;
            done      <= 1'b0;
            found_flag <= 1'b0;
            low       <= 4'd0;
            high      <= 4'd0;
            mid       <= 4'd0;
            target    <= 8'd0;
            arr_len   <= 4'd0;
            found_idx <= 4'd0;
            max_cycles<= 8'd100;
        end
        else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    if (start) begin
                        target <= x;
                        arr_len <= n;
                        low <= 4'd0;
                        high <= (n > 4'd0) ? n - 4'd1 : 4'd0;
                        found_flag <= 1'b0;
                        state <= SEARCH;
                    end
                end
                
                SEARCH: begin
                    if (low <= high) begin
                        mid <= (low + high) >> 1;
                        if (get_arr_val(mid) == target && (mid == 4'd0 || get_arr_val(mid-4'd1) < target)) begin
                            found_flag <= 1'b1;
                            found_idx <= mid;
                            state <= CHECK;
                        end
                        else if (get_arr_val(mid) < target) begin
                            low <= mid + 4'd1;
                        end
                        else begin
                            high <= mid - 4'd1;
                        end
                    end
                    else begin
                        state <= FINISH;
                    end
                end
                
                CHECK: begin
                    if (found_idx + (arr_len >> 1) < arr_len) begin
                        result <= (get_arr_val(found_idx + (arr_len >> 1)) == target);
                    end
                    else begin
                        result <= 1'b0;
                    end
                    state <= FINISH;
                end
                
                FINISH: begin
                    if (!found_flag && state == SEARCH) begin
                        result <= 1'b0;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    function [7:0] get_arr_val;
        input [3:0] idx;
        case (idx)
            4'd0: get_arr_val = arr_0;
            4'd1: get_arr_val = arr_1;
            4'd2: get_arr_val = arr_2;
            4'd3: get_arr_val = arr_3;
            4'd4: get_arr_val = arr_4;
            4'd5: get_arr_val = arr_5;
            4'd6: get_arr_val = arr_6;
            4'd7: get_arr_val = arr_7;
            default: get_arr_val = 8'd0;
        endcase
    endfunction
    
endmodule