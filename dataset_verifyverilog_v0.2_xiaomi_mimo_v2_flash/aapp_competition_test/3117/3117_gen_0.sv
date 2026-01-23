module longest_repeated_substring (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] char_in [0:15],
    output reg [4:0] max_len,
    output reg done
);

    // Parameters
    parameter N = 16;
    parameter CHAR_W = 5;

    // State encoding (3 bits, 8 states)
    localparam IDLE = 3'b000;
    localparam CHECK_LEN = 3'b001;
    localparam SETUP_I = 3'b010;
    localparam SETUP_J = 3'b011;
    localparam COMPARE = 3'b100;
    localparam NEXT_J = 3'b101;
    localparam NEXT_I = 3'b110;
    localparam NEXT_LEN = 3'b111;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state; // Next state for combinational logic
    reg [3:0] len;        // Current substring length (1..15)
    reg [3:0] i;          // Start index of first substring
    reg [3:0] j;          // Start index of second substring
    reg [3:0] k;          // Character index for comparison

    // Combinational Next State Logic
    always @(*) begin
        next_state = state; // Default: stay in current state
        
        case (state)
            IDLE: begin
                if (start) next_state = CHECK_LEN;
            end
            
            CHECK_LEN: begin
                if (len > 0) next_state = SETUP_I;
                else next_state = IDLE; // No more lengths to check
            end
            
            SETUP_I: begin
                // i is set to 0 in the sequential block
                next_state = SETUP_J;
            end
            
            SETUP_J: begin
                // j is set to i+1 in the sequential block
                // Check if j is within valid range (j <= N - len)
                if (j <= N - len) begin
                    next_state = COMPARE;
                end else begin
                    next_state = NEXT_I;
                end
            end
            
            COMPARE: begin
                // Compare char_in[i+k] vs char_in[j+k]
                // If mismatch, move to next j
                if (char_in[i+k] != char_in[j+k]) begin
                    next_state = NEXT_J;
                end else begin
                    // If match, check if we reached the full length
                    if (k + 1 == len) begin
                        next_state = IDLE; // Found duplicate substring!
                    end else begin
                        next_state = COMPARE; // Continue comparing next character
                    end
                end
            end
            
            NEXT_J: begin
                // j is incremented in sequential block
                if (j + 1 <= N - len) begin
                    next_state = SETUP_J;
                end else begin
                    next_state = NEXT_I;
                end
            end
            
            NEXT_I: begin
                // i is incremented in sequential block
                // Check if we can still start a substring with this i (i+1 < N - len implies j = i+1 <= N-len)
                // Actually, valid i range is [0, N - len - 1]
                if (i + 1 < N - len) begin
                    next_state = SETUP_J;
                end else begin
                    next_state = NEXT_LEN;
                end
            end
            
            NEXT_LEN: begin
                next_state = CHECK_LEN;
            end
        endcase
    end

    // Sequential Logic and Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_len <= 5'b0;
            done <= 1'b0;
            len <= 4'd15;
            i <= 4'b0;
            j <= 4'b0;
            k <= 4'b0;
        end else begin
            state <= next_state;
            
            // Default assignments
            done <= 1'b0;
            
            case (next_state)
                IDLE: begin
                    // Check if we are transitioning from a valid computation
                    if (state == COMPARE) begin
                        // We came from COMPARE, which implies a match was found (transition logic)
                        max_len <= len;
                        done <= 1'b1;
                    end else if (state == CHECK_LEN && len == 0) begin
                        // Length exhausted, no match found
                        max_len <= 5'b0; // Optional, max_len already holds value from previous checks (or 0)
                        done <= 1'b1;
                    end
                    
                    // Handle start signal to reset counters and max_len
                    if (start) begin
                        max_len <= 5'b0;
                        len <= 4'd15;
                        done <= 1'b0;
                    end
                end
                
                SETUP_I: begin
                    i <= 4'd0;
                end
                
                SETUP_J: begin
                    // Update j based on transition source
                    if (state == NEXT_J) begin
                        j <= j + 1; // Increment j
                    end else begin
                        // From SETUP_I or NEXT_I (where i was just incremented)
                        j <= i + 1;
                    end
                    k <= 4'd0; // Reset character counter
                end
                
                COMPARE: begin
                    // Increment k only if we are staying in COMPARE (i.e., previous comparison matched)
                    if (state == COMPARE) begin
                        k <= k + 1;
                    end
                    // Note: If state was SETUP_J, we enter COMPARE with k=0 and compare immediately.
                end
                
                NEXT_I: begin
                    i <= i + 1;
                end
                
                NEXT_LEN: begin
                    len <= len - 1;
                end
            endcase
        end
    end

endmodule