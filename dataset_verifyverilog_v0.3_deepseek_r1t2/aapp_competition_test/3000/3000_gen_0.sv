module BracketEvaluator(
    input clk,
    input rst_n,
    input start,
    input [3:0] token_count,
    input [9:0] token_0,
    input [9:0] token_1,
    input [9:0] token_2,
    input [9:0] token_3,
    input [9:0] token_4,
    input [9:0] token_5,
    input [9:0] token_6,
    input [9:0] token_7,
    input [9:0] token_8,
    input [9:0] token_9,
    input [9:0] token_10,
    input [9:0] token_11,
    input [9:0] token_12,
    input [9:0] token_13,
    input [9:0] token_14,
    input [9:0] token_15,
    output reg [7:0] result,
    output reg done,
    output reg error
);
    
    // State definitions
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] PROCESS  = 2'd1;
    localparam [1:0] FINISH   = 2'd2;
    
    reg [1:0] state;
    reg [8:0] stack [0:3];  // {mode, value[7:0]} (4-deep stack)
    reg [2:0] stack_ptr;
    reg current_mode;       // 0: add, 1: multiply
    reg [7:0] current_value;
    reg [4:0] token_index;
    reg error_flag;
    
    // Combinational current token selection
    wire [9:0] current_token;
    always @(*) begin
        case (token_index[3:0])
            4'd0:  current_token = token_0;
            4'd1:  current_token = token_1;
            4'd2:  current_token = token_2;
            4'd3:  current_token = token_3;
            4'd4:  current_token = token_4;
            4'd5:  current_token = token_5;
            4'd6:  current_token = token_6;
            4'd7:  current_token = token_7;
            4'd8:  current_token = token_8;
            4'd9:  current_token = token_9;
            4'd10: current_token = token_10;
            4'd11: current_token = token_11;
            4'd12: current_token = token_12;
            4'd13: current_token = token_13;
            4'd14: current_token = token_14;
            4'd15: current_token = token_15;
            default: current_token = 10'd0;
        endcase
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            error <= 1'b0;
            stack_ptr <= 3'd0;
            current_mode <= 1'b0;
            current_value <= 8'd0;
            token_index <= 5'd0;
            error_flag <= 1'b0;
            for (integer i = 0; i < 4; i = i + 1) begin
                stack[i] <= 9'd0;
            end
        end else begin
            done <= 1'b0;
            error <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PROCESS;
                        stack_ptr <= 3'd0;
                        current_mode <= 1'b0;
                        current_value <= 8'd0;
                        token_index <= 5'd0;
                        error_flag <= 1'b0;
                    end
                end
                
                PROCESS: begin
                    case (current_token[9:8])
                        2'b00: begin  // Number
                            if (current_mode == 1'b0) begin
                                current_value <= (current_value + current_token[7:0]) % 8'd256;
                            end else begin
                                current_value <= (current_value * current_token[7:0]) % 8'd256;
                            end
                        end
                        
                        2'b01: begin  // '('
                            if (stack_ptr < 3'd4) begin
                                stack[stack_ptr] <= {current_mode, current_value};
                                stack_ptr <= stack_ptr + 3'd1;
                                current_mode <= ~current_mode;
                                current_value <= (current_mode ? 8'd1 : 8'd0);
                            end else begin
                                error_flag <= 1'b1;
                            end
                        end
                        
                        2'b10: begin  // ')'
                            if (stack_ptr > 3'd0) begin
                                stack_ptr <= stack_ptr - 3'd1;
                                if (stack[stack_ptr-3'd1][8]) begin  // multiply
                                    current_value <= (stack[stack_ptr-3'd1][7:0] * current_value) % 8'd256;
                                end else begin  // add
                                    current_value <= (stack[stack_ptr-3'd1][7:0] + current_value) % 8'd256;
                                end
                                current_mode <= stack[stack_ptr-3'd1][8];
                            end else begin
                                error_flag <= 1'b1;
                            end
                        end
                        
                        default: begin
                            error_flag <= 1'b1;
                        end
                    endcase
                    
                    token_index <= token_index + 5'd1;
                    
                    if (token_index + 5'd1 >= {1'b0, token_count}) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    if (stack_ptr != 3'd0) error_flag <= 1'b1;
                    done <= 1'b1;
                    error <= error_flag;
                    result <= current_value;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule