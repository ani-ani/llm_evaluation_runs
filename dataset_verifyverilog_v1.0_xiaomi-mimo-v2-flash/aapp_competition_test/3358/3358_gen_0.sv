module sum_binary (
    input clk,
    input rst_n,
    input start,
    input [7:0] n_in,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] FETCH       = 4'd1;
    localparam [3:0] EXEC_ST     = 4'd2;
    localparam [3:0] EXEC_ZE     = 4'd3;
    localparam [3:0] EXEC_PH     = 4'd4;
    localparam [3:0] EXEC_PL     = 4'd5;
    localparam [3:0] EXEC_AD     = 4'd6;
    localparam [3:0] EXEC_DI     = 4'd7;
    localparam [3:0] WAIT_START  = 4'd8;
    localparam [3:0] PREPARE     = 4'd9;
    localparam [3:0] CHECK_N     = 4'd10;
    localparam [3:0] SHIFT_N     = 4'd11;
    localparam [3:0] DONE_STATE  = 4'd12;

    // Internal registers
    reg [3:0] state, next_state;
    reg [3:0] prev_state;
    reg [7:0] counter;
    localparam [7:0] MAX_CYCLES = 8'd128;
    
    // Datapath registers
    reg [7:0] A_reg, X_reg, Y_reg;
    
    // Stack implementation (16x8)
    reg [7:0] stack [0:15];  // 16 entries of 8 bits
    reg [3:0] sp;  // Stack pointer
    
    // ALU signals
    reg [7:0] alu_op1, alu_op2;
    wire [7:0] alu_result;
    assign alu_result = alu_op1 + alu_op2;
    
    // Instruction decoder state
    reg [7:0] n_reg;  // Copy of n_in
    reg [2:0] bit_index;  // Tracks which bit we're processing
    reg [7:0] shift_count;  // For tracking shift operations
    reg [1:0] op_phase;  // Phase within operation
    reg [7:0] temp_val;  // Temporary storage
    
    // Program counter for instruction execution
    reg [5:0] instr_pc;  // Instruction counter
    
    // Signal to detect when instruction sequence is complete
    reg [7:0] done_counter;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            counter <= 8'd0;
            
            // Initialize registers
            A_reg <= 8'd0;
            X_reg <= 8'd0;
            Y_reg <= 8'd0;
            sp <= 4'd0;
            n_reg <= 8'd0;
            bit_index <= 3'd0;
            shift_count <= 8'd0;
            op_phase <= 2'd0;
            temp_val <= 8'd0;
            instr_pc <= 6'd0;
            done_counter <= 8'd0;
            prev_state <= IDLE;
            
            // Initialize stack memory
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                stack[i] <= 8'd0;
            end
        end else begin
            // Counter to prevent infinite loops
            if (state != IDLE) begin
                if (counter < MAX_CYCLES) begin
                    counter <= counter + 8'd1;
                end
            end else begin
                counter <= 8'd0;
            end
            
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    A_reg <= 8'd0;
                    X_reg <= 8'd0;
                    Y_reg <= 8'd0;
                    sp <= 4'd0;
                    counter <= 8'd0;
                    instr_pc <= 6'd0;
                    bit_index <= 3'd0;
                    op_phase <= 2'd0;
                    shift_count <= 8'd0;
                    temp_val <= 8'd0;
                    done_counter <= 8'd0;
                    // Clear stack
                    integer k;
                    for (k = 0; k < 16; k = k + 1) begin
                        stack[k] <= 8'd0;
                    end
                end
                
                WAIT_START: begin
                    done <= 1'b0;
                end
                
                PREPARE: begin
                    // Copy n_in to internal register
                    n_reg <= n_in;
                    bit_index <= 3'd0;
                    sp <= 4'd0;  // Clear stack
                    A_reg <= 8'd0;
                    X_reg <= 8'd0;
                    Y_reg <= 8'd0;
                    instr_pc <= 6'd0;
                end
                
                CHECK_N: begin
                    // Check if we've processed all 8 bits
                    if (bit_index > 3'd7) begin
                        // Done with bit processing
                        if (sp > 4'd0) begin
                            // Need to sum remaining items
                            op_phase <= 2'd0;
                        end else begin
                            // Nothing to sum, result is 0 or handled
                            // If n_in was 0, we need to handle that
                            if (n_in == 8'd0) begin
                                A_reg <= 8'd0;
                            end
                        end
                    end
                end
                
                SHIFT_N: begin
                    // Check current bit (LSB)
                    if (n_reg[0] == 1'b1) begin
                        // Bit is set, need to handle it
                        if (bit_index == 3'd0) begin
                            // First set bit, just push 1 (ST A, PH A)
                            A_reg <= 8'd1;
                        end else begin
                            // For subsequent bits, need to handle
                            // Will push appropriate power of 2
                            A_reg <= 8'd1;
                        end
                    end
                    // Shift n_reg right by 1
                    n_reg <= {1'b0, n_reg[7:1]};
                    bit_index <= bit_index + 3'd1;
                end
                
                EXEC_ST: begin
                    // ST instruction: Set register to 1
                    case (op_phase)
                        2'd0: begin
                            A_reg <= 8'd1;
                            op_phase <= 2'd1;
                        end
                        2'd1: begin
                            // Done with ST
                            op_phase <= 2'd0;
                        end
                        default: op_phase <= 2'd0;
                    endcase
                end
                
                EXEC_ZE: begin
                    // ZE instruction: Set register to 0
                    case (op_phase)
                        2'd0: begin
                            A_reg <= 8'd0;
                            op_phase <= 2'd1;
                        end
                        2'd1: begin
                            // Done with ZE
                            op_phase <= 2'd0;
                        end
                        default: op_phase <= 2'd0;
                    endcase
                end
                
                EXEC_PH: begin
                    // PH instruction: Push register to stack
                    case (op_phase)
                        2'd0: begin
                            if (sp < 4'd15) begin
                                // Push value of A to stack
                                stack[sp] <= A_reg;
                                sp <= sp + 4'd1;
                                op_phase <= 2'd1;
                            end
                        end
                        2'd1: begin
                            // Done with PH
                            op_phase <= 2'd0;
                        end
                        default: op_phase <= 2'd0;
                    endcase
                end
                
                EXEC_PL: begin
                    // PL instruction: Pop stack to register
                    case (op_phase)
                        2'd0: begin
                            if (sp > 4'd0) begin
                                sp <= sp - 4'd1;
                                A_reg <= stack[sp - 4'd1];
                                op_phase <= 2'd1;
                            end
                        end
                        2'd1: begin
                            // Done with PL
                            op_phase <= 2'd0;
                        end
                        default: op_phase <= 2'd0;
                    endcase
                end
                
                EXEC_AD: begin
                    // AD instruction: Pop two, add, push result
                    case (op_phase)
                        2'd0: begin
                            if (sp >= 4'd2) begin
                                // Pop first operand to A_reg
                                sp <= sp - 4'd1;
                                A_reg <= stack[sp - 4'd1];
                                temp_val <= stack[sp - 4'd2];
                                op_phase <= 2'd1;
                            end
                        end
                        2'd1: begin
                            // Pop second operand and compute
                            sp <= sp - 4'd1;
                            // Add (mod 256)
                            A_reg <= A_reg + temp_val;
                            op_phase <= 2'd2;
                        end
                        2'd2: begin
                            // Push result
                            if (sp < 4'd15) begin
                                stack[sp] <= A_reg;
                                sp <= sp + 4'd1;
                                op_phase <= 2'd3;
                            end
                        end
                        2'd3: begin
                            // Done with AD
                            op_phase <= 2'd0;
                        end
                        default: op_phase <= 2'd0;
                    endcase
                end
                
                EXEC_DI: begin
                    // DI instruction: Latch result and assert done
                    case (op_phase)
                        2'd0: begin
                            result <= A_reg;
                            done <= 1'b1;
                            op_phase <= 2'd1;
                            done_counter <= 8'd0;
                        end
                        2'd1: begin
                            // Hold done for one cycle
                            if (done_counter >= 8'd0) begin
                                done <= 1'b0;
                                op_phase <= 2'd2;
                            end
                        end
                        2'd2: begin
                            op_phase <= 2'd0;
                        end
                        default: op_phase <= 2'd0;
                    endcase
                end
                
                FETCH: begin
                    // Not used in this implementation
                end
                
                DONE_STATE: begin
                    done <= 1'b0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                next_state = WAIT_START;
            end
            
            WAIT_START: begin
                if (start) begin
                    next_state = PREPARE;
                end else begin
                    next_state = WAIT_START;
                end
            end
            
            PREPARE: begin
                next_state = CHECK_N;
            end
            
            CHECK_N: begin
                if (bit_index > 3'd7) begin
                    // All bits processed, check if we need to sum
                    if (sp > 4'd1) begin
                        // Multiple values on stack, need to sum them
                        next_state = EXEC_AD;
                    end else if (sp == 4'd1) begin
                        // Only one value, pop it to A
                        next_state = EXEC_PL;
                    end else begin
                        // Empty stack (n_in was 0)
                        next_state = EXEC_DI;
                    end
                end else begin
                    next_state = SHIFT_N;
                end
            end
            
            SHIFT_N: begin
                // Process current bit
                if (n_reg[0] == 1'b1) begin
                    // Bit set, need to add power of 2
                    if (bit_index == 3'd0) begin
                        // First set bit, just set A=1 then push
                        next_state = EXEC_ST;
                    end else begin
                        // Subsequent set bit
                        // We need to multiply previous result by 2 (left shift)
                        // Implementation: PH A, PH A, AD, PL A (multiply by 2)
                        // But we also need to add 1 if this is the MSB of the decomposition
                        // Actually, for binary decomposition:
                        // For bit i, we need to add 2^i
                        // If we have previous sum S, new sum = S + 2^i
                        // But we need 2^i on stack
                        next_state = EXEC_ST;  // Set A=1
                    end
                end else begin
                    // Bit not set, just shift and continue
                    if (bit_index < 3'd7) begin
                        next_state = CHECK_N;  // Continue checking next bit
                    end else begin
                        next_state = CHECK_N;  // Done
                    end
                end
            end
            
            EXEC_ST: begin
                if (op_phase == 2'd1) begin
                    // ST done, need to PH
                    next_state = EXEC_PH;
                end else begin
                    next_state = EXEC_ST;
                end
            end
            
            EXEC_PH: begin
                if (op_phase == 2'd1) begin
                    // PH done
                    if (bit_index > 3'd0) begin
                        // For bits after first, we need to add this power of 2 to existing sum
                        // Actually, this algorithm is getting complex.
                        // Let's simplify:
                        // For each set bit i (starting from LSB):
                        //   If first set bit: ST A, PH A
                        //   Else: We need to push 2^i, then AD with existing sum
                        // For bit i > 0: 2^i = 1 shifted left i times
                        // But we can compute 2^i by starting with 1 and shifting
                        // Let's track which bit we're on
                        if (bit_index == 3'd1) begin
                            // Second set bit, need to create 2^1 = 2
                            // We have 1 in A, need to PH it, then PH it again, AD (gives 2), PH it
                            // Or simpler: we keep a running power value
                            // Actually, let's redesign the approach
                            // We'll compute 2^i and push it
                            // For i=1: push 2 (1+1)
                            next_state = EXEC_ST;  // Push another 1
                        end else begin
                            // For i >= 2: need to compute 2^i
                            // We'll use a different approach
                            next_state = EXEC_AD;  // Add to get next power of 2
                        end
                    end else begin
                        // First bit, done with PH
                        next_state = CHECK_N;
                    end
                end else begin
                    next_state = EXEC_PH;
                end
            end
            
            EXEC_PL: begin
                if (op_phase == 2'd1) begin
                    // PL done
                    next_state = EXEC_DI;
                end else begin
                    next_state = EXEC_PL;
                end
            end
            
            EXEC_AD: begin
                if (op_phase == 2'd3) begin
                    // AD done
                    // Check if we need to do more additions
                    if (sp > 4'd1) begin
                        // Still have multiple items, continue adding
                        next_state = EXEC_AD;
                    end else if (sp == 4'd1) begin
                        // One item left, pop it
                        next_state = EXEC_PL;
                    end else begin
                        // Shouldn't happen
                        next_state = CHECK_N;
                    end
                end else begin
                    next_state = EXEC_AD;
                end
            end
            
            EXEC_DI: begin
                if (op_phase == 2'd2) begin
                    // DI done
                    next_state = DONE_STATE;
                end else begin
                    next_state = EXEC_DI;
                end
            end
            
            DONE_STATE: begin
                next_state = WAIT_START;
            end
            
            FETCH: begin
                next_state = WAIT_START;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
        
        // Override for cycle limit
        if (counter >= MAX_CYCLES) begin
            next_state = WAIT_START;
        end
    end
    
endmodule

// This module implements a binary addition algorithm for summing N.
// The FSM processes n_in bit by bit, constructing powers of 2 and adding them.
// For each set bit in n_in, it:
//  1. Creates 2^i (where i is the bit position)
//  2. Adds it to the running sum
// 
// The implementation uses an internal stack and ALU to perform:
// - Register operations (ST, ZE)
// - Stack operations (PH, PL)
// - Addition (AD)
// - Result output (DI)
//
// The algorithm handles the binary decomposition of n_in and computes
// the sum through a series of instructions generated internally.
// The instruction sequence length is bounded by 128 cycles.

// Note: The implementation above may need refinement for the exact
// binary decomposition algorithm. For a simpler and more robust
// implementation, the following approach can be used:
// 
// For n_in, we can directly compute sum by iterating through bits:
// Start with sum = 0, power = 1
// For each bit i from 0 to 7:
//   If bit i is set: sum = sum + power
//   power = power + power (double for next bit)
//
// This translates to the instruction sequence:
// - Initialize A=0, X=1 (power)
// - For each bit:
//   - If set: PH A, PH X, AD, PL A
//   - PH X, PH X, AD, PL X (double power)
// - DI A
//
// This is more efficient and cleaner. The FSM below implements this.

// REDESIGNED FSM for cleaner binary sum:

module sum_binary_revised (
    input clk,
    input rst_n,
    input start,
    input [7:0] n_in,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] WAIT_START  = 4'd1;
    localparam [3:0] INIT        = 4'd2;
    localparam [3:0] CHECK_BIT   = 4'd3;
    localparam [3:0] ADD_POWER   = 4'd4;
    localparam [3:0] DOUBLE_POWER = 4'd5;
    localparam [3:0] NEXT_BIT    = 4'd6;
    localparam [3:0] OUTPUT      = 4'd7;
    localparam [3:0] DONE_STATE  = 4'd8;
    localparam [3:0] PHASE_DONE  = 4'd9;
    localparam [3:0] EXEC_PH_A   = 4'd10;
    localparam [3:0] EXEC_PH_X   = 4'd11;
    localparam [3:0] EXEC_AD     = 4'd12;
    localparam [3:0] EXEC_PL_A   = 4'd13;
    localparam [3:0] EXEC_PL_X   = 4'd14;
    localparam [3:0] EXEC_PH_A2  = 4'd15;

    // Internal registers
    reg [3:0] state, next_state;
    reg [7:0] counter;
    localparam [7:0] MAX_CYCLES = 8'd128;
    
    // Datapath registers
    reg [7:0] A_reg;  // Sum
    reg [7:0] X_reg;  // Power of 2
    
    // Stack (16x8)
    reg [7:0] stack [0:15];
    reg [3:0] sp;
    
    // ALU
    wire [7:0] alu_result;
    assign alu_result = A_reg + X_reg;  // For addition
    
    // Temporary storage
    reg [7:0] temp_val;
    reg [2:0] bit_idx;
    reg [7:0] n_reg;
    reg [1:0] phase;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            counter <= 8'd0;
            A_reg <= 8'd0;
            X_reg <= 8'd0;
            sp <= 4'd0;
            n_reg <= 8'd0;
            bit_idx <= 3'd0;
            phase <= 2'd0;
            temp_val <= 8'd0;
            // Clear stack
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                stack[i] <= 8'd0;
            end
        end else begin
            if (state != IDLE && state != WAIT_START) begin
                if (counter < MAX_CYCLES) begin
                    counter <= counter + 8'd1;
                end
            end else begin
                counter <= 8'd0;
            end
            
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    A_reg <= 8'd0;
                    X_reg <= 8'd0;
                    sp <= 4'd0;
                    bit_idx <= 3'd0;
                    phase <= 2'd0;
                    n_reg <= 8'd0;
                    counter <= 8'd0;
                    // Clear stack
                    for (i = 0; i < 16; i = i + 1) begin
                        stack[i] <= 8'd0;
                    end
                end
                
                WAIT_START: begin
                    done <= 1'b0;
                end
                
                INIT: begin
                    // Initialize: A=0, X=1 (power=2^0=1)
                    A_reg <= 8'd0;
                    X_reg <= 8'd1;
                    bit_idx <= 3'd0;
                    n_reg <= n_in;
                    sp <= 4'd0;
                    phase <= 2'd0;
                end
                
                CHECK_BIT: begin
                    // Check if we've processed all bits
                    // No state change here, handled in next_state logic
                end
                
                ADD_POWER: begin
                    // Add X (power) to A (sum)
                    // Stack operations: PH A, PH X, AD, PL A
                    case (phase)
                        2'd0: begin
                            // PH A
                            if (sp < 4'd15) begin
                                stack[sp] <= A_reg;
                                sp <= sp + 4'd1;
                                phase <= 2'd1;
                            end
                        end
                        2'd1: begin
                            // PH X
                            if (sp < 4'd15) begin
                                stack[sp] <= X_reg;
                                sp <= sp + 4'd1;
                                phase <= 2'd2;
                            end
                        end
                        2'd2: begin
                            // AD: Pop two, add, push
                            if (sp >= 4'd2) begin
                                sp <= sp - 4'd1;  // Pop X
                                temp_val <= stack[sp - 4'd1];  // X value
                                // Next cycle will pop A and add
                            end
                            phase <= 2'd3;
                        end
                        2'd3: begin
                            // Pop A and add, push result
                            if (sp >= 4'd1) begin
                                sp <= sp - 4'd1;  // Pop A
                                A_reg <= temp_val + stack[sp];  // X + A
                                if (sp - 4'd1 < 4'd15) begin
                                    stack[sp - 4'd1] <= temp_val + stack[sp];
                                end
                            end
                            phase <= 2'd0;
                        end
                    endcase
                end
                
                DOUBLE_POWER: begin
                    // Double X: PH X, PH X, AD, PL X
                    case (phase)
                        2'd0: begin
                            // PH X
                            if (sp < 4'd15) begin
                                stack[sp] <= X_reg;
                                sp <= sp + 4'd1;
                                phase <= 2'd1;
                            end
                        end
                        2'd1: begin
                            // PH X
                            if (sp < 4'd15) begin
                                stack[sp] <= X_reg;
                                sp <= sp + 4'd1;
                                phase <= 2'd2;
                            end
                        end
                        2'd2: begin
                            // AD: Pop two, add, push
                            if (sp >= 4'd2) begin
                                sp <= sp - 4'd1;  // Pop first X
                                temp_val <= stack[sp - 4'd1];  // X value
                            end
                            phase <= 2'd3;
                        end
                        2'd3: begin
                            // Pop second X, add, push, then PL X
                            if (sp >= 4'd1) begin
                                sp <= sp - 4'd1;  // Pop second X
                                X_reg <= temp_val + stack[sp];  // X + X
                                if (sp - 4'd1 < 4'd15) begin
                                    stack[sp - 4'd1] <= temp_val + stack[sp];
                                    sp <= sp;  // Keep result on stack
                                end
                            end
                            // Now need to PL X from stack
                            if (sp > 4'd0) begin
                                sp <= sp - 4'd1;
                                X_reg <= stack[sp - 4'd1];
                            end
                            phase <= 2'd0;
                        end
                    endcase
                end
                
                NEXT_BIT: begin
                    // Increment bit index
                    bit_idx <= bit_idx + 3'd1;
                    n_reg <= {1'b0, n_reg[7:1]};  // Shift right
                end
                
                OUTPUT: begin
                    // Output result: DI A
                    result <= A_reg;
                    done <= 1'b1;
                end
                
                DONE_STATE: begin
                    done <= 1'b0;
                end
                
                // Alternative execution states for cleaner flow
                EXEC_PH_A: begin
                    if (sp < 4'd15) begin
                        stack[sp] <= A_reg;
                        sp <= sp + 4'd1;
                    end
                end
                
                EXEC_PH_X: begin
                    if (sp < 4'd15) begin
                        stack[sp] <= X_reg;
                        sp <= sp + 4'd1;
                    end
                end
                
                EXEC_AD: begin
                    if (sp >= 4'd2) begin
                        sp <= sp - 4'd1;  // Pop second
                        temp_val <= stack[sp - 4'd1];
                        sp <= sp - 4'd1;  // Pop first
                        A_reg <= temp_val + stack[sp];
                        if (sp - 4'd1 < 4'd15) begin
                            stack[sp - 4'd1] <= temp_val + stack[sp];
                            sp <= sp - 4'd1;  // Push result
                        end
                    end
                end
                
                EXEC_PL_A: begin
                    if (sp > 4'd0) begin
                        sp <= sp - 4'd1;
                        A_reg <= stack[sp];
                    end
                end
                
                EXEC_PL_X: begin
                    if (sp > 4'd0) begin
                        sp <= sp - 4'd1;
                        X_reg <= stack[sp];
                    end
                end
                
                EXEC_PH_A2: begin
                    if (sp < 4'd15) begin
                        stack[sp] <= A_reg;
                        sp <= sp + 4'd1;
                    end
                end
                
                PHASE_DONE: begin
                    phase <= 2'd0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                next_state = WAIT_START;
            end
            
            WAIT_START: begin
                if (start) begin
                    next_state = INIT;
                end else begin
                    next_state = WAIT_START;
                end
            end
            
            INIT: begin
                next_state = CHECK_BIT;
            end
            
            CHECK_BIT: begin
                if (bit_idx > 3'd7) begin
                    // All bits processed
                    next_state = OUTPUT;
                end else if (n_reg[0] == 1'b1) begin
                    // Current bit is set, add power
                    next_state = ADD_POWER;
                end else begin
                    // Bit not set, just double power and continue
                    next_state = DOUBLE_POWER;
                end
            end
            
            ADD_POWER: begin
                if (phase == 2'd0) begin
                    next_state = EXEC_PH_A;
                end else if (phase == 2'd1) begin
                    next_state = EXEC_PH_X;
                end else if (phase == 2'd2) begin
                    next_state = EXEC_AD;
                end else if (phase == 2'd3) begin
                    next_state = PHASE_DONE;
                end
            end
            
            DOUBLE_POWER: begin
                if (phase == 2'd0) begin
                    next_state = EXEC_PH_X;
                end else if (phase == 2'd1) begin
                    next_state = EXEC_PH_X;
                end else if (phase == 2'd2) begin
                    next_state = EXEC_AD;
                end else if (phase == 2'd3) begin
                    next_state = EXEC_PL_X;
                end
            end
            
            EXEC_PH_A: begin
                next_state = EXEC_PH_X;
            end
            
            EXEC_PH_X: begin
                next_state = EXEC_AD;
            end
            
            EXEC_AD: begin
                next_state = PHASE_DONE;
            end
            
            EXEC_PL_X: begin
                next_state = PHASE_DONE;
            end
            
            PHASE_DONE: begin
                if (state == ADD_POWER) begin
                    next_state = DOUBLE_POWER;
                end else if (state == DOUBLE_POWER) begin
                    next_state = NEXT_BIT;
                end else begin
                    next_state = CHECK_BIT;
                end
            end
            
            NEXT_BIT: begin
                next_state = CHECK_BIT;
            end
            
            OUTPUT: begin
                next_state = DONE_STATE;
            end
            
            DONE_STATE: begin
                next_state = WAIT_START;
            end
            
            EXEC_PL_A: begin
                next_state = OUTPUT;
            end
            
            EXEC_PH_A2: begin
                next_state = OUTPUT;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
        
        // Cycle limit check
        if (counter >= MAX_CYCLES) begin
            next_state = WAIT_START;
        end
    end
    
endmodule

// MAIN MODULE: This is the actual module that should be used
// It uses the revised algorithm for computing binary sum

module sum_binary_algorithm (
    input clk,
    input rst_n,
    input start,
    input [7:0] n_in,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] WAIT_START  = 4'd1;
    localparam [3:0] INIT        = 4'd2;
    localparam [3:0] PROCESS_BIT = 4'd3;
    localparam [3:0] ADD_TO_SUM  = 4'd4;
    localparam [3:0] DOUBLE_POWER = 4'd5;
    localparam [3:0] NEXT_BIT    = 4'd6;
    localparam [3:0] OUTPUT_RESULT = 4'd7;
    localparam [3:0] DONE_STATE  = 4'd8;

    // Internal registers
    reg [3:0] state, next_state;
    reg [7:0] counter;
    localparam [7:0] MAX_CYCLES = 8'd128;
    
    // Datapath: Registers A (sum) and X (power)
    reg [7:0] A_reg;
    reg [7:0] X_reg;
    
    // Stack (16x8)
    reg [7:0] stack [0:15];
    reg [3:0] sp;
    
    // ALU for addition (mod 256)
    wire [7:0] alu_add;
    assign alu_add = A_reg + X_reg;
    
    // Temporary storage
    reg [7:0] n_reg;
    reg [2:0] bit_idx;
    reg [1:0] op_phase;
    reg [7:0] temp_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            counter <= 8'd0;
            A_reg <= 8'd0;
            X_reg <= 8'd0;
            sp <= 4'd0;
            n_reg <= 8'd0;
            bit_idx <= 3'd0;
            op_phase <= 2'd0;
            temp_reg <= 8'd0;
            // Initialize stack
            for (i = 0; i < 16; i = i + 1) begin
                stack[i] <= 8'd0;
            end
        end else begin
            if (state != IDLE && state != WAIT_START) begin
                if (counter < MAX_CYCLES) begin
                    counter <= counter + 8'd1;
                end
            end else begin
                counter <= 8'd0;
            end
            
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    A_reg <= 8'd0;
                    X_reg <= 8'd0;
                    sp <= 4'd0;
                    bit_idx <= 3'd0;
                    op_phase <= 2'd0;
                    n_reg <= 8'd0;
                    temp_reg <= 8'd0;
                    // Clear stack
                    for (i = 0; i < 16; i = i + 1) begin
                        stack[i] <= 8'd0;
                    end
                end
                
                WAIT_START: begin
                    done <= 1'b0;
                end
                
                INIT: begin
                    // Initialize: A = 0 (sum), X = 1 (2^0)
                    A_reg <= 8'd0;
                    X_reg <= 8'd1;
                    bit_idx <= 3'd0;
                    n_reg <= n_in;
                    sp <= 4'd0;
                    op_phase <= 2'd0;
                end
                
                PROCESS_BIT: begin
                    // Process current bit (check if done)
                end
                
                ADD_TO_SUM: begin
                    // Add power X to sum A
                    // Using stack: PH A, PH X, AD, PL A
                    case (op_phase)
                        2'd0: begin
                            // PH A
                            if (sp < 4'd15) begin
                                stack[sp] <= A_reg;
                                sp <= sp + 4'd1;
                            end
                            op_phase <= 2'd1;
                        end
                        2'd1: begin
                            // PH X
                            if (sp < 4'd15) begin
                                stack[sp] <= X_reg;
                                sp <= sp + 4'd1;
                            end
                            op_phase <= 2'd2;
                        end
                        2'd2: begin
                            // AD: Pop two, add, push result
                            if (sp >= 4'd2) begin
                                sp <= sp - 4'd1;  // Pop X
                                temp_reg <= stack[sp - 4'd1];  // Save X
                            end
                            op_phase <= 2'd3;
                        end
                        2'd3: begin
                            // Pop A, compute sum, push
                            if (sp >= 4'd1) begin
                                sp <= sp - 4'd1;  // Pop A
                                A_reg <= temp_reg + stack[sp];  // X + A
                                if (sp - 4'd1 < 4'd15) begin
                                    stack[sp - 4'd1] <= temp_reg + stack[sp];
                                end
                            end
                            op_phase <= 2'd0;
                        end
                    endcase
                end
                
                DOUBLE_POWER: begin
                    // Double power: PH X, PH X, AD, PL X
                    case (op_phase)
                        2'd0: begin
                            // PH X
                            if (sp < 4'd15) begin
                                stack[sp] <= X_reg;
                                sp <= sp + 4'd1;
                            end
                            op_phase <= 2'd1;
                        end
                        2'd1: begin
                            // PH X
                            if (sp < 4'd15) begin
                                stack[sp] <= X_reg;
                                sp <= sp + 4'd1;
                            end
                            op_phase <= 2'd2;
                        end
                        2'd2: begin
                            // AD: Pop two, add, push
                            if (sp >= 4'd2) begin
                                sp <= sp - 4'd1;  // Pop first X
                                temp_reg <= stack[sp - 4'd1];  // Save X
                            end
                            op_phase <= 2'd3;
                        end
                        2'd3: begin
                            // Pop second X, add, then PL X
                            if (sp >= 4'd1) begin
                                sp <= sp - 4'd1;  // Pop second X
                                X_reg <= temp_reg + stack[sp];  // X + X
                                if (sp - 4'd1 < 4'd15) begin
                                    stack[sp - 4'd1] <= temp_reg + stack[sp];
                                    sp <= sp - 4'd1;  // Push result
                                end
                            end
                            // Now PL X: pop stack to X_reg
                            if (sp > 4'd0) begin
                                sp <= sp - 4'd1;
                                X_reg <= stack[sp];
                            end
                            op_phase <= 2'd0;
                        end
                    endcase
                end
                
                NEXT_BIT: begin
                    // Move to next bit
                    bit_idx <= bit_idx + 3'd1;
                    n_reg <= {1'b0, n_reg[7:1]};  // Shift right
                end
                
                OUTPUT_RESULT: begin
                    // Output A as result
                    result <= A_reg;
                    done <= 1'b1;
                end
                
                DONE_STATE: begin
                    done <= 1'b0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                next_state = WAIT_START;
            end
            
            WAIT_START: begin
                if (start) begin
                    next_state = INIT;
                end else begin
                    next_state = WAIT_START;
                end
            end
            
            INIT: begin
                next_state = PROCESS_BIT;
            end
            
            PROCESS_BIT: begin
                if (bit_idx > 3'd7) begin
                    next_state = OUTPUT_RESULT;
                end else if (n_reg[0] == 1'b1) begin
                    next_state = ADD_TO_SUM;
                end else begin
                    next_state = DOUBLE_POWER;
                end
            end
            
            ADD_TO_SUM: begin
                if (op_phase == 2'd3) begin
                    next_state = DOUBLE_POWER;
                end else begin
                    next_state = ADD_TO_SUM;
                end
            end
            
            DOUBLE_POWER: begin
                if (op_phase == 2'd3) begin
                    next_state = NEXT_BIT;
                end else begin
                    next_state = DOUBLE_POWER;
                end
            end
            
            NEXT_BIT: begin
                next_state = PROCESS_BIT;
            end
            
            OUTPUT_RESULT: begin
                next_state = DONE_STATE;
            end
            
            DONE_STATE: begin
                next_state = WAIT_START;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
        
        // Cycle limit
        if (counter >= MAX_CYCLES) begin
            next_state = WAIT_START;
        end
    end
    
endmodule

// FINAL IMPLEMENTATION: Streamlined version
// This is the module that should be returned

module sum_binary_algorithm_final (
    input clk,
    input rst_n,
    input start,
    input [7:0] n_in,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] WAIT_START  = 4'd1;
    localparam [3:0] INIT        = 4'd2;
    localparam [3:0] CHECK_BIT   = 4'd3;
    localparam [3:0] ADD_POW     = 4'd4;
    localparam [3:0] DOUBLE_POW  = 4'd5;
    localparam [3:0] NEXT_BIT    = 4'd6;
    localparam [3:0] OUTPUT      = 4'd7;
    localparam [3:0] DONE_STATE  = 4'd8;
    localparam [3:0] PH1         = 4'd9;
    localparam [3:0] PH2         = 4'd10;
    localparam [3:0] PH3         = 4'd11;
    localparam [3:0] PH4         = 4'd12;

    // Internal registers
    reg [3:0] state, next_state;
    reg [7:0] counter;
    localparam [7:0] MAX_CYCLES = 8'd128;
    
    // Datapath
    reg [7:0] A_reg;  // Sum accumulator
    reg [7:0] X_reg;  // Current power of 2
    
    // Stack
    reg [7:0] stack [0:15];
    reg [3:0] sp;
    
    // Storage
    reg [7:0] n_reg;
    reg [2:0] bit_idx;
    reg [1:0] phase;
    reg [7:0] temp;
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            counter <= 8'd0;
            A_reg <= 8'd0;
            X_reg <= 8'd0;
            sp <= 4'd0;
            n_reg <= 8'd0;
            bit_idx <= 3'd0;
            phase <= 2'd0;
            temp <= 8'd0;
            for (i = 0; i < 16; i = i + 1) begin
                stack[i] <= 8'd0;
            end
        end else begin
            if (state != IDLE && state != WAIT_START) begin
                if (counter < MAX_CYCLES) begin
                    counter <= counter + 8'd1;
                end
            end else begin
                counter <= 8'd0;
            end
            
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    A_reg <= 8'd0;
                    X_reg <= 8'd0;
                    sp <= 4'd0;
                    bit_idx <= 3'd0;
                    phase <= 2'd0;
                    n_reg <= 8'd0;
                    temp <= 8'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        stack[i] <= 8'd0;
                    end
                end
                
                WAIT_START: begin
                    done <= 1'b0;
                end
                
                INIT: begin
                    A_reg <= 8'd0;
                    X_reg <= 8'd1;
                    bit_idx <= 3'd0;
                    n_reg <= n_in;
                    sp <= 4'd0;
                    phase <= 2'd0;
                end
                
                CHECK_BIT: begin
                    // Handled in next_state
                end
                
                ADD_POW: begin
                    // Add X to A (A = A + X)
                    // PH A, PH X, AD, PL A
                    case (phase)
                        2'd0: begin  // PH A
                            if (sp < 4'd15) begin
                                stack[sp] <= A_reg;
                                sp <= sp + 4'd1;
                            end
                            phase <= 2'd1;
                        end
                        2'd1: begin  // PH X
                            if (sp < 4'd15) begin
                                stack[sp] <= X_reg;
                                sp <= sp + 4'd1;
                            end
                            phase <= 2'd2;
                        end
                        2'd2: begin  // AD (prep)
                            if (sp >= 4'd2) begin
                                sp <= sp - 4'd1;
                                temp <= stack[sp - 4'd1];
                            end
                            phase <= 2'd3;
                        end
                        2'd3: begin  // AD (execute) and PL A
                            if (sp >= 4'd1) begin
                                sp <= sp - 4'd1;
                                A_reg <= temp + stack[sp];
                                if (sp - 4'd1 < 4'd15) begin
                                    stack[sp - 4'd1] <= temp + stack[sp];
                                end
                            end
                            phase <= 2'd0;
                        end
                    endcase
                end
                
                DOUBLE_POW: begin
                    // X = X + X (X = 2 * X)
                    // PH X, PH X, AD, PL X
                    case (phase)
                        2'd0: begin  // PH X
                            if (sp < 4'd15) begin
                                stack[sp] <= X_reg;
                                sp <= sp + 4'd1;
                            end
                            phase <= 2'd1;
                        end
                        2'd1: begin  // PH X
                            if (sp < 4'd15) begin
                                stack[sp] <= X_reg;
                                sp <= sp + 4'd1;
                            end
                            phase <= 2'd2;
                        end
                        2'd2: begin  // AD (prep)
                            if (sp >= 4'd2) begin
                                sp <= sp - 4'd1;
                                temp <= stack[sp - 4'd1];
                            end
                            phase <= 2'd3;
                        end
                        2'd3: begin  // AD (execute) and PL X
                            if (sp >= 4'd1) begin
                                sp <= sp - 4'd1;
                                X_reg <= temp + stack[sp];
                                if (sp - 4'd1 < 4'd15) begin
                                    stack[sp - 4'd1] <= temp + stack[sp];
                                end
                            end
                            if (sp > 4'd0) begin
                                sp <= sp - 4'd1;
                                X_reg <= stack[sp];
                            end
                            phase <= 2'd0;
                        end
                    endcase
                end
                
                NEXT_BIT: begin
                    bit_idx <= bit_idx + 3'd1;
                    n_reg <= {1'b0, n_reg[7:1]};
                end
                
                OUTPUT: begin
                    result <= A_reg;
                    done <= 1'b1;
                end
                
                DONE_STATE: begin
                    done <= 1'b0;
                end
                
                // Additional phases for cleaner control
                PH1: begin
                    // Push A to stack
                    if (sp < 4'd15) begin
                        stack[sp] <= A_reg;
                        sp <= sp + 4'd1;
                    end
                end
                
                PH2: begin
                    // Push X to stack
                    if (sp < 4'd15) begin
                        stack[sp] <= X_reg;
                        sp <= sp + 4'd1;
                    end
                end
                
                PH3: begin
                    // Pop two, add
                    if (sp >= 4'd2) begin
                        sp <= sp - 4'd1;
                        temp <= stack[sp - 4'd1];
                        sp <= sp - 4'd1;
                        A_reg <= temp + stack[sp];
                        if (sp - 4'd1 < 4'd15) begin
                            stack[sp - 4'd1] <= temp + stack[sp];
                            sp <= sp - 4'd1;
                        end
                    end
                end
                
                PH4: begin
                    // Pop to X
                    if (sp > 4'd0) begin
                        sp <= sp - 4'd1;
                        X_reg <= stack[sp];
                    end
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: next_state = WAIT_START;
            
            WAIT_START: begin
                if (start) next_state = INIT;
                else next_state = WAIT_START;
            end
            
            INIT: next_state = CHECK_BIT;
            
            CHECK_BIT: begin
                if (bit_idx > 3'd7) next_state = OUTPUT;
                else if (n_reg[0] == 1'b1) next_state = ADD_POW;
                else next_state = DOUBLE_POW;
            end
            
            ADD_POW: begin
                if (phase == 2'd3) next_state = DOUBLE_POW;
                else next_state = ADD_POW;
            end
            
            DOUBLE_POW: begin
                if (phase == 2'd3) next_state = NEXT_BIT;
                else next_state = DOUBLE_POW;
            end
            
            NEXT_BIT: next_state = CHECK_BIT;
            
            OUTPUT: next_state = DONE_STATE;
            
            DONE_STATE: next_state = WAIT_START;
            
            default: next_state = IDLE;
        endcase
        
        if (counter >= MAX_CYCLES) next_state = WAIT_START;
    end
    
endmodule