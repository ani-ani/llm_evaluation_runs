module vowels_count (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [4:0] length,
    output reg [4:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK_CHAR = 2'd1;
    localparam [1:0] DONE = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [4:0] index;           // Current character index (0 to length-1)
    reg [4:0] result_next;
    reg is_last_char;
    reg is_vowel;

    // Combinational logic for vowel detection
    always @(*) begin
        // Default: not a vowel
        is_vowel = 1'b0;
        
        // Check standard vowels (case-insensitive)
        if (char_in == 8'h61 || char_in == 8'h41 || // a/A
            char_in == 8'h65 || char_in == 8'h45 || // e/E
            char_in == 8'h69 || char_in == 8'h49 || // i/I
            char_in == 8'h6F || char_in == 8'h4F || // o/O
            char_in == 8'h75 || char_in == 8'h55) begin // u/U
            is_vowel = 1'b1;
        end
        
        // Check for 'y' or 'Y' (only if last character)
        is_last_char = (index == (length - 5'd1));
        if (is_last_char && (char_in == 8'h79 || char_in == 8'h59)) begin
            is_vowel = 1'b1;
        end
        
        // Determine next result value
        if (is_vowel) begin
            result_next = result + 5'd1;
        end else begin
            result_next = result;
        end
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            index <= 5'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 5'd0;
                    index <= 5'd0;
                    if (start) begin
                        state <= CHECK_CHAR;
                    end
                end
                
                CHECK_CHAR: begin
                    // Check current character and update result
                    result <= result_next;
                    
                    // Move to next index
                    index <= index + 5'd1;
                    
                    // Check if we've processed all characters
                    if (index + 5'd1 == length) begin
                        state <= DONE;
                    end else begin
                        state <= CHECK_CHAR;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule