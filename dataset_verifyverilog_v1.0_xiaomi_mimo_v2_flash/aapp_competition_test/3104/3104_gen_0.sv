module equation_solver(
    input clk,
    input rst_n,
    input start,
    input [3:0] digits [0:7],
    input [3:0] length,
    input [7:0] target,
    output reg done,
    output reg [7:0] split,
    output reg valid
);
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK = 3'd1;
    localparam [2:0] OUTPUT = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state;
    reg [7:0] pattern;
    reg [7:0] pattern_count;
    localparam [7:0] MAX_PATTERNS = 8'd256;
    localparam [8:0] MAX_SUM = 9'd512;
    
    reg [8:0] current_sum;
    reg [3:0] digit_idx;
    reg [3:0] temp_num;
    reg [7:0] temp_pattern;
    reg [2:0] check_state;
    localparam [2:0] CHECK_INIT = 3'd0;
    localparam [2:0] CHECK_PROCESS = 3'd1;
    localparam [2:0] CHECK_ADD = 3'd2;
    localparam [2:0] CHECK_DONE = 3'd3;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            split <= 8'd0;
            valid <= 1'b0;
            pattern <= 8'd0;
            pattern_count <= 8'd0;
            current_sum <= 9'd0;
            digit_idx <= 4'd0;
            temp_num <= 4'd0;
            temp_pattern <= 8'd0;
            check_state <= CHECK_INIT;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    split <= 8'd0;
                    pattern_count <= 8'd0;
                    check_state <= CHECK_INIT;
                    if (start) begin
                        state <= CHECK;
                    end
                end
                
                CHECK: begin
                    case (check_state)
                        CHECK_INIT: begin
                            current_sum <= 9'd0;
                            digit_idx <= 4'd0;
                            temp_num <= 4'd0;
                            temp_pattern <= pattern;
                            check_state <= CHECK_PROCESS;
                        end
                        
                        CHECK_PROCESS: begin
                            if (digit_idx < length) begin
                                temp_num <= {digits[digit_idx]};
                                check_state <= CHECK_ADD;
                            end else begin
                                check_state <= CHECK_DONE;
                            end
                        end
                        
                        CHECK_ADD: begin
                            if (digit_idx < length) begin
                                if (digit_idx == 4'd0) begin
                                    current_sum <= current_sum + {1'd0, digits[digit_idx]};
                                end else begin
                                    if (temp_pattern[digit_idx - 1] == 1'b1) begin
                                        current_sum <= current_sum + {1'd0, digits[digit_idx]};
                                    end else begin
                                        if (current_sum > 9'd200) begin
                                            current_sum <= 9'd201;
                                        end else begin
                                            current_sum <= (current_sum * 9'd10) + {1'd0, digits[digit_idx]};
                                        end
                                    end
                                end
                                digit_idx <= digit_idx + 4'd1;
                                check_state <= CHECK_PROCESS;
                            end
                        end
                        
                        CHECK_DONE: begin
                            if (current_sum == target) begin
                                split <= temp_pattern;
                                valid <= 1'b1;
                                state <= OUTPUT;
                            end else begin
                                pattern_count <= pattern_count + 8'd1;
                                if (pattern_count >= MAX_PATTERNS) begin
                                    state <= FINISH;
                                end else begin
                                    state <= CHECK_INIT;
                                end
                            end
                        end
                        
                        default: check_state <= CHECK_INIT;
                    endcase
                end
                
                OUTPUT: begin
                    done <= 1'b1;
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    always @(*) begin
        if (state == CHECK && check_state == CHECK_INIT) begin
            pattern = pattern_count;
        end
    end
endmodule