module trade_pattern_matcher #(
    parameter CLK_FREQ = 100,
    parameter integer STRING_LEN = 17,
    parameter [0:STRING_LEN*8-1] ROM_DATA = {8'h41, 8'h42, 8'h41, 8'h42, 8'h41, 8'h42, 8'h63, 8'h41, 8'h42, 8'h41, 8'h42, 8'h41, 8'h62, 8'h41, 8'h62, 8'h61, 8'h62}
) (
    input clk,
    input rst_n,
    input start,
    input [5:0] i,
    input [5:0] j,
    output reg [5:0] result,
    output reg done
);

    // State Encoding
    localparam IDLE = 2'b00;
    localparam COMPARE = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] current_state;
    reg [1:0] next_state;

    // Internal Registers
    reg [5:0] idx_i;
    reg [5:0] idx_j;
    reg [5:0] len;
    reg char_match;

    // Combinational Logic for ROM Read
    // Correct indexing for packed parameter: byte 0 is at MSB of ROM_DATA[0]*8, or we can index by byte.
    // Verilog parameter string indexing usually treats indices as byte selects.
    // However, packed arrays index by [word][bit]. We need 8-bit ASCII.
    // Constructed as {8'h41, 8'h42...}. Index 0 should be 8'h41.
    wire [7:0] char_i = ROM_DATA[(STRING_LEN-1 - idx_i)*8 +: 8];
    wire [7:0] char_j = ROM_DATA[(STRING_LEN-1 - idx_j)*8 +: 8];

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State Logic & Output Logic
    always @(*) begin
        // Default assignments
        next_state = current_state;
        done = 1'b0;
        
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = COMPARE;
                end
            end
            
            COMPARE: begin
                // Check bounds and match condition
                // If mismatch OR out of bounds OR reached max length (64) OR reached string end
                if (!char_match || 
                    (idx_i >= STRING_LEN - 1) || 
                    (idx_j >= STRING_LEN - 1) || 
                    len >= 63 ||
                    (idx_i + 1 >= STRING_LEN) || 
                    (idx_j + 1 >= STRING_LEN)) begin
                    next_state = DONE;
                end
            end
            
            DONE: begin
                done = 1'b1;
                // Wait for reset or next start implicitly by IDLE transition on start
                if (start) begin
                    next_state = COMPARE;
                end else if (!rst_n) begin
                    next_state = IDLE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 6'b0;
            len <= 6'b0;
            idx_i <= 6'b0;
            idx_j <= 6'b0;
            char_match <= 1'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    if (start) begin
                        // Initialize for new comparison
                        result <= 6'b0;
                        len <= 6'b0;
                        idx_i <= i;
                        idx_j <= j;
                        // Pre-fetch comparison check for COMPARE state
                        // Since registers update on posedge, the COMPARE state logic sees inputs from previous cycle.
                        // To align, we handle the first comparison logic here or pipeline correctly.
                        // Simplification: We set the registers to start state. The comparison logic in ALWAYS block runs continuously.
                        // The state transition happens based on these values.
                        // However, to avoid 1-cycle delay in IDLE->COMPARE, we need to load valid compare data.
                        // But standard FSM: State switches, then logic executes. 
                        // We will rely on the COMPARE state logic. 
                    end
                end
                
                COMPARE: begin
                    // Load current chars for comparison
                    // Note: char_i/char_j are wires based on idx_i/j. 
                    // In same cycle, wires update. Comparison happens.
                    // If match, we increment result, and prepare indices for next cycle.
                    
                    if (char_match && (idx_i + 1 < STRING_LEN) && (idx_j + 1 < STRING_LEN) && (len < 63)) begin
                        result <= result + 1;
                        len <= len + 1;
                        idx_i <= idx_i + 1;
                        idx_j <= idx_j + 1;
                    end
                    // If we stop, we stay in registers until DONE. 
                    // When transitioning to DONE, we finalize 'result'.
                end
                
                DONE: begin
                    // Result is finalized. 
                    // Registers hold values.
                    if (start) begin
                        // Re-initialize on start pulse while in DONE
                        result <= 6'b0;
                        len <= 6'b0;
                        idx_i <= i;
                        idx_j <= j;
                    end
                end
            endcase
        end
    end

    // Match condition logic (Independent of state for cleaner code, used in combinational next_state logic)
    // We need to detect match based on currently loaded indices.
    // The indices update on clock edge. 
    // So in state COMPARE, idx_i/j point to the chars to compare *this cycle*.
    // If we just updated idx_i (from previous cycle), we compare those chars.
    // If they match, we increment (in next cycle). 
    // Wait, standard synchronous logic:
    // 1. Cycle N: State = COMPARE. Idx = X. Compare (X, X). Result = N.
    // 2. If Match: Update Idx to X+1, Result to N+1 (next cycle).
    // 3. Cycle N+1: State = COMPARE. Idx = X+1. 
    // 
    // The 'char_match' register helps sync the comparison result.
    // In COMPARE state, we compare char_i and char_j (current indices).
    // If they match, we signal 'match' for next cycle increment.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            char_match <= 1'b0;
        end else if (current_state == COMPARE) begin
            char_match <= (char_i == char_j);
        end else begin
            char_match <= 1'b0;
        end
    end

endmodule
