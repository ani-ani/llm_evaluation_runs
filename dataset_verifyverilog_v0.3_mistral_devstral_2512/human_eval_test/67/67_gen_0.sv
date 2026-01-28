module fruit_distribution(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [4:0] char_index,
    input [7:0] total_fruits,
    output reg [7:0] mangoes,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] READ_APPLE = 3'd1;
    localparam [2:0] READ_ORANGE = 3'd2;
    localparam [2:0] CALCULATE = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Internal storage for string
    reg [7:0] string_mem [0:31];
    reg [4:0] index;
    reg [2:0] state, next_state;
    reg [7:0] apples, oranges;
    reg [7:0] temp_value;
    reg [3:0] digit_count;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Character detection constants
    localparam [7:0] ASCII_0 = 8'd48;
    localparam [7:0] ASCII_9 = 8'd57;
    localparam [7:0] ASCII_SPACE = 8'd32;
    localparam [7:0] ASCII_a = 8'd97;
    localparam [7:0] ASCII_n = 8'd110;
    localparam [7:0] ASCII_d = 8'd100;
    localparam [7:0] ASCII_o = 8'd111;
    localparam [7:0] ASCII_r = 8'd114;
    localparam [7:0] ASCII_g = 8'd103;
    localparam [7:0] ASCII_e = 8'd101;
    localparam [7:0] ASCII_s = 8'd115;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            index <= 5'd0;
            apples <= 8'd0;
            oranges <= 8'd0;
            temp_value <= 8'd0;
            digit_count <= 4'd0;
            mangoes <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize string memory
            integer i;
            for (i = 0; i < 32; i = i + 1) begin
                string_mem[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= READ_APPLE;
                        index <= 5'd0;
                        temp_value <= 8'd0;
                        digit_count <= 4'd0;
                    end
                end
                
                READ_APPLE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if current character is a digit
                    if (char_index == index && char_in >= ASCII_0 && char_in <= ASCII_9) begin
                        temp_value <= temp_value * 8'd10 + (char_in - ASCII_0);
                        digit_count <= digit_count + 4'd1;
                        
                        // If we've read 2 digits or next character is not a digit, store apples
                        if (digit_count == 4'd2 || (index < 5'd31 && string_mem[index + 5'd1] < ASCII_0 || string_mem[index + 5'd1] > ASCII_9)) begin
                            apples <= temp_value;
                            temp_value <= 8'd0;
                            digit_count <= 4'd0;
                            next_state <= READ_ORANGE;
                        end
                    end
                    
                    // Move to next character
                    index <= index + 5'd1;
                    
                    // Timeout protection
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end
                end
                
                READ_ORANGE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Look for "and" pattern
                    if (index <= 5'd28 && 
                        string_mem[index] == ASCII_SPACE &&
                        string_mem[index + 5'd1] == ASCII_a &&
                        string_mem[index + 5'd2] == ASCII_n &&
                        string_mem[index + 5'd3] == ASCII_d &&
                        string_mem[index + 5'd4] == ASCII_SPACE) begin
                        index <= index + 5'd5;
                    end
                    
                    // Check if current character is a digit (after "and")
                    if (char_index == index && char_in >= ASCII_0 && char_in <= ASCII_9) begin
                        temp_value <= temp_value * 8'd10 + (char_in - ASCII_0);
                        digit_count <= digit_count + 4'd1;
                        
                        // If we've read 2 digits or next character is not a digit, store oranges
                        if (digit_count == 4'd2 || (index < 5'd31 && string_mem[index + 5'd1] < ASCII_0 || string_mem[index + 5'd1] > ASCII_9)) begin
                            oranges <= temp_value;
                            temp_value <= 8'd0;
                            digit_count <= 4'd0;
                            next_state <= CALCULATE;
                        end
                    end
                    
                    // Move to next character
                    index <= index + 5'd1;
                    
                    // Timeout protection
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end
                end
                
                CALCULATE: begin
                    // Compute mangoes = total_fruits - apples - oranges
                    mangoes <= total_fruits - apples - oranges;
                    next_state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

    // Store incoming characters
    always @(posedge clk) begin
        if (char_index < 5'd32) begin
            string_mem[char_index] <= char_in;
        end
    end

endmodule