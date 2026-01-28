module PatternDetector (
    input clk,
    input rst_n,
    input start,
    input [127:0] input_str,  // 16 chars * 8 bits
    input [3:0] str_len,
    output reg found,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] CHECK     = 3'd2;
    localparam [3:0] VALIDATE  = 3'd3;
    localparam [3:0] DONE_STATE = 3'd4;

    // Registers
    reg [2:0] state, next_state;
    reg [3:0] index;           // Current position to check
    reg [3:0] cycle_count;     // Prevent infinite loops
    reg found_reg;             // Internal found signal
    reg [7:0] char_a, char_b1, char_b2, char_b3;
    wire [7:0] char_at_idx;
    wire [7:0] char_at_idx_plus1;
    wire [7:0] char_at_idx_plus2;
    wire [7:0] char_at_idx_plus3;

    // Extract characters from packed input
    assign char_at_idx = input_str[(index*8) +: 8];
    assign char_at_idx_plus1 = input_str[((index + 4'd1)*8) +: 8];
    assign char_at_idx_plus2 = input_str[((index + 4'd2)*8) +: 8];
    assign char_at_idx_plus3 = input_str[((index + 4'd3)*8) +: 8];

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            cycle_count <= 4'd0;
            found_reg <= 1'b0;
            found <= 1'b0;
            done <= 1'b0;
            char_a <= 8'd0;
            char_b1 <= 8'd0;
            char_b2 <= 8'd0;
            char_b3 <= 8'd0;
        end else begin
            state <= next_state;
            
            // Default outputs
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    found <= 1'b0;
                    found_reg <= 1'b0;
                    index <= 4'd0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        // Reset done and found for new operation
                        done <= 1'b0;
                        found <= 1'b0;
                        found_reg <= 1'b0;
                    end
                end
                
                LOAD: begin
                    // Load characters at current index
                    char_a <= char_at_idx;
                    char_b1 <= char_at_idx_plus1;
                    char_b2 <= char_at_idx_plus2;
                    char_b3 <= char_at_idx_plus3;
                    cycle_count <= cycle_count + 4'd1;
                end
                
                CHECK: begin
                    // Check if pattern matches
                    if (char_a == 8'h61 && char_b1 == 8'h62 && 
                        char_b2 == 8'h62 && char_b3 == 8'h62) begin
                        found_reg <= 1'b1;
                    end
                    index <= index + 4'd1;
                end
                
                VALIDATE: begin
                    // Update found output and prepare for next check
                    if (found_reg) begin
                        found <= 1'b1;
                    end
                    cycle_count <= cycle_count + 4'd1;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    // Keep found stable
                    if (found_reg) begin
                        found <= 1'b1;
                    end
                end
                
                default: begin
                    state <= IDLE;
                    index <= 4'd0;
                    cycle_count <= 4'd0;
                    found_reg <= 1'b0;
                    found <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = IDLE;
        case (state)
            IDLE: begin
                if (start && str_len >= 4'd4) begin
                    next_state = LOAD;
                end else if (start && str_len < 4'd4) begin
                    next_state = DONE_STATE;  // Can't find pattern in < 4 chars
                end else begin
                    next_state = IDLE;
                end
            end
            
            LOAD: begin
                // Check if we have enough characters left
                if (index + 4'd3 < str_len) begin
                    next_state = CHECK;
                end else begin
                    next_state = DONE_STATE;
                end
            end
            
            CHECK: begin
                next_state = VALIDATE;
            end
            
            VALIDATE: begin
                // Check if we need to continue or finish
                if (found_reg) begin
                    next_state = DONE_STATE;  // Pattern found, stop searching
                end else if (index + 4'd3 < str_len && cycle_count < 4'd12) begin
                    next_state = LOAD;  // Continue scanning
                end else begin
                    next_state = DONE_STATE;  // End of string or timeout
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;  // Return to idle after one cycle
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule