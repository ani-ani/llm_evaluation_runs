module mean_absolute_deviation (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_elements,
    input [31:0] data_in,
    input data_valid,
    output reg [31:0] result,
    output reg done,
    output reg [2:0] read_index
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam READ_MEAN = 3'b001;
    localparam READ_DATA = 3'b010;
    localparam COMPUTE = 3'b011;
    localparam DIVIDE = 3'b100;
    localparam DONE = 3'b101;

    // Registers
    reg [2:0] current_state;
    reg [2:0] next_state;
    reg [2:0] element_counter; // Tracks index 0-7 or loop counts
    reg [31:0] accumulator; // Holds sum or partial sums
    reg [31:0] mean_val; // Holds the calculated mean
    reg [31:0] temp_diff; // Holds difference for abs computation
    reg [2:0] shift_amt; // Shift amount derived from num_elements
    
    // Logic to calculate shift amount based on num_elements (N)
    // N=1 -> 0 shifts, N=2 -> 1 shift, ..., N=8 -> 3 shifts
    always @(*) begin
        case(num_elements)
            3'b001: shift_amt = 3'd0; // 1
            3'b010: shift_amt = 3'd1; // 2
            3'b011: shift_amt = 3'd1; // 3 (approx for 4) -> 2
            3'b100: shift_amt = 3'd2; // 4
            3'b101: shift_amt = 3'd2; // 5 (approx for 8) -> 3
            3'b110: shift_amt = 3'd2; // 6 -> 3
            3'b111: shift_amt = 3'd2; // 7 -> 3
            default: shift_amt = 3'd0;
        endcase
        // Special case logic for exact division not strictly required by prompt (shift right),
        // but let's stick to standard powers of 2 for shift if strict, 
        // or simply use the bit width. Prompt says 'shift for division by power of 2'.
        // For N=3, 5, 6, 7, exact division is not a power of 2. 
        // However, the prompt implies 'shift-right since N is power of 2'.
        // Let's calculate shift amount for power of 2 equivalence for 1, 2, 4, 8.
        // If num_elements is not a power of 2, we might need a divider, but prompt says use shift.
        // Let's map: 1->0, 2->1, 3->2 (approx), 4->2, 5->3 (approx), 6->3, 7->3, 8->3.
        // Actually, simpler approach: Use bits required.
        // 1 element: 0 shifts. 2-3 elements: 1 shift (divide by 2). 4-7 elements: 2 shifts (divide by 4). 8 elements: 3 shifts (divide by 8).
        // Re-evaluating prompt: 'Division by shift-right since N is power of 2'. 
        // I will implement the shift logic based on log2(N) approximation for general N, or strictly powers of 2 if requested.
        // Given the hardware constraint, let's assume the user wants standard bit-shifts.
        // 1 (0 shifts), 2 (1 shift), 3 (1 shift), 4 (2 shifts), 5 (2 shifts), 6 (2 shifts), 7 (2 shifts), 8 (3 shifts).
        // Note: For strictly powers of 2 (1, 2, 4, 8), the mapping is exact.
        // I will implement the log2 ceiling logic.
        if (num_elements == 3'b001) shift_amt = 3'd0;
        else if (num_elements <= 3'b011) shift_amt = 3'd1;
        else if (num_elements <= 3'b111) shift_amt = 3'd2;
        else shift_amt = 3'd3; // Should not happen given 3 bits
    end

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // Next State Logic
    always @(*) begin
        next_state = current_state; // Default hold
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = READ_MEAN;
            end
            READ_MEAN: begin
                // Wait for all elements to be read for mean
                if (data_valid && (element_counter + 1 == num_elements))
                    next_state = COMPUTE; // Go to compute to do the division (mean = sum/N)
            end
            COMPUTE: begin
                // This state handles multiple operations depending on flow
                // Sub-state logic is better handled by specific counters
                // Flow: 
                // 1. After READ_MEAN accumulation -> Compute Mean (Shift) -> transition to READ_DATA
                // 2. After READ_DATA accumulation -> transition to DIVIDE
                
                // To keep state machine linear as requested: 
                // IDLE -> READ_MEAN -> READ_DATA -> COMPUTE -> DIVIDE -> DONE
                // But COMPUTE needs to happen twice. 
                // I will use the state to perform the Mean Calculation shift, then go to READ_DATA.
                // Then back to COMPUTE (via READ_DATA done) to perform the final Sum shift.
                // Actually, a cleaner way is:
                // READ_MEAN (collects) -> DIVIDE (calc mean) -> READ_DATA (collect diffs) -> COMPUTE (calc sum diffs) -> DIVIDE (final calc) -> DONE
                // Or keep it as IDLE -> READ_MEAN -> COMPUTE (calc mean) -> READ_DATA -> COMPUTE (calc sum diffs) -> DIVIDE (final calc) -> DONE
                // I will interpret COMPUTE as the state where math happens.
                
                // Logic inside COMPUTE state will check 'stage' or context.
                // Let's use flags to differentiate actions in states.
                // Let's strictly follow the state list: IDLE, READ_MEAN, READ_DATA, COMPUTE, DIVIDE, DONE
                // Interpretation:
                // READ_MEAN: Read inputs and sum them.
                // COMPUTE (First): Convert Mean Sum -> Mean (Divide by N). -> Transition to READ_DATA.
                // READ_DATA: Read inputs, calc abs diff, accumulate. -> Transition to COMPUTE.
                // COMPUTE (Second): Wait for accumulation? No, accumulate inside READ_DATA or COMPUTE?
                // Prompt says 'In READ_DATA: fetch... compute abs diff... sum...' -> Accumulate here.
                // Then 'In COMPUTE: sum all deviations'. This implies READ_DATA gets diffs, COMPUTE sums them? That seems off if READ_DATA already sums.
                // Maybe READ_DATA fetches and stores diff, COMPUTE sums them all.
                // But we have no RAM. 
                // Hypothesis:
                // 1. READ_MEAN: Read N numbers, sum into accumulator. (Iterates N times)
                // 2. COMPUTE: Shift accumulator to get mean. Store in mean_val. Reset accumulator. (1 cycle logic)
                // 3. READ_DATA: Read N numbers. For each, calculate |data - mean|. Add to accumulator. (Iterates N times)
                // 4. COMPUTE: Shift accumulator to get final MAD. (1 cycle logic)
                // 5. DIVIDE: Maybe redundant if COMPUTE did it? Prompt has DIVIDE state.
                // Let's adjust:
                // READ_MEAN: Read and Sum.
                // COMPUTE (1): Shift accumulator -> Mean. Reset Counter.
                // READ_DATA: Read and Sum absolute diffs.
                // COMPUTE (2): Shift accumulator -> Final Result. 
                // DIVIDE: Explicit state for final shift? Prompt has it. I will map COMPUTE -> Mean, DIVIDE -> Final MAD.
                // WAIT states added for synchronization.

                // To fit IDLE, READ_MEAN, READ_DATA, COMPUTE, DIVIDE, DONE strictly:
                // Transition out of COMPUTE when math is done (latched next cycle).
                next_state = DIVIDE; // Default transition from COMPUTE to DIVIDE (or READ_DATA)
            end
            DIVIDE: begin
                // Used for final result generation
                next_state = DONE;
            end
            READ_DATA: begin
                if (data_valid && (element_counter + 1 == num_elements))
                    next_state = DIVIDE; // Accumulate done, go to compute final division
            end
            DONE: begin
                if (!start) // Wait for start to go low to reset or stay? 
                    next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
        
        // Refinement of transitions to match the 5 states exactly:
        // IDLE -> READ_MEAN (on start)
        // READ_MEAN -> COMPUTE (when all read)
        // COMPUTE -> READ_DATA (perform mean calculation)
        // READ_DATA -> DIVIDE (when all read)
        // DIVIDE -> DONE (perform final calculation)
        // DONE -> IDLE (reset)
        
        if (current_state == IDLE && start) next_state = READ_MEAN;
        else if (current_state == READ_MEAN && data_valid && (element_counter + 1 == num_elements)) next_state = COMPUTE;
        else if (current_state == COMPUTE) next_state = READ_DATA; // Assume cycle latency for shift is 0 (combinational) or 1 (next state). 
        // If combinational logic in state is used, we can transition immediately. But standard Verilog uses registered outputs.
        // I will use COMPUTE to latch the Mean value, then go to READ_DATA.
        else if (current_state == READ_DATA && data_valid && (element_counter + 1 == num_elements)) next_state = DIVIDE;
        else if (current_state == DIVIDE) next_state = DONE;
        else if (current_state == DONE && !start) next_state = IDLE;
        else next_state = current_state;
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 32'd0;
            done <= 1'b0;
            read_index <= 3'd0;
            element_counter <= 3'd0;
            accumulator <= 32'd0;
            mean_val <= 32'd0;
            temp_diff <= 32'd0;
        end else begin
            done <= 1'b0; // Default done low
            
            case (next_state)
                IDLE: begin
                    element_counter <= 3'd0;
                    accumulator <= 32'd0;
                    read_index <= 3'd0;
                end

                READ_MEAN: begin
                    if (data_valid) begin
                        accumulator <= accumulator + data_in;
                        element_counter <= element_counter + 1'b1;
                        read_index <= element_counter + 1'b1;
                    end
                end

                COMPUTE: begin
                    // This state performs the division of the accumulator to get the mean
                    // Logic: mean_val = accumulator >> shift_amt
                    element_counter <= 3'd0; // Reset for next read phase
                    read_index <= 3'd0; // Reset index
                    accumulator <= 32'd0; // Reset accumulator for next phase
                    
                    // Shift operation
                    case (shift_amt)
                        3'd0: mean_val <= accumulator;
                        3'd1: mean_val <= accumulator >> 1;
                        3'd2: mean_val <= accumulator >> 2;
                        3'd3: mean_val <= accumulator >> 3;
                        default: mean_val <= accumulator;
                    endcase
                end

                READ_DATA: begin
                    if (data_valid) begin
                        // Compute difference: data_in - mean_val
                        // Check sign to compute absolute value
                        if (data_in >= mean_val) begin
                            temp_diff <= data_in - mean_val;
                        end else begin
                            temp_diff <= mean_val - data_in;
                        end
                        // We need one cycle to compute diff, then add in next cycle or combinational.
                        // To save states, let's compute diff in same cycle if possible, but inputs are registered.
                        // Let's register the diff, then add in next clock. 
                        // Wait, we are in the state READ_DATA. We read 'data_valid'.
                        // The logic above computes diff into temp_diff.
                        // We need to add it to accumulator. 
                        // Let's do the add in the same clock for better throughput if timing permits, but strictly we are processing one value per cycle.
                        // Let's perform the subtraction in combinational logic outside the always block? 
                        // No, keep it inside.
                        // To avoid extra latency, let's add 'temp_diff' of previous cycle? No.
                        // Let's use combinational logic for diff calculation based on current inputs, then accumulate.
                        // But `data_in` is input, `mean_val` is registered. 
                        // Let's do: diff = (data_in >= mean_val) ? (data_in - mean_val) : (mean_val - data_in);
                        // accumulator <= accumulator + diff;
                        // But we need to use blocking assignment for combinational calc inside sequential block? No, use intermediate wire.
                        // Let's stick to registered logic for safety/synthesis.
                        // Cycle 1 (when data_valid high): Compute diff, store in temp_diff, flag 'diff_ready'.
                        // Cycle 2: Add temp_diff to accumulator.
                        // This wastes cycles.
                        // Better: 
                        // In READ_DATA state, when data_valid is high:
                        // accumulator <= accumulator + ((data_in >= mean_val) ? (data_in - mean_val) : (mean_val - data_in));
                        // This is pure combinational logic inside the FF block. Synthesis tools handle this well.
                        
                        if (data_in >= mean_val)
                            accumulator <= accumulator + (data_in - mean_val);
                        else
                            accumulator <= accumulator + (mean_val - data_in);
                            
                        element_counter <= element_counter + 1'b1;
                        read_index <= element_counter + 1'b1;
                    end
                end

                DIVIDE: begin
                    // This is the second division (Sum of absolute diffs / N)
                    // Result is accumulator >> shift_amt
                    case (shift_amt)
                        3'd0: result <= accumulator;
                        3'd1: result <= accumulator >> 1;
                        3'd2: result <= accumulator >> 2;
                        3'd3: result <= accumulator >> 3;
                        default: result <= accumulator;
                    endcase
                end

                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule
