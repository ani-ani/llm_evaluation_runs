module ascii_uppercase(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_0,
    input [7:0] char_1,
    input [7:0] char_2,
    input [7:0] char_3,
    input [7:0] char_4,
    input [7:0] char_5,
    input [7:0] char_6,
    input [7:0] char_7,
    input [3:0] length,
    output reg [7:0] result_0,
    output reg [7:0] result_1,
    output reg [7:0] result_2,
    output reg [7:0] result_3,
    output reg [7:0] result_4,
    output reg [7:0] result_5,
    output reg [7:0] result_6,
    output reg [7:0] result_7,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] FINISH  = 3'd2;
    
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] index;
    reg [7:0] current_char;
    reg [7:0] current_result;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            current_char <= 8'd0;
            current_result <= 8'd0;
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            result_3 <= 8'd0;
            result_4 <= 8'd0;
            result_5 <= 8'd0;
            result_6 <= 8'd0;
            result_7 <= 8'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= PROCESS;
                        index <= 4'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                PROCESS: begin
                    // Select current character based on index
                    case (index)
                        4'd0: current_char <= char_0;
                        4'd1: current_char <= char_1;
                        4'd2: current_char <= char_2;
                        4'd3: current_char <= char_3;
                        4'd4: current_char <= char_4;
                        4'd5: current_char <= char_5;
                        4'd6: current_char <= char_6;
                        4'd7: current_char <= char_7;
                        default: current_char <= 8'd0;
                    endcase
                    
                    // Convert to uppercase if lowercase
                    if (current_char >= 8'd97 && current_char <= 8'd122) begin
                        current_result <= current_char - 8'd32;
                    end else begin
                        current_result <= current_char;
                    end
                    
                    // Store result
                    case (index)
                        4'd0: result_0 <= current_result;
                        4'd1: result_1 <= current_result;
                        4'd2: result_2 <= current_result;
                        4'd3: result_3 <= current_result;
                        4'd4: result_4 <= current_result;
                        4'd5: result_5 <= current_result;
                        4'd6: result_6 <= current_result;
                        4'd7: result_7 <= current_result;
                    endcase
                    
                    // Move to next character or finish
                    if (index == length - 4'd1) begin
                        next_state <= FINISH;
                    end else begin
                        index <= index + 4'd1;
                        next_state <= PROCESS;
                    end
                end
                
                FINISH: begin
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
    
    // Clear results beyond length
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            result_3 <= 8'd0;
            result_4 <= 8'd0;
            result_5 <= 8'd0;
            result_6 <= 8'd0;
            result_7 <= 8'd0;
        end else begin
            if (index > length - 4'd1) begin
                case (index)
                    4'd0: if (length <= 4'd0) result_0 <= 8'd0;
                    4'd1: if (length <= 4'd1) result_1 <= 8'd0;
                    4'd2: if (length <= 4'd2) result_2 <= 8'd0;
                    4'd3: if (length <= 4'd3) result_3 <= 8'd0;
                    4'd4: if (length <= 4'd4) result_4 <= 8'd0;
                    4'd5: if (length <= 4'd5) result_5 <= 8'd0;
                    4'd6: if (length <= 4'd6) result_6 <= 8'd0;
                    4'd7: if (length <= 4'd7) result_7 <= 8'd0;
                endcase
            end
        end
    end
endmodule