module string_list_reverse (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input valid_in,
    input [2:0] str_len,
    output reg [7:0] char_out,
    output reg valid_out,
    output reg done,
    output reg [2:0] out_idx
);

    // Parameters
    parameter MAX_STRINGS = 4;
    parameter MAX_LEN = 8;
    
    // State encoding
    parameter IDLE = 3'b000;
    parameter READ_STR = 3'b001;
    parameter REVERSE = 3'b010;
    parameter OUTPUT = 3'b011;
    parameter DONE = 3'b100;
    
    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] buffer [0:MAX_STRINGS-1][0:MAX_LEN-1]; // 4x8 buffer
    reg [2:0] str_count; // Count of strings processed (0-4)
    reg [2:0] char_count; // Character counter (0-7)
    reg [2:0] current_len; // Length of current string being read
    reg [2:0] output_idx; // Output index counter
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state and output logic
    always @(*) begin
        // Default values
        next_state = state;
        done = 1'b0;
        valid_out = 1'b0;
        char_out = 8'b0;
        out_idx = 3'b0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = READ_STR;
                end
            end
            
            READ_STR: begin
                if (valid_in && (char_count < current_len)) begin
                    // Character is being read (handled in sequential block)
                end
                // Transition to REVERSE when all chars for this string are read
                if (char_count >= current_len && str_count < MAX_STRINGS) begin
                    next_state = REVERSE;
                end
                // If we've read all 4 strings, go to DONE
                if (char_count >= current_len && str_count >= MAX_STRINGS) begin
                    next_state = DONE;
                end
                // If start goes low while reading, we wait for completion
            end
            
            REVERSE: begin
                // Process is done in sequential logic, transition to OUTPUT
                next_state = OUTPUT;
            end
            
            OUTPUT: begin
                valid_out = 1'b1;
                // Output current character
                if (output_idx < current_len) begin
                    out_idx = output_idx;
                    // Character assignment done in sequential logic
                end
                // Transition to next state
                if (output_idx >= current_len) begin
                    // Move to next string
                    if (str_count < MAX_STRINGS) begin
                        next_state = READ_STR;
                    end else begin
                        next_state = DONE;
                    end
                end
            end
            
            DONE: begin
                done = 1'b1;
                if (start) begin
                    next_state = READ_STR;
                end
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Sequential logic for data processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            str_count <= 3'b0;
            char_count <= 3'b0;
            current_len <= 3'b0;
            output_idx <= 3'b0;
            char_out <= 8'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        str_count <= 3'b0;
                        char_count <= 3'b0;
                        output_idx <= 3'b0;
                    end
                end
                
                READ_STR: begin
                    if (valid_in && (char_count < current_len)) begin
                        buffer[str_count][char_count] <= char_in;
                        char_count <= char_count + 1;
                    end
                    // Store the length when starting a new string
                    if (char_count == 0 && valid_in) begin
                        current_len <= str_len;
                    end
                    // Reset counter and increment string count when done reading
                    if (char_count >= current_len && valid_in) begin
                        char_count <= 3'b0;
                        str_count <= str_count + 1;
                    end
                end
                
                REVERSE: begin
                    // No specific action needed, data is already in buffer
                    // But reset output index
                    output_idx <= 3'b0;
                end
                
                OUTPUT: begin
                    if (output_idx < current_len) begin
                        // Output from buffer in reverse order
                        char_out <= buffer[str_count][current_len - 1 - output_idx];
                        out_idx <= output_idx;
                        output_idx <= output_idx + 1;
                    end
                    // When done with this string, prepare for next
                    if (output_idx >= current_len) begin
                        char_count <= 3'b0;
                    end
                end
                
                DONE: begin
                    // Hold done signal high
                end
            endcase
        end
    end
    
endmodule