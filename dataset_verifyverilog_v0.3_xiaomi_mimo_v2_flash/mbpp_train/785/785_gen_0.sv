module tuple_str_int (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire [3:0] char_len,
    output reg [7:0] result_arr_0,
    output reg [7:0] result_arr_1,
    output reg [7:0] result_arr_2,
    output reg [7:0] result_arr_3,
    output reg [7:0] result_arr_4,
    output reg [7:0] result_arr_5,
    output reg [7:0] result_arr_6,
    output reg [7:0] result_arr_7,
    output reg [3:0] result_len,
    output reg done,
    output reg error
);

// This module parses a tuple string format: "(num1, num2, ...)"
// Input: Serial stream of ASCII characters via char_in
//        char_len = actual string length (excluding parentheses)
// Processing: 
//    - Accepts characters on each clock cycle after start
//    - Parses comma-separated integers
//    - Stores up to 8 numbers in output array
//    - Handles 1-2 digit numbers (0-99)
// Output: result_arr contains parsed integers, result_len = count

// States
localparam [1:0] IDLE = 2'd0;
localparam [1:0] PARSING = 2'd1;
localparam [1:0] WAIT_DONE = 2'd2;
reg [1:0] state;

// Internal counters and buffers
reg [3:0] char_idx;        // Current character index
reg [3:0] num_idx;         // Current number index in result array
reg [7:0] current_num;     // Accumulator for current number
reg [7:0] digit_count;     // Digits in current number
reg [7:0] temp_char;       // Current character buffer

// ASCII constants
localparam [7:0] COMMA = 8'h2C;
localparam [7:0] SPACE = 8'h20;
localparam [7:0] RPAREN = 8'h29;
localparam [7:0] ZERO = 8'h30;
localparam [7:0] NINE = 8'h39;

integer i;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        error <= 1'b0;
        result_len <= 4'd0;
        char_idx <= 4'd0;
        num_idx <= 4'd0;
        current_num <= 8'd0;
        digit_count <= 8'd0;
        result_arr_0 <= 8'd0;
        result_arr_1 <= 8'd0;
        result_arr_2 <= 8'd0;
        result_arr_3 <= 8'd0;
        result_arr_4 <= 8'd0;
        result_arr_5 <= 8'd0;
        result_arr_6 <= 8'd0;
        result_arr_7 <= 8'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                error <= 1'b0;
                if (start) begin
                    state <= PARSING;
                    char_idx <= 4'd0;
                    num_idx <= 4'd0;
                    current_num <= 8'd0;
                    digit_count <= 8'd0;
                end
            end
            
            PARSING: begin
                if (char_idx < char_len) begin
                    temp_char <= char_in;
                    
                    // Process character
                    if (char_in >= ZERO && char_in <= NINE) begin
                        // Number digit
                        if (digit_count < 2'd2) begin
                            current_num <= (current_num * 8'd10) + (char_in - ZERO);
                            digit_count <= digit_count + 8'd1;
                        end else begin
                            error <= 1'b1;
                            state <= WAIT_DONE;
                        end
                    end else if (char_in == COMMA || char_in == SPACE) begin
                        // End of number (ignore space)
                        if (digit_count > 8'd0 && num_idx < 4'd8) begin
                            case (num_idx)
                                4'd0: result_arr_0 <= current_num;
                                4'd1: result_arr_1 <= current_num;
                                4'd2: result_arr_2 <= current_num;
                                4'd3: result_arr_3 <= current_num;
                                4'd4: result_arr_4 <= current_num;
                                4'd5: result_arr_5 <= current_num;
                                4'd6: result_arr_6 <= current_num;
                                4'd7: result_arr_7 <= current_num;
                            endcase
                            num_idx <= num_idx + 4'd1;
                            current_num <= 8'd0;
                            digit_count <= 8'd0;
                        end
                    end else if (char_in == RPAREN) begin
                        // End of string
                        if (digit_count > 8'd0 && num_idx < 4'd8) begin
                            case (num_idx)
                                4'd0: result_arr_0 <= current_num;
                                4'd1: result_arr_1 <= current_num;
                                4'd2: result_arr_2 <= current_num;
                                4'd3: result_arr_3 <= current_num;
                                4'd4: result_arr_4 <= current_num;
                                4'd5: result_arr_5 <= current_num;
                                4'd6: result_arr_6 <= current_num;
                                4'd7: result_arr_7 <= current_num;
                            endcase
                            num_idx <= num_idx + 4'd1;
                        end
                        if (digit_count > 8'd0) begin
                            result_len <= num_idx + 4'd1;
                        end else begin
                            result_len <= num_idx;
                        end
                        state <= WAIT_DONE;
                    end else begin
                        // Invalid character
                        error <= 1'b1;
                        state <= WAIT_DONE;
                    end
                    
                    char_idx <= char_idx + 4'd1;
                end else begin
                    // End of input
                    result_len <= num_idx;
                    state <= WAIT_DONE;
                end
            end
            
            WAIT_DONE: begin
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule