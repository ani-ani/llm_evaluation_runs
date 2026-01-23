module kth_sequence(
    input clk,
    input rst_n,
    input start,
    input [31:0] k,
    output reg [3:0] result,
    output reg valid,
    output reg done
);

// Parameters for sequence length and alphabet size
localparam N = 5;
localparam LEN = 4; // N - 1
localparam MAX_VAL = 4; // N - 1
localparam MAX_SEQ = 256; // 4^4 = 256, but we generate sequentially

// State definitions
localparam IDLE = 3'b001;
localparam COUNTING = 3'b010;
localparam CHECKING = 3'b100;

reg [2:0] state, next_state;

// Sequence generation registers (flattened 4-element array)
reg [3:0] seq_0, seq_1, seq_2, seq_3;
reg [3:0] next_seq_0, next_seq_1, next_seq_2, next_seq_3;

// Counter for valid sequences found
reg [31:0] valid_count;

// Checking logic registers
reg [2:0] check_len; // Length of subarray (1 to 4)
reg [1:0] check_idx; // Start index of subarray
reg [5:0] current_sum; // Sum accumulator (max 4*4=16, 6 bits)
reg check_fail; // Flag if any sum is divisible by 5
reg [2:0] check_state; // Sub-state for checking phases

// Output stream control
reg [1:0] out_idx;

