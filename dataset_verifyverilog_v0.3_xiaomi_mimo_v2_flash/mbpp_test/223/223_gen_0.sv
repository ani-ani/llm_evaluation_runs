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

    // State machine states
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] SEARCH   = 3'd1;
    localparam [2:0] CHECK    = 3'd2;
    localparam [2:0] FINISH   = 3'd3;
    localparam [2:0] ERROR    = 3'd4;

    reg [2:0] state;
    reg [3:0] low, high, mid;
    reg [7:0] target;
    reg [3:0] arr_len;
    reg found_flag;
    reg [3:0] found_idx;
    reg [3:0] check_cnt;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd12;
    
    // Combinational array read for current mid index
    reg [7:0] mid_val;
    reg [7:0] mid_minus_one_val;
    reg [7:0] check_val;
    
    always @(*) begin
        case (mid)
            4'd0: mid_val = arr_0;
            4'd1: mid_val = arr_1;
            4'd2: mid_val = arr_2;
            4'd3: mid_val = arr_3;
            4'd4: mid_val = arr_4;
            4'd5: mid_val = arr_5;
            4'd6: mid_val = arr_6;
            4'd7: mid_val = arr_7;
            default: mid_val = 8'd0;
        endcase
        
        case (mid - 4'd1)
            4'd0: mid_minus_one_val = arr_0;
            4'd1: mid_minus_one_val = arr_1;
            4'd2: mid_minus_one_val = arr_2;
            4'd3: mid_minus_one_val = arr_3;
            4'd4: mid_minus_one_val = arr_4;
            4'd5: mid_minus_one_val = arr_5;
            4'd6: mid_minus_one_val = arr_6;
            4'd7: mid_minus_one_val = arr_7;
            default: mid_minus_one_val = 8'd0;
        endcase
        
        case (found_idx + (arr_len >> 1))
            4'd0: check_val = arr_0;
            4'd1: check_val = arr_1;
            4'd2: check_val = arr_2;
            4'd3: check_val = arr_3;
            4'd4: check_val = arr_4;
            4'd5: check_val = arr_5;
            4'd6: check_val = arr_6;
            4'd7: check_val = arr_7;
            default: check_val = 8'd0;
        endcase
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            found_flag <= 1'b0;
            cycle_count <= 4'd0;
            low <= 4'd0;
            high <= 4'd0;
            mid <= 4'd0;
            found_idx <= 4'd0;
            check_cnt <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    found_flag <= 1'b0;
                    if (start) begin
                        target <= x;
                        arr_len <= n;
                        low <= 4'd0;
                        high <= n - 4'd1;
                        if (n > 4'd8 || n == 4'd0) begin
                            state <= ERROR;
                        end else begin
                            state <= SEARCH;
                        end
                    end
                end
                
                SEARCH: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (low <= high && cycle_count < MAX_CYCLES) begin
                        mid <= (low + high) >> 1;
                        if (mid == 4'd0) begin
                            if (mid_val == target) begin
                                found_flag <= 1'b1;
                                found_idx <= mid;
                                state <= CHECK;
                            end else if (target > mid_val) begin
                                low <= mid + 4'd1;
                            end else begin
                                state <= FINISH;
                            end
                        end else begin
                            if (mid_minus_one_val < target && mid_val == target) begin
                                found_flag <= 1'b1;
                                found_idx <= mid;
                                state <= CHECK;
                            end else if (mid_minus_one_val < target && target > mid_val) begin
                                low <= mid + 4'd1;
                            end else begin
                                high <= mid - 4'd1;
                            end
                        end
                    end else begin
                        state <= FINISH;
                    end
                end
                
                CHECK: begin
                    if (found_flag && (found_idx + (arr_len >> 1)) < arr_len) begin
                        if (check_val == target) begin
                            result <= 1'b1;
                        end else begin
                            result <= 1'b0;
                        end
                    end else begin
                        result <= 1'b0;
                    end
                    state <= FINISH;
                end
                
                FINISH: begin
                    if (!found_flag) begin
                        result <= 1'b0;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                ERROR: begin
                    result <= 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule