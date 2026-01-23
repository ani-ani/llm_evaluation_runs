module bracket_evaluator(
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

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    reg [2:0] state;
    reg [7:0] current_value;
    reg current_mode;
    reg [7:0] stack_value [0:3];
    reg stack_mode [0:3];
    reg [3:0] stack_ptr;
    reg [3:0] token_index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_value <= 8'd0;
            current_mode <= 1'b0;
            stack_ptr <= 4'd0;
            token_index <= 4'd0;
            cycle_count <= 8'd0;
            result <= 8'd0;
            done <= 1'b0;
            error <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PROCESS;
                        current_value <= 8'd0;
                        current_mode <= 1'b0;
                        stack_ptr <= 4'd0;
                        token_index <= 4'd0;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Process current token
                    case (token_index)
                        4'd0: process_token(token_0);
                        4'd1: process_token(token_1);
                        4'd2: process_token(token_2);
                        4'd3: process_token(token_3);
                        4'd4: process_token(token_4);
                        4'd5: process_token(token_5);
                        4'd6: process_token(token_6);
                        4'd7: process_token(token_7);
                        4'd8: process_token(token_8);
                        4'd9: process_token(token_9);
                        4'd10: process_token(token_10);
                        4'd11: process_token(token_11);
                        4'd12: process_token(token_12);
                        4'd13: process_token(token_13);
                        4'd14: process_token(token_14);
                        4'd15: process_token(token_15);
                        default: ;
                    endcase
                    
                    // Check if done
                    if (token_index == token_count || cycle_count >= MAX_CYCLES) begin
                        if (stack_ptr != 4'd0) begin
                            error <= 1'b1;
                            state <= FINISH;
                        end else begin
                            result <= current_value;
                            state <= FINISH;
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // Token processing task
    task process_token;
        input [9:0] token;
        begin
            case (token[9:8])
                2'd0: begin // Number
                    if (current_mode == 1'b0) begin
                        current_value <= (current_value + token[7:0]) % 8'd256;
                    end else begin
                        current_value <= (current_value * token[7:0]) % 8'd256;
                    end
                    token_index <= token_index + 4'd1;
                end
                
                2'd1: begin // '('
                    if (stack_ptr == 4'd4) begin
                        error <= 1'b1;
                        state <= FINISH;
                    end else begin
                        stack_value[stack_ptr] <= current_value;
                        stack_mode[stack_ptr] <= current_mode;
                        stack_ptr <= stack_ptr + 4'd1;
                        current_mode <= ~current_mode;
                        if (current_mode == 1'b0) begin
                            current_value <= 8'd0;
                        end else begin
                            current_value <= 8'd1;
                        end
                        token_index <= token_index + 4'd1;
                    end
                end
                
                2'd2: begin // ')'
                    if (stack_ptr == 4'd0) begin
                        error <= 1'b1;
                        state <= FINISH;
                    end else begin
                        stack_ptr <= stack_ptr - 4'd1;
                        if (stack_mode[stack_ptr] == 1'b0) begin
                            current_value <= (stack_value[stack_ptr] + current_value) % 8'd256;
                        end else begin
                            current_value <= (stack_value[stack_ptr] * current_value) % 8'd256;
                        end
                        current_mode <= stack_mode[stack_ptr];
                        token_index <= token_index + 4'd1;
                    end
                end
                
                default: ;
            endcase
        end
    endtask

endmodule