// Next State Logic
always @(*) begin
    case (state)
        IDLE: begin
            if (start)
                next_state = COUNTING;
            else
                next_state = IDLE;
        end
        COUNTING: begin
            // Generate next sequence lexicographically
            // If we have reached max sequence (4,4,4,4) and checked it
            if (seq_0 == MAX_VAL && seq_1 == MAX_VAL && seq_2 == MAX_VAL && seq_3 == MAX_VAL && check_state == 3'b111) begin
                 next_state = OUTPUT; // Fall through or wait, we need to handle done
                 // Actually, if we finished checking the last sequence and didn't find k
                 // but requirements say k up to ~10000, but total valid is likely less than 256.
                 // If k > valid_count, done stays high? Assuming valid k.
            end else begin
                next_state = CHECKING;
            end
        end
        CHECKING: begin
            // Check logic
            // Check specific subarray state machine or single cycle check? 
            // Let's use a micro-coded check inside CHECKING state to keep latency manageable.
            // If check passes, increment valid_count. If valid_count == k, go to OUTPUT.
            // If check fails, go to NEXT_SEQ (which is part of COUNTING logic or implicit).
            
            // We will use check_state to manage the verification steps
            // check_state 0: Init sum
            // check_state 1: Accumulate
            // check_state 2: Check Mod
            // check_state 3: Next Subarray
            // check_state 4: Done with all checks (Pass)
            // check_state 5: Fail
            
            if (check_state == 3'b100) begin // Pass
                if (valid_count + 1 == k) begin
                    next_state = OUTPUT;
                end else begin
                    next_state = COUNTING; // Generate next sequence
                end
            end else if (check_state == 3'b101) begin // Fail
                next_state = COUNTING; // Generate next sequence
            end else begin
                next_state = CHECKING; // Continue checking
            end
        end
        OUTPUT: begin
            if (out_idx == 2'b11) begin
                next_state = IDLE;
            end else begin
                next_state = OUTPUT;
            end
        end
        default: next_state = IDLE;
    endcase
end

// State Register
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

// Sequence Generation Logic (Nested Loops simulation)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        seq_0 <= 1;
        seq_1 <= 1;
        seq_2 <= 1;
        seq_3 <= 1;
    end else if (state == COUNTING && next_state == CHECKING) begin
        // Increment sequence logic (Simulating nested loops: 3, 2, 1, 0)
        if (seq_3 < MAX_VAL) begin
            seq_3 <= seq_3 + 1;
        end else begin
            seq_3 <= 1;
            if (seq_2 < MAX_VAL) begin
                seq_2 <= seq_2 + 1;
            end else begin
                seq_2 <= 1;
                if (seq_1 < MAX_VAL) begin
                    seq_1 <= seq_1 + 1;
                end else begin
                    seq_1 <= 1;
                    if (seq_0 < MAX_VAL) begin
                        seq_0 <= seq_0 + 1;
                    end else begin
                        // This is the last sequence (4,4,4,4), stay there
                        seq_0 <= seq_0;
                    end
                end
            end
        end
    end else if (state == CHECKING && next_state == COUNTING && check_state == 3'b101) begin
         // If check failed, we still need to increment sequence from the current state
         // (Redundant logic handled by above block if we latch, but simpler to repeat)
         // Actually, the logic above triggers on state transition from COUNTING->CHECKING.
         // If we stay in CHECKING, we need to handle the increment on failure.
         // Let's move sequence increment to the transition out of CHECKING on failure.
         
         // Correction: The sequence increment logic should happen when we move from CHECKING back to COUNTING on failure,
         // or from IDLE to COUNTING.
         
         // Let's redefine the increment trigger: Trigger when next_state == CHECKING.
         // But on failure, we go CHECKING -> COUNTING. We need to increment then.
         // Let's create a separate flag.
         
         if (seq_3 < MAX_VAL) begin
            seq_3 <= seq_3 + 1;
        end else begin
            seq_3 <= 1;
            if (seq_2 < MAX_VAL) begin
                seq_2 <= seq_2 + 1;
            end else begin
                seq_2 <= 1;
                if (seq_1 < MAX_VAL) begin
                    seq_1 <= seq_1 + 1;
                end else begin
                    seq_1 <= 1;
                    if (seq_0 < MAX_VAL) begin
                        seq_0 <= seq_0 + 1;
                    end else begin
                        seq_0 <= seq_0;
                    end
                end
            end
        end
    end else if (state == IDLE && start) begin
        seq_0 <= 1; seq_1 <= 1; seq_2 <= 1; seq_3 <= 1;
    end
end

// Check Logic State Machine (runs inside CHECKING state)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        check_state <= 3'b000;
        check_fail <= 0;
        valid_count <= 0;
    end else begin
        case (check_state)
            3'b000: begin // Initialize check loop
                if (state == CHECKING) begin
                    check_len <= 1;
                    check_idx <= 0;
                    check_fail <= 0;
                    // Start calculation for len 1, idx 0
                    // Subarray [0:0]
                    current_sum <= seq_0;
                    check_state <= 3'b001; 
                end
            end
            3'b001: begin // Calculate Sum
                if (check_len == 1) begin
                     current_sum <= (check_idx == 0) ? seq_0 : 
                                    (check_idx == 1) ? seq_1 : 
                                    (check_idx == 2) ? seq_2 : seq_3;
                end else if (check_len == 2) begin
                     current_sum <= (check_idx == 0) ? seq_0 + seq_1 : 
                                    (check_idx == 1) ? seq_1 + seq_2 : seq_2 + seq_3;
                end else if (check_len == 3) begin
                     current_sum <= (check_idx == 0) ? seq_0 + seq_1 + seq_2 : seq_1 + seq_2 + seq_3;
                end else if (check_len == 4) begin
                     current_sum <= seq_0 + seq_1 + seq_2 + seq_3;
                end
                check_state <= 3'b010;
            end
            3'b010: begin // Check Modulo
                if (current_sum % 5 == 0) begin
                    check_fail <= 1;
                    check_state <= 3'b101; // Fail
                end else begin
                    // Next subarray configuration
                    if (check_len < 4) begin
                        if (check_idx < 4 - check_len) begin
                            check_idx <= check_idx + 1;
                            check_state <= 3'b001; // Recalc sum for same length, next index
                        end else begin
                            check_len <= check_len + 1;
                            check_idx <= 0;
                            if (check_len + 1 <= 4) check_state <= 3'b001; // Next length
                            else check_state <= 3'b100; // Done (Pass)
                        end
                    end else begin
                        // check_len == 4, just checked idx 0
                        check_state <= 3'b100; // Pass
                    end
                end
            end
            3'b100: begin // Pass
                valid_count <= valid_count + 1;
                check_state <= 3'b000; // Reset for next sequence
            end
            3'b101: begin // Fail
                check_state <= 3'b000; // Reset for next sequence
            end
            default: check_state <= 3'b000;
        endcase
        
        // If leaving CHECKING state to IDLE (done), reset check_state
        if (next_state == IDLE) check_state <= 3'b000;
        // If entering COUNTING from elsewhere, reset check_state
        if (state != CHECKING && next_state == COUNTING) check_state <= 3'b000;
    end
end

// Better Logic for Sequence Increment to avoid conflict
// We need to increment sequence when check fails OR when check passes but not the target
// Let's make a dedicated increment signal
reg inc_seq;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Init handled in state logic
    end else begin
        if (inc_seq) begin
            if (seq_3 < MAX_VAL) begin
                seq_3 <= seq_3 + 1;
            end else begin
                seq_3 <= 1;
                if (seq_2 < MAX_VAL) begin
                    seq_2 <= seq_2 + 1;
                end else begin
                    seq_2 <= 1;
                    if (seq_1 < MAX_VAL) begin
                        seq_1 <= seq_1 + 1;
                    end else begin
                        seq_1 <= 1;
                        if (seq_0 < MAX_VAL) begin
                            seq_0 <= seq_0 + 1;
                        end
                    end
                end
            end
        end else if (state == IDLE && start) begin
            seq_0 <= 1; seq_1 <= 1; seq_2 <= 1; seq_3 <= 1;
        end
    end
end

always @(*) begin
    inc_seq = 0;
    if (state == CHECKING && next_state == COUNTING) begin
        // From Check to Count (Fail or Pass but not target)
        inc_seq = 1;
    end
end

// Output Logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        result <= 0;
        valid <= 0;
        done <= 0;
        out_idx <= 0;
    end else begin
        if (state == OUTPUT) begin
            valid <= 1;
            done <= 0;
            case (out_idx)
                2'b00: result <= seq_0;
                2'b01: result <= seq_1;
                2'b10: result <= seq_2;
                2'b11: begin
                    result <= seq_3;
                    done <= 1;
                end
            endcase
            if (out_idx < 2'b11) out_idx <= out_idx + 1;
        end else begin
            valid <= 0;
            if (state == IDLE) begin
                done <= 0;
                out_idx <= 0;
            end
        end
    end
end

endmodule