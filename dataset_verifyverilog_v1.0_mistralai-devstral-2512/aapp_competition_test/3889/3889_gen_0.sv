module PuppyColorCheck(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] s_0,
    input wire [7:0] s_1,
    input wire [7:0] s_2,
    input wire [7:0] s_3,
    input wire [7:0] s_4,
    input wire [7:0] s_5,
    input wire [7:0] s_6,
    input wire [7:0] s_7,
    input wire [7:0] s_8,
    input wire [7:0] s_9,
    input wire [7:0] s_10,
    input wire [7:0] s_11,
    input wire [7:0] s_12,
    input wire [7:0] s_13,
    input wire [7:0] s_14,
    input wire [7:0] s_15,
    input wire [3:0] len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] CHECKING = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] i;
    reg [3:0] counts [0:25];
    reg [7:0] current_char;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd200;

    // Character to index conversion
    function [3:0] char_to_index;
        input [7:0] c;
        begin
            if (c >= 8'd97 && c <= 8'd122) begin
                char_to_index = c - 8'd97;
            end else begin
                char_to_index = 4'd0;
            end
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            i <= 4'd0;
            cycle_count <= 4'd0;
            // Initialize counts array
            integer j;
            for (j = 0; j < 26; j = j + 1) begin
                counts[j] <= 4'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                end
            end
            
            PROCESSING: begin
                if (i == len - 4'd1) begin
                    next_state = CHECKING;
                end
            end
            
            CHECKING: begin
                next_state = DONE_STATE;
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Processing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i <= 4'd0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    cycle_count <= 4'd0;
                end
                
                PROCESSING: begin
                    cycle_count <= cycle_count + 4'd1;
                    // Select current character based on index
                    case (i)
                        4'd0: current_char = s_0;
                        4'd1: current_char = s_1;
                        4'd2: current_char = s_2;
                        4'd3: current_char = s_3;
                        4'd4: current_char = s_4;
                        4'd5: current_char = s_5;
                        4'd6: current_char = s_6;
                        4'd7: current_char = s_7;
                        4'd8: current_char = s_8;
                        4'd9: current_char = s_9;
                        4'd10: current_char = s_10;
                        4'd11: current_char = s_11;
                        4'd12: current_char = s_12;
                        4'd13: current_char = s_13;
                        4'd14: current_char = s_14;
                        4'd15: current_char = s_15;
                        default: current_char = 8'd0;
                    endcase
                    
                    // Increment count for this character
                    counts[char_to_index(current_char)] <= counts[char_to_index(current_char)] + 4'd1;
                    
                    // Move to next character
                    if (i < len - 4'd1) begin
                        i <= i + 4'd1;
                    end
                end
                
                CHECKING: begin
                    // Check if any count >= 2 or len == 1
                    reg [3:0] j;
                    reg found;
                    found = 1'b0;
                    
                    for (j = 0; j < 26; j = j + 1) begin
                        if (counts[j] >= 4'd2) begin
                            found = 1'b1;
                        end
                    end
                    
                    if (len == 4'd1 || found) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    done <= 1'b0;
                    result <= 1'b0;
                end
            endcase
        end
    end

endmodule