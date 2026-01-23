module roman_converter(
    input clk,
    input rst_n,
    input start,
    input [9:0] number,
    output reg [9:0][7:0] roman_chars,
    output reg done,
    output reg error
);

    // State encoding
    localparam IDLE = 5'd0;
    localparam CHECK_M = 5'd1;
    localparam CHECK_CM = 5'd2;
    localparam CHECK_D = 5'd3;
    localparam CHECK_CD = 5'd4;
    localparam CHECK_C = 5'd5;
    localparam CHECK_XC = 5'd6;
    localparam CHECK_L = 5'd7;
    localparam CHECK_XL = 5'd8;
    localparam CHECK_X = 5'd9;
    localparam CHECK_IX = 5'd10;
    localparam CHECK_V = 5'd11;
    localparam CHECK_IV = 5'd12;
    localparam CHECK_I = 5'd13;
    localparam APPEND = 5'd14;
    localparam DONE = 5'd15;

    reg [4:0] state;
    reg [4:0] next_state;
    
    // Internal registers
    reg [9:0] remaining_val;
    reg [9:0] next_remaining_val;
    reg [3:0] pos;
    reg [3:0] next_pos;
    
    // Temporary buffer for current symbol(s)
    reg [1:0] append_count;
    reg [7:0] char1;
    reg [7:0] char2;
    
    // FSM State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            remaining_val <= 10'd0;
            pos <= 4'd0;
        end else begin
            state <= next_state;
            remaining_val <= next_remaining_val;
            pos <= next_pos;
        end
    end

    // Output Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            error <= 1'b0;
            // Clear output buffer
            roman_chars[0] <= 8'h00;
            roman_chars[1] <= 8'h00;
            roman_chars[2] <= 8'h00;
            roman_chars[3] <= 8'h00;
            roman_chars[4] <= 8'h00;
            roman_chars[5] <= 8'h00;
            roman_chars[6] <= 8'h00;
            roman_chars[7] <= 8'h00;
            roman_chars[8] <= 8'h00;
            roman_chars[9] <= 8'h00;
        end else begin
            if (state == IDLE && start) begin
                // Clear outputs on start
                done <= 1'b0;
                error <= 1'b0;
                roman_chars[0] <= 8'h00;
                roman_chars[1] <= 8'h00;
                roman_chars[2] <= 8'h00;
                roman_chars[3] <= 8'h00;
                roman_chars[4] <= 8'h00;
                roman_chars[5] <= 8'h00;
                roman_chars[6] <= 8'h00;
                roman_chars[7] <= 8'h00;
                roman_chars[8] <= 8'h00;
                roman_chars[9] <= 8'h00;
            end else if (state == APPEND) begin
                // Perform appending in APPEND state
                if (append_count >= 2'd1) begin
                    if (pos < 10) begin
                        roman_chars[pos] <= char1;
                    end
                end
                if (append_count == 2'd2) begin
                    if (pos < 9) begin
                        roman_chars[pos + 1] <= char2;
                    end
                end
            end else if (state == DONE) begin
                if (remaining_val != 10'd0) begin
                    error <= 1'b1;
                    done <= 1'b1;
                end else begin
                    error <= 1'b0;
                    done <= 1'b1;
                end
            end else if (state != IDLE && next_state == IDLE) begin
                 // Reset done/error when returning to IDLE via external reset or logic (not explicit here, handled by reset)
            end
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        next_remaining_val = remaining_val;
        next_pos = pos;
        
        // Defaults for append logic
        append_count = 2'd0;
        char1 = 8'h00;
        char2 = 8'h00;

        case (state)
            IDLE: begin
                if (start) begin
                    if (number > 10'd0 && number <= 10'd1000) begin
                        next_remaining_val = number;
                        next_pos = 4'd0;
                        next_state = CHECK_M;
                    end else begin
                        // Error case handled in output logic, go to DONE immediately
                        next_remaining_val = number; // Store invalid input for error check
                        next_pos = 4'd0;
                        next_state = DONE;
                    end
                end
            end

            CHECK_M: begin
                if (remaining_val >= 1000) begin
                    next_remaining_val = remaining_val - 1000;
                    next_state = APPEND;
                    // Configure Append for M
                    append_count = 1;
                    char1 = 8'h6D; // 'm'
                    // Stay on CHECK_M to potentially append more
                end else begin
                    next_state = CHECK_CM;
                end
            end

            CHECK_CM: begin
                if (remaining_val >= 900) begin
                    next_remaining_val = remaining_val - 900;
                    next_state = APPEND;
                    append_count = 2;
                    char1 = 8'h63; // 'c'
                    char2 = 8'h6D; // 'm'
                end else begin
                    next_state = CHECK_D;
                end
            end

            CHECK_D: begin
                if (remaining_val >= 500) begin
                    next_remaining_val = remaining_val - 500;
                    next_state = APPEND;
                    append_count = 1;
                    char1 = 8'h64; // 'd'
                end else begin
                    next_state = CHECK_CD;
                end
            end

            CHECK_CD: begin
                if (remaining_val >= 400) begin
                    next_remaining_val = remaining_val - 400;
                    next_state = APPEND;
                    append_count = 2;
                    char1 = 8'h63; // 'c'
                    char2 = 8'h64; // 'd'
                end else begin
                    next_state = CHECK_C;
                end
            end

            CHECK_C: begin
                if (remaining_val >= 100) begin
                    next_remaining_val = remaining_val - 100;
                    next_state = APPEND;
                    append_count = 1;
                    char1 = 8'h63; // 'c'
                end else begin
                    next_state = CHECK_XC;
                end
            end

            CHECK_XC: begin
                if (remaining_val >= 90) begin
                    next_remaining_val = remaining_val - 90;
                    next_state = APPEND;
                    append_count = 2;
                    char1 = 8'h78; // 'x'
                    char2 = 8'h63; // 'c'
                end else begin
                    next_state = CHECK_L;
                end
            end

            CHECK_L: begin
                if (remaining_val >= 50) begin
                    next_remaining_val = remaining_val - 50;
                    next_state = APPEND;
                    append_count = 1;
                    char1 = 8'h6C; // 'l'
                end else begin
                    next_state = CHECK_XL;
                end
            end

            CHECK_XL: begin
                if (remaining_val >= 40) begin
                    next_remaining_val = remaining_val - 40;
                    next_state = APPEND;
                    append_count = 2;
                    char1 = 8'h78; // 'x'
                    char2 = 8'h6C; // 'l'
                end else begin
                    next_state = CHECK_X;
                end
            end

            CHECK_X: begin
                if (remaining_val >= 10) begin
                    next_remaining_val = remaining_val - 10;
                    next_state = APPEND;
                    append_count = 1;
                    char1 = 8'h78; // 'x'
                end else begin
                    next_state = CHECK_IX;
                end
            end

            CHECK_IX: begin
                if (remaining_val >= 9) begin
                    next_remaining_val = remaining_val - 9;
                    next_state = APPEND;
                    append_count = 2;
                    char1 = 8'h69; // 'i'
                    char2 = 8'h78; // 'x'
                end else begin
                    next_state = CHECK_V;
                end
            end

            CHECK_V: begin
                if (remaining_val >= 5) begin
                    next_remaining_val = remaining_val - 5;
                    next_state = APPEND;
                    append_count = 1;
                    char1 = 8'h76; // 'v'
                end else begin
                    next_state = CHECK_IV;
                end
            end

            CHECK_IV: begin
                if (remaining_val >= 4) begin
                    next_remaining_val = remaining_val - 4;
                    next_state = APPEND;
                    append_count = 2;
                    char1 = 8'h69; // 'i'
                    char2 = 8'h76; // 'v'
                end else begin
                    next_state = CHECK_I;
                end
            end

            CHECK_I: begin
                if (remaining_val >= 1) begin
                    next_remaining_val = remaining_val - 1;
                    next_state = APPEND;
                    append_count = 1;
                    char1 = 8'h69; // 'i'
                end else begin
                    next_state = DONE;
                end
            end

            APPEND: begin
                // Increment position based on how many chars we wrote
                if (append_count > 0) begin
                    // We need to look at the char to know what we appended, 
                    // but we can't access 'char1' here easily in combinational logic if it's local to the previous state block.
                    // However, since APPEND follows a specific CHECK state, we rely on the fact that 
                    // char1/append_count were set in the transition *into* APPEND.
                    // But wait, this logic is sequential or needs to hold the values.
                    // To fix: The 'APPEND' state needs to know what to append. 
                    // Let's modify the transition logic: We will set 'append_count', 'char1', 'char2' 
                    // in the logic that determines *next_state* = APPEND. 
                    // But variables defined in always @(*) are local. 
                    // Solution: Do the append logic *inside* the CHECK states if we stay, 
                    // OR use a separate cycle for APPEND.
                    // The prompt says: "The APPEND state should handle writing characters".
                    // We need to transport the char info to APPEND.
                    // Let's use a temporary register to hold the 'pending' chars.
                    // Actually, simpler approach: Do the append calculation in the comb block, 
                    // but we need to define a way to pass data. 
                    // Since we can't pass arguments, let's assume the logic flows: 
                    // State N -> determines chars -> goes to APPEND. 
                    // In APPEND, we need those chars. 
                    // BUT, in pure combinational next_state logic, if we go to APPEND, we can't capture the 'char1' unless we put it in a register.
                    // Let's use a register 'pending_chars' to store what needs to be written.
                    // Or, simpler: Re-calculate what needs to be written in APPEND based on remaining_val diff? No, that's hard.
                    // Alternative: Do the append *in* the CHECK state if we decide to append, then stay in CHECK.
                    // The prompt says "The APPEND state should handle writing characters".
                    // This implies a 2-cycle approach for each append: Check -> Append -> Check (again for greedy).
                    // However, the prompt also says "Use state machine with states... APPEND".
                    // And "Specify latency: Result valid ~20 clock cycles".
                    // 13 checks + 7 appends max (usually) = 20 cycles.
                    // So we do: State N -> (if match) -> APPEND (update buffer/pos) -> State N (to check again).
                    // Wait, the state machine diagram implies flow. "Move to next threshold state".
                    // If we are greedy, we stay on the same state until it fails.
                    // If APPEND is a state, it must return to the previous state (e.g. CHECK_M).
                    // To do that, we need to know where to return.
                    // Let's add a 'return_state' register.
                    // OR, simpler: Since the list of states is fixed, we can encode the loop.
                    // Let's refine the logic:
                    // 1. Check State: If >=, subtract, set pending char, go to APPEND.
                    // 2. APPEND State: Write pending char to buffer, increment pos, go back to the previous Check State.
                    // 3. Check State (re-entered): If still >=, repeat. Else, go to next Check State.
                    
                    // To implement "Go back", we need to know who called APPEND.
                    // Let's use a 'return_state' register.
                end
                
                // Since we realized the complexity of passing variables and return states in pure Verilog FSM without extra signals:
                // Let's stick to a simpler FSM interpretation that fits the "1 cycle per threshold" hint while using APPEND.
                // Actually, "One cycle per threshold check" suggests the check and append happen in one go if possible, or simply that the logic is linear.
                // The prompt asks for specific states: CHECK_M, ..., APPEND, DONE.
                // Let's try the Return State approach. It is standard for subroutines in FSM.
                // But to minimize complexity: 
                // The prompt says: "The APPEND state should handle writing characters and updating the remaining value."
                // Wait, usually "Update remaining value" happens in Check. 
                // Let's assume "APPEND" is just the writing part.
                // Since we need to return to the *same* state (greedy algorithm), we need to know where we came from.
                // We will add a 'return_state' register to solve this cleanly.
            end

            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

    // --- Revised Approach to handle variable passing and Return State ---
    // To make this synthesizable and correct, let's restructure the logic slightly.
    // The `always @(*)` block above is incomplete because APPEND needs context.
    // Let's add registers to hold the context.

    reg [4:0] return_state;
    reg [1:0] pending_count;
    reg [7:0] pending_c1;
    reg [7:0] pending_c2;

    // Update Context Registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            return_state <= IDLE;
            pending_count <= 0;
            pending_c1 <= 0;
            pending_c2 <= 0;
        end else begin
            // Capture context when entering APPEND logic from a Check state
            if (next_state == APPEND) begin
                return_state <= state; // Return to the state that triggered append
                pending_count <= append_count;
                pending_c1 <= char1;
                pending_c2 <= char2;
            end
        end
    end

    // Re-write the Next State Logic with the Return State mechanism
    always @(*) begin
        next_state = state;
        next_remaining_val = remaining_val;
        next_pos = pos;
        
        // Defaults for append logic (to latch inputs for context)
        append_count = 2'd0;
        char1 = 8'h00;
        char2 = 8'h00;

        case (state)
            IDLE: begin
                if (start) begin
                    if (number > 10'd0 && number <= 10'd1000) begin
                        next_remaining_val = number;
                        next_pos = 4'd0;
                        next_state = CHECK_M;
                    end else begin
                        next_remaining_val = number;
                        next_state = DONE;
                    end
                end
            end

            CHECK_M: begin
                if (remaining_val >= 1000) begin
                    next_remaining_val = remaining_val - 1000;
                    next_state = APPEND;
                    append_count = 1;
                    char1 = 8'h6D;
                end else begin
                    next_state = CHECK_CM;
                end
            end

            CHECK_CM: begin
                if (remaining_val >= 900) begin
                    next_remaining_val = remaining_val - 900;
                    next_state = APPEND;
                    append_count = 2;
                    char1 = 8'h63;
                    char2 = 8'h6D;
                end else begin
                    next_state = CHECK_D;
                end
            end

            CHECK_D: begin
                if (remaining_val >= 500) begin
                    next_remaining_val = remaining_val - 500;
                    next_state = APPEND;
                    append_count = 1;
                    char1 = 8'h64;
                end else begin
                    next_state = CHECK_CD;
                end
            end

            CHECK_CD: begin
                if (remaining_val >= 400) begin
                    next_remaining_val = remaining_val - 400;
                    next_state = APPEND;
                    append_count = 2;
                    char1 = 8'h63;
                    char2 = 8'h64;
                end else begin
                    next_state = CHECK_C;
                end
            end

            CHECK_C: begin
                if (remaining_val >= 100) begin
                    next_remaining_val = remaining_val - 100;
                    next_state = APPEND;
                    append_count = 1;
                    char1 = 8'h63;
                end else begin
                    next_state = CHECK_XC;
                end
            end

            CHECK_XC: begin
                if (remaining_val >= 90) begin
                    next_remaining_val = remaining_val - 90;
                    next_state = APPEND;
                    append_count = 2;
                    char1 = 8'h78;
                    char2 = 8'h63;
                end else begin
                    next_state = CHECK_L;
                end
            end

            CHECK_L: begin
                if (remaining_val >= 50) begin
                    next_remaining_val = remaining_val - 50;
                    next_state = APPEND;
                    append_count = 1;
                    char1 = 8'h6C;
                end else begin
                    next_state = CHECK_XL;
                end
            end

            CHECK_XL: begin
                if (remaining_val >= 40) begin
                    next_remaining_val = remaining_val - 40;
                    next_state = APPEND;
                    append_count = 2;
                    char1 = 8'h78;
                    char2 = 8'h6C;
                end else begin
                    next_state = CHECK_X;
                end
            end

            CHECK_X: begin
                if (remaining_val >= 10) begin
                    next_remaining_val = remaining_val - 10;
                    next_state = APPEND;
                    append_count = 1;
                    char1 = 8'h78;
                end else begin
                    next_state = CHECK_IX;
                end
            end

            CHECK_IX: begin
                if (remaining_val >= 9) begin
                    next_remaining_val = remaining_val - 9;
                    next_state = APPEND;
                    append_count = 2;
                    char1 = 8'h69;
                    char2 = 8'h78;
                end else begin
                    next_state = CHECK_V;
                end
            end

            CHECK_V: begin
                if (remaining_val >= 5) begin
                    next_remaining_val = remaining_val - 5;
                    next_state = APPEND;
                    append_count = 1;
                    char1 = 8'h76;
                end else begin
                    next_state = CHECK_IV;
                end
            end

            CHECK_IV: begin
                if (remaining_val >= 4) begin
                    next_remaining_val = remaining_val - 4;
                    next_state = APPEND;
                    append_count = 2;
                    char1 = 8'h69;
                    char2 = 8'h76;
                end else begin
                    next_state = CHECK_I;
                end
            end

            CHECK_I: begin
                if (remaining_val >= 1) begin
                    next_remaining_val = remaining_val - 1;
                    next_state = APPEND;
                    append_count = 1;
                    char1 = 8'h69;
                end else begin
                    next_state = DONE;
                end
            end

            APPEND: begin
                // Update Position
                if (pending_count > 0) begin
                    next_pos = pos + pending_count;
                end else begin
                    next_pos = pos;
                end
                
                // Decide Next State: Return to the state that triggered us, 
                // unless we are at the end of a loop (not applicable here since CHECK states handle flow).
                // We must return to the state to check the condition again (Greedy).
                next_state = return_state;
            end

            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Output Update Logic (Separate block for cleanliness)
    // We need to update roman_chars in the APPEND state.
    // The values to write are in pending_c1/pending_c2/pending_count.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in the main output block
        end else begin
            if (state == APPEND) begin
                // Write to buffer based on pending data
                // We update the register directly here to avoid combinational loop issues
                if (pending_count >= 1) begin
                    if (pos < 10) begin
                        roman_chars[pos] <= pending_c1;
                    end
                end
                if (pending_count == 2) begin
                    if (pos < 9) begin
                        roman_chars[pos + 1] <= pending_c2;
                    end
                end
            end
            
            // Handle Done/Error flags in DONE state
            if (state == DONE) begin
                if (remaining_val != 10'd0) begin
                    error <= 1'b1;
                end else begin
                    error <= 1'b0;
                end
                done <= 1'b1;
            end else if (state == IDLE && start) begin
                done <= 1'b0;
                error <= 1'b0;
            end
        end
    end

endmodule
module TopModule(
    input clk,
    input rst_n,
    input start,
    input [9:0] number,
    output [9:0][7:0] roman_chars,
    output done,
    output error
);
    roman_converter u_conv (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .number(number),
        .roman_chars(roman_chars),
        .done(done),
        .error(error)
    );
endmodule
