module wire_untangle (
    input clk,              // Clock signal
    input rst_n,            // Active-low reset
    input start,            // Start pulse (1 cycle) to begin new sequence
    input char_in,          // Current character: 0 for '-', 1 for '+'
    input valid_in,         // Valid input indicator
    input last,             // Last character of sequence indicator
    output reg done,        // Done signal (1 cycle) when computation complete
    output reg result       // Result: 0 for "No", 1 for "Yes"
);

// State definitions
localparam [2:0] IDLE      = 3'd0;
localparam [2:0] PROCESS   = 3'd1;
localparam [2:0] FINISH    = 3'd2;

// Internal registers
reg [2:0] state;
reg [15:0] stack_data;     // Stack storage: each bit represents one element
reg [4:0] stack_depth;     // Current number of elements in stack (0-16)
reg finished;              // Flag to ignore extra characters after last

// State machine for processing
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        stack_data <= 16'b0;
        stack_depth <= 5'b0;
        done <= 1'b0;
        result <= 1'b0;
        finished <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                stack_data <= 16'b0;
                stack_depth <= 5'b0;
                finished <= 1'b0;
                if (start) begin
                    state <= PROCESS;
                end
            end
            
            PROCESS: begin
                done <= 1'b0;
                if (valid_in && !finished) begin
                    // Process new character
                    if (stack_depth != 5'b0 && stack_data[0] == char_in) begin
                        // Pop operation: top matches current character
                        stack_data <= {1'b0, stack_data[15:1]};
                        stack_depth <= stack_depth - 5'd1;
                    end else begin
                        // Push operation: add new character to stack
                        if (stack_depth < 5'd16) begin
                            stack_data <= {stack_data[14:0], char_in};
                            stack_depth <= stack_depth + 5'd1;
                        end
                        // If stack full, ignore (will result in No anyway)
                    end
                    
                    // If this is the last character, transition to finish
                    if (last) begin
                        state <= FINISH;
                    end
                end
            end
            
            FINISH: begin
                done <= 1'b1;
                result <= (stack_depth == 5'b0) ? 1'b1 : 1'b0;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule