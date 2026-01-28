module StringPatternChecker (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] string_chars [0:15],
    input wire [15:0] valid_chars,
    output reg match,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] CHECK    = 3'd1;
    localparam [2:0] OUTPUT   = 3'd2;
    localparam [2:0] DONE     = 3'd3;

    // Internal registers and variables
    reg [2:0] state, next_state;
    reg [7:0] match_result;
    reg [4:0] char_idx;  // 0-15
    reg has_start_a;
    reg has_end_b;
    reg [7:0] end_b_idx;  // Store index of last 'b' found
    reg processing_done;
    
    // ASCII constants
    localparam [7:0] CHAR_A = 8'h61;  // 'a'
    localparam [7:0] CHAR_B = 8'h62;  // 'b'

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            match <= 1'b0;
            done <= 1'b0;
            char_idx <= 5'd0;
            has_start_a <= 1'b0;
            has_end_b <= 1'b0;
            end_b_idx <= 8'd0;
            match_result <= 8'd0;
            processing_done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    match <= 1'b0;
                    done <= 1'b0;
                    char_idx <= 5'd0;
                    has_start_a <= 1'b0;
                    has_end_b <= 1'b0;
                    end_b_idx <= 8'd0;
                    match_result <= 8'd0;
                    processing_done <= 1'b0;
                    
                    if (start) begin
                        // Start processing
                    end
                end
                
                CHECK: begin
                    if (char_idx == 5'd16) begin
                        processing_done <= 1'b1;
                        // Evaluate conditions
                        if (has_start_a && has_end_b) begin
                            match_result <= 8'd1;
                        end else begin
                            match_result <= 8'd0;
                        end
                    end else begin
                        // Check current character
                        if (valid_chars[char_idx]) begin
                            if (char_idx == 5'd0) begin
                                // Check first character for 'a'
                                if (string_chars[char_idx] == CHAR_A) begin
                                    has_start_a <= 1'b1;
                                end
                            end
                            
                            // Always check for 'b' (will overwrite with last occurrence)
                            if (string_chars[char_idx] == CHAR_B) begin
                                has_end_b <= 1'b1;
                                end_b_idx <= char_idx;
                            end
                        end
                    end
                    
                    // Increment index
                    char_idx <= char_idx + 5'd1;
                end
                
                OUTPUT: begin
                    match <= match_result[0];
                end
                
                DONE: begin
                    done <= 1'b1;
                    match <= 1'b0;
                    processing_done <= 1'b0;
                    char_idx <= 5'd0;
                end
                
                default: begin
                    state <= IDLE;
                    match <= 1'b0;
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
                if (start) begin
                    next_state = CHECK;
                end else begin
                    next_state = IDLE;
                end
            end
            
            CHECK: begin
                if (processing_done && (char_idx > 5'd16)) begin
                    // Should not happen, but safety
                    next_state = OUTPUT;
                end else if (char_idx == 5'd17) begin
                    // Complete after checking all 16 chars
                    next_state = OUTPUT;
                end else begin
                    next_state = CHECK;
                end
            end
            
            OUTPUT: begin
                next_state = DONE;
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule