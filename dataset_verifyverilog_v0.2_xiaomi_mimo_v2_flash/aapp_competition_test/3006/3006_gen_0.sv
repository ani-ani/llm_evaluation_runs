module dna_program_comparator (
    input clk,
    input rst_n,
    input start,
    input [7:0] op_type,
    input [15:0] op_pos,
    input [7:0] op_char,
    input program_sel,
    output reg result,
    output reg done,
    output reg error
);

    // State Encoding
    localparam IDLE      = 4'b0000;
    localparam READ_OPS1 = 4'b0001;
    localparam READ_OPS2 = 4'b0010;
    localparam SIMPLIFY1 = 4'b0011;
    localparam SIMPLIFY2 = 4'b0100;
    localparam COMPARE   = 4'b0101;
    localparam DONE      = 4'b0110;
    localparam ERROR     = 4'b0111;

    // Operation Type Encoding
    localparam OP_NONE = 8'h00;
    localparam OP_INS  = 8'h01;
    localparam OP_DEL  = 8'h02;
    localparam OP_END  = 8'h03;

    // Registers for State Machine
    reg [3:0] current_state, next_state;

    // Buffer Pointers and Counters
    reg [2:0] ptr; // Generic pointer for reading/writing/compare index
    reg [2:0] count_p1; // Number of ops in program 1 buffer (after read)
    reg [2:0] count_p2; // Number of ops in program 2 buffer (after read)
    reg [2:0] count_s1; // Number of ops in program 1 simplified buffer
    reg [2:0] count_s2; // Number of ops in program 2 simplified buffer

    // Temp buffer for current read operation
    reg [7:0] curr_type;
    reg [15:0] curr_pos;
    reg [7:0] curr_char;
    reg        curr_valid;

    // Program 1 Raw Storage
    reg [7:0]  p1_type [0:7];
    reg [15:0] p1_pos  [0:7];
    reg [7:0]  p1_char [0:7];

    // Program 2 Raw Storage
    reg [7:0]  p2_type [0:7];
    reg [15:0] p2_pos  [0:7];
    reg [7:0]  p2_char [0:7];

    // Program 1 Simplified Storage
    reg [7:0]  s1_type [0:7];
    reg [15:0] s1_pos  [0:7];
    reg [7:0]  s1_char [0:7];

    // Program 2 Simplified Storage
    reg [7:0]  s2_type [0:7];
    reg [15:0] s2_pos  [0:7];
    reg [7:0]  s2_char [0:7];

    // Helper logic for top of simplified buffer
    wire [7:0]  s1_top_type = s1_type[ptr - 3'd1]; // Assuming ptr points to next empty slot or current read
    wire [15:0] s1_top_pos  = s1_pos[ptr - 3'd1];
    wire [7:0]  s2_top_type = s2_type[ptr - 3'd1];
    wire [15:0] s2_top_pos  = s2_pos[ptr - 3'd1];

    // Next State Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // State Transition and Datapath Control
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = READ_OPS1;
            end
            
            READ_OPS1: begin
                if (curr_valid && op_type == OP_END) next_state = READ_OPS2;
                else if (error) next_state = ERROR;
                // Stay here until end of P1
            end

            READ_OPS2: begin
                if (curr_valid && op_type == OP_END) next_state = SIMPLIFY1;
                else if (error) next_state = ERROR;
                // Stay here until end of P2
            end

            SIMPLIFY1: begin
                // If we processed all raw ops, move to SIMPLIFY2
                if (ptr >= count_p1) next_state = SIMPLIFY2;
            end

            SIMPLIFY2: begin
                // If we processed all raw ops, move to COMPARE
                if (ptr >= count_p2) next_state = COMPARE;
            end

            COMPARE: begin
                // If comparison is done (either mismatch found or all matched)
                // We transition to DONE in the combinational block or sequential block
                // To ensure result is stable, we can transition to DONE on next clock
                if (ptr >= count_s1 || ptr >= count_s2 || result) next_state = DONE;
                else if (ptr < count_s1 && ptr < count_s2) begin
                     // Check mismatch
                     if (s1_type[ptr] != s2_type[ptr] || 
                         s1_pos[ptr] != s2_pos[ptr] || 
                         s1_char[ptr] != s2_char[ptr])
                         next_state = DONE;
                end else if (count_s1 != count_s2) begin
                    next_state = DONE;
                end else begin
                    next_state = DONE;
                end
            end

            DONE: begin
                // Stay in DONE until reset or start
                if (start) next_state = READ_OPS1;
            end

            ERROR: begin
                // Stay in ERROR until reset
            end

            default: next_state = IDLE;
        endcase
    end

    // Datapath Operations (Sequencing)
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset Registers
            result <= 0;
            done <= 0;
            error <= 0;
            ptr <= 0;
            count_p1 <= 0;
            count_p2 <= 0;
            count_s1 <= 0;
            count_s2 <= 0;
            curr_valid <= 0;
            // Explicitly reset array content is not synthesizable usually, 
            // but we rely on valid signals and state logic.
        end else begin
            // Default pulse signals (if any) reset here or handled by state
            // Capture Input if valid during specific states (except END)
            curr_valid <= 0;

            case (next_state)
                IDLE: begin
                    result <= 0;
                    done <= 0;
                    error <= 0;
                    ptr <= 0;
                    count_p1 <= 0;
                    count_p2 <= 0;
                    count_s1 <= 0;
                    count_s2 <= 0;
                end

                READ_OPS1: begin
                    // Sample input if it's not End
                    if (program_sel == 1'b0 && op_type != OP_NONE) begin
                        if (op_type == OP_END) begin
                            // Mark end of read
                            count_p1 <= ptr;
                            ptr <= 0; // Reset ptr for next phase
                            curr_valid <= 1; // Signal transition
                        end else if (ptr < 8) begin
                            // Store raw operation
                            p1_type[ptr] <= op_type;
                            p1_pos[ptr] <= op_pos;
                            p1_char[ptr] <= op_char;
                            ptr <= ptr + 1;
                            curr_valid <= 0; // Stay in state
                        end else begin
                            // Buffer overflow
                            error <= 1;
                        end
                    end
                end

                READ_OPS2: begin
                    // Sample input
                    if (program_sel == 1'b1 && op_type != OP_NONE) begin
                        if (op_type == OP_END) begin
                            count_p2 <= ptr;
                            ptr <= 0;
                            curr_valid <= 1;
                        end else if (ptr < 8) begin
                            p2_type[ptr] <= op_type;
                            p2_pos[ptr] <= op_pos;
                            p2_char[ptr] <= op_char;
                            ptr <= ptr + 1;
                            curr_valid <= 0;
                        end else begin
                            error <= 1;
                        end
                    end
                end

                SIMPLIFY1: begin
                    // Logic: Iterate through p1_raw (index = ptr), add to s1 buffer (index = count_s1)
                    // Using a 2-cycle approach per operation to handle cancellation check against previous s1
                    // Cycle 1: Load current raw op
                    // Cycle 2: Logic to push to s1
                    
                    // Simplification logic is complex. 
                    // Let's do one step per clock for simplicity and correctness.
                    
                    if (ptr < count_p1) begin
                        // Current raw op is p1_type[ptr] etc.
                        // Previous simplified op is s1_type[count_s1-1]
                        
                        // Check Cancellation (Ins p, Del p)
                        // Check Shift (Del q > p -> Del q-1)
                        
                        // If count_s1 == 0, just push
                        if (count_s1 == 0) begin
                            s1_type[count_s1] <= p1_type[ptr];
                            s1_pos[count_s1] <= p1_pos[ptr];
                            s1_char[count_s1] <= p1_char[ptr];
                            count_s1 <= count_s1 + 1;
                            ptr <= ptr + 1;
                        end else begin
                            // Check against last simplified op
                            // s1_top is at index count_s1 - 1
                            
                            // Rule 1: Ins(p, c) followed by Del(p) -> Cancel
                            if (s1_type[count_s1-1] == OP_INS && p1_type[ptr] == OP_DEL && 
                                s1_pos[count_s1-1] == p1_pos[ptr]) begin
                                // Remove top of s1 (decrement count_s1) and consume raw (increment ptr)
                                count_s1 <= count_s1 - 1;
                                ptr <= ptr + 1;
                            end
                            // Rule 2: Del(p) followed by Del(q) where q > p -> second becomes Del(q-1)
                            else if (s1_type[count_s1-1] == OP_DEL && p1_type[ptr] == OP_DEL) begin
                                if (p1_pos[ptr] > s1_pos[count_s1-1]) begin
                                    // Shift position down by 1
                                    s1_type[count_s1] <= OP_DEL;
                                    s1_pos[count_s1] <= p1_pos[ptr] - 1;
                                    s1_char[count_s1] <= 0;
                                    count_s1 <= count_s1 + 1;
                                    ptr <= ptr + 1;
                                end else begin
                                    // No shift rule specified for q < p or q == p? 
                                    // Standard logic: Del(q) after Del(p), positions unaffected if q != p.
                                    // Assuming strict rule application only for q > p.
                                    s1_type[count_s1] <= p1_type[ptr];
                                    s1_pos[count_s1] <= p1_pos[ptr];
                                    s1_char[count_s1] <= p1_char[ptr];
                                    count_s1 <= count_s1 + 1;
                                    ptr <= ptr + 1;
                                end
                            end
                            // Rule 3: Ins(p, c) followed by Ins(q, d) -> Both remain (position logic not fully specified to shift, 
                            // but prompt says "positions may shift", usually implying if q > p. 
                            // However, pure Insertions usually don't shift each other unless positions overlap. 
                            // We will assume standard append logic unless specific rule applies).
                            // Prompt says: "For Ins(p, c) followed by Ins(q, d) where q > p: both remain but positions may shift".
                            // Wait, if q > p, it's already later. If we are appending, positions don't shift relative to the op.
                            // If the prompt means 'p' relative to the buffer index, it's unclear. 
                            // Let's stick to the literal instruction:
                            // 'both remain' implies we just add it.
                            // 'positions may shift' is vague. We will ignore shift for ins-ins unless we interpret it as p > q (insert earlier).
                            // If p > q (insert earlier in genome), subsequent inserts shift. But q > p means later. 
                            // Let's treat it as: Add operation as is.
                            else begin
                                s1_type[count_s1] <= p1_type[ptr];
                                s1_pos[count_s1] <= p1_pos[ptr];
                                s1_char[count_s1] <= p1_char[ptr];
                                count_s1 <= count_s1 + 1;
                                ptr <= ptr + 1;
                            end
                        end
                    end
                end

                SIMPLIFY2: begin
                    // Same logic for Program 2
                    if (ptr < count_p2) begin
                        if (count_s2 == 0) begin
                            s2_type[count_s2] <= p2_type[ptr];
                            s2_pos[count_s2] <= p2_pos[ptr];
                            s2_char[count_s2] <= p2_char[ptr];
                            count_s2 <= count_s2 + 1;
                            ptr <= ptr + 1;
                        end else begin
                            // Check Cancellation
                            if (s2_type[count_s2-1] == OP_INS && p2_type[ptr] == OP_DEL && 
                                s2_pos[count_s2-1] == p2_pos[ptr]) begin
                                count_s2 <= count_s2 - 1;
                                ptr <= ptr + 1;
                            end
                            // Check Del Shift
                            else if (s2_type[count_s2-1] == OP_DEL && p2_type[ptr] == OP_DEL) begin
                                if (p2_pos[ptr] > s2_pos[count_s2-1]) begin
                                    s2_type[count_s2] <= OP_DEL;
                                    s2_pos[count_s2] <= p2_pos[ptr] - 1;
                                    s2_char[count_s2] <= 0;
                                    count_s2 <= count_s2 + 1;
                                    ptr <= ptr + 1;
                                end else begin
                                    s2_type[count_s2] <= p2_type[ptr];
                                    s2_pos[count_s2] <= p2_pos[ptr];
                                    s2_char[count_s2] <= p2_char[ptr];
                                    count_s2 <= count_s2 + 1;
                                    ptr <= ptr + 1;
                                end
                            end
                            else begin
                                s2_type[count_s2] <= p2_type[ptr];
                                s2_pos[count_s2] <= p2_pos[ptr];
                                s2_char[count_s2] <= p2_char[ptr];
                                count_s2 <= count_s2 + 1;
                                ptr <= ptr + 1;
                            end
                        end
                    end
                end

                COMPARE: begin
                    // Compare logic (Combinational in Next State, but we can set result here)
                    // Actually, better to do comparisons in combinational block to drive next_state,
                    // and latch result here.
                    
                    // Let's do the check here and set result/done flags if mismatch or end
                    if (ptr < count_s1 && ptr < count_s2) begin
                        if (s1_type[ptr] != s2_type[ptr] || 
                            s1_pos[ptr] != s2_pos[ptr] || 
                            s1_char[ptr] != s2_char[ptr]) begin
                            result <= 1; // Different
                            // next_state handles transition to DONE
                        end else begin
                            ptr <= ptr + 1; // Match, move next
                            result <= 0;
                        end
                    end else if (count_s1 != count_s2) begin
                        result <= 1; // Different length
                    end else if (ptr >= count_s1 && ptr >= count_s2) begin
                        // End of both, counts equal, all matched so far (result should be 0)
                        result <= 0;
                    end
                end

                DONE: begin
                    done <= 1;
                end

                ERROR: begin
                    error <= 1;
                end
            endcase
        end
    end

endmodule
