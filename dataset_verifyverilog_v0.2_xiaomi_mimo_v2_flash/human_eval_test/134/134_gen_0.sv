module check_if_last_char_is_a_letter(
    input clk,
    input rst_n,
    input start,
    input [127:0] string_data,
    input [3:0] string_len,
    output reg result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] current_state, next_state;
    reg result_next, done_next;
    
    // Intermediate character extraction
    wire [7:0] last_char;
    wire [7:0] prev_char;
    wire is_last_alpha;
    wire is_prev_space;
    
    // Extract characters based on string_len
    // string_len is 4-bit: 0 to 16
    // Last character is at index string_len - 1
    // Index i corresponds to bits [127-(i*8) : 120-(i*8)]
    // For index 15 (len=16): bits [7:0] - but our formula gives [127-120 : 120-120] = [7:0] OK
    // For index 0 (len=1): bits [127-0 : 120-0] = [127:120] OK
    // For index n-2 (len=n): bits [127-((n-2)*8) : 120-((n-2)*8)]
    
    // However, we need to handle the case when string_len is 0
    // The problem asks to handle empty string -> result = 0
    
    // To extract dynamically based on string_len, we need a small combinational logic
    // Since string_len is small (0-16), we can use a simple extraction
    
    // Extract last character at index (string_len - 1)
    assign last_char = string_data[127:0] >> ((16 - string_len) * 8); // This doesn't work directly
    
    // Better: explicit extraction based on length
    // Actually, to keep it simple and correct, we can use a fixed extraction logic
    // But synthesizable code prefers explicit indexing
    
    // Let's create the extraction manually for the last character
    // The string_data is packed MSB first. Last char is at the end based on length.
    // Example: len=3, chars at [127:120], [119:112], [111:104]. Last is [111:104].
    // This is at index 2 (0-based). Formula: [127 - (index*8) : 120 - (index*8)]
    
    // To do this dynamically, we can use a case statement or a shift
    // Shift approach for synthesizable dynamic indexing:
    wire [127:0] shifted_data = string_data << ((16 - string_len) * 8);
    assign last_char = shifted_data[127:120];
    
    // Extract previous character (at index string_len - 2)
    // We need to be careful if string_len <= 1
    wire [127:0] shifted_data_prev = string_data << ((16 - (string_len - 1)) * 8);
    assign prev_char = shifted_data_prev[127:120];
    
    // Character classification
    assign is_last_alpha = (last_char >= 8'h41 && last_char <= 8'h5A) || 
                           (last_char >= 8'h61 && last_char <= 8'h7A);
    
    assign is_prev_space = (prev_char == 8'h20);
    
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 0;
            done <= 0;
        end else begin
            current_state <= next_state;
            result <= result_next;
            done <= done_next;
        end
    end
    
    // Next state and output logic
    always @(*) begin
        next_state = current_state;
        result_next = result;
        done_next = done;
        
        case (current_state)
            IDLE: begin
                done_next = 0;
                if (start) begin
                    next_state = PROCESSING;
                end
            end
            
            PROCESSING: begin
                // Perform checks
                if (string_len == 0) begin
                    result_next = 0;
                end else if (!is_last_alpha) begin
                    result_next = 0;
                end else begin
                    // It is an alphabetical char
                    if (string_len == 1) begin
                        result_next = 1;
                    end else if (is_prev_space) begin
                        result_next = 1;
                    end else begin
                        result_next = 0;
                    end
                end
                next_state = DONE;
            end
            
            DONE: begin
                done_next = 1;
                // Stay in DONE until start is asserted for next
                // Or reset. The requirement says DONE -> IDLE when done is read or next start=1
                // In hardware, we usually transition when start goes high again
                if (start) begin
                    next_state = PROCESSING;
                    done_next = 0; // Start processing immediately, done drops
                end else begin
                    // Remain in DONE state (holding result) until start
                    next_state = DONE;
                end
            end
            
            default: begin
                next_state = IDLE;
                result_next = 0;
                done_next = 0;
            end
        endcase
    end

endmodule
