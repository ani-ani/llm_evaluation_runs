module rectangular_sum (
    input clk,
    input rst_n,
    input start,
    input [31:0] a,
    input [3:0] length,
    input [15:0][3:0] digits,
    output reg [31:0] result,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam PHASE1_GEN_SUBARRAYS = 3'b001;
    localparam PHASE1_STORE = 3'b010;
    localparam PHASE2_COUNT = 3'b011;
    localparam PHASE3_CALC = 3'b100;
    localparam DONE = 3'b101;

    // Internal Registers
    reg [2:0] state, next_state;
    reg [31:0] result_reg, next_result;
    reg done_reg, next_done;

    // Phase 1 Registers
    reg [3:0] p1_start, next_p1_start;
    reg [3:0] p1_end, next_p1_end;
    reg [31:0] subarray_sum, next_subarray_sum;
    reg [31:0] subarray_buffer [0:135]; // BRAM for 136 sums
    reg [7:0] p1_write_idx, next_p1_write_idx;

    // Phase 2 & 3 Registers
    reg [31:0] freq_table [0:144]; // Frequency lookup table
    reg [7:0] p2_read_idx, next_p2_read_idx;
    reg [31:0] current_sum, next_current_sum;
    reg [31:0] current_freq, next_current_freq;
    reg [31:0] target_sum, next_target_sum;
    reg [31:0] target_freq, next_target_freq;

    // Combinational helper signals
    wire [31:0] next_subarray_sum_wire;
    assign next_subarray_sum_wire = subarray_sum + digits[p1_end];

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_reg <= 0;
            done_reg <= 0;
            p1_start <= 0;
            p1_end <= 0;
            subarray_sum <= 0;
            p1_write_idx <= 0;
            p2_read_idx <= 0;
            current_sum <= 0;
            current_freq <= 0;
            target_sum <= 0;
            target_freq <= 0;
        end else begin
            state <= next_state;
            result_reg <= next_result;
            done_reg <= next_done;
            p1_start <= next_p1_start;
            p1_end <= next_p1_end;
            subarray_sum <= next_subarray_sum;
            p1_write_idx <= next_p1_write_idx;
            p2_read_idx <= next_p2_read_idx;
            current_sum <= next_current_sum;
            current_freq <= next_current_freq;
            target_sum <= next_target_sum;
            target_freq <= next_target_freq;
        end
    end

    // Next State Logic & Output Logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_result = result_reg;
        next_done = done_reg;
        next_p1_start = p1_start;
        next_p1_end = p1_end;
        next_subarray_sum = subarray_sum;
        next_p1_write_idx = p1_write_idx;
        next_p2_read_idx = p2_read_idx;
        next_current_sum = current_sum;
        next_current_freq = current_freq;
        next_target_sum = target_sum;
        next_target_freq = target_freq;

        case (state)
            IDLE: begin
                next_done = 0;
                next_result = 0;
                next_p1_start = 0;
                next_p1_end = 0;
                next_subarray_sum = 0;
                next_p1_write_idx = 0;
                next_p2_read_idx = 0;

                if (start) begin
                    // Check if length is valid
                    if (length > 0 && length <= 16)
                        next_state = PHASE1_GEN_SUBARRAYS;
                    else
                        next_state = DONE; // Invalid length, finish immediately
                end
            end

            PHASE1_GEN_SUBARRAYS: begin
                // Loop through all valid subarrays
                // Generate sum on the fly
                if (p1_end < length) begin
                    next_subarray_sum = next_subarray_sum_wire;
                    next_p1_end = p1_end + 1;
                    next_state = PHASE1_STORE;
                end else begin
                    // End of current start index
                    if (p1_start + 1 < length) begin
                        next_p1_start = p1_start + 1;
                        next_p1_end = p1_start + 1;
                        next_subarray_sum = digits[p1_start + 1];
                    end else begin
                        // Finished all subarrays
                        next_state = PHASE2_COUNT;
                    end
                end
            end

            PHASE1_STORE: begin
                // Store the calculated sum
                subarray_buffer[p1_write_idx] = subarray_sum;
                next_p1_write_idx = p1_write_idx + 1;
                next_subarray_sum = subarray_sum; // Keep sum for accumulation logic in Gen
                next_state = PHASE1_GEN_SUBARRAYS;
            end

            PHASE2_COUNT: begin
                // Build Histogram
                if (p2_read_idx < p1_write_idx) begin
                    // Read from buffer
                    // Since reading register array needs a cycle, we handle logic here carefully
                    // In this specific FSM structure, we will use the stored value directly
                    // Note: Verilog array read is usually combinational if blocking, but here we are in sequential block.
                    // We rely on the fact that subarray_buffer access is combinational in synthesis
                    // Let's assume subarray_buffer[p2_read_idx] is available immediately.

                    if (freq_table[subarray_buffer[p2_read_idx]] < 255) // Cap at 255
                        freq_table[subarray_buffer[p2_read_idx]] = freq_table[subarray_buffer[p2_read_idx]] + 1;

                    next_p2_read_idx = p2_read_idx + 1;
                end else begin
                    // Finished counting
                    next_p2_read_idx = 0;
                    if (a == 0) begin
                        // Special case for zero
                        // We need TotalSubarrays = p1_write_idx
                        // Result = freq[0]^2 + 2*freq[0]*(Total - freq[0])
                        // Optimization: Calculate directly
                        next_result = (freq_table[0] * freq_table[0]) + (freq_table[0] * (p1_write_idx - freq_table[0]));
                        next_result = next_result << 1; // * 2
                        next_result = next_result + (freq_table[0] * freq_table[0]);
                        next_state = DONE;
                    end else begin
                        // Move to Phase 3
                        next_current_sum = 1;
                        next_state = PHASE3_CALC;
                    end
                end
            end

            PHASE3_CALC: begin
                // Iterate s from 1 to 144
                if (current_sum <= 144) begin
                    if (freq_table[current_sum] > 0) begin
                        // Check if a is divisible by current_sum
                        if ((a % current_sum) == 0) begin
                            next_target_sum = a / current_sum;
                            // Check if target is valid and s <= target to avoid double counting
                            if (next_target_sum <= 144 && next_target_sum >= current_sum) begin
                                next_target_freq = freq_table[next_target_sum];
                                // Calculate addition
                                if (current_sum == next_target_sum) begin
                                    next_result = result_reg + (freq_table[current_sum] * freq_table[current_sum]);
                                end else begin
                                    next_result = result_reg + (freq_table[current_sum] * freq_table[next_target_sum]);
                                end
                            end
                        end
                    end
                    next_current_sum = current_sum + 1;
                end else begin
                    next_state = DONE;
                end
            end

            DONE: begin
                next_done = 1;
                if (!start) begin
                    next_state = IDLE;
                    next_done = 0;
                    // Clear freq table for next run (lazy clear via reset or explicit loop not needed if we write before read)
                    // But to be safe, we can assume we overwrite.
                    // However, for clean synthesis, let's reset freq table content in IDLE or upon start.
                    // Let's do an explicit clear loop if we were to be super robust,
                    // but given the constraints, we will clear the table in IDLE if we want full deterministic behavior.
                    // Better approach: Clear table in Phase 2 start or IDLE start.
                    // Let's add a clear mechanism. Since max size is small (145), we can clear it in IDLE.
                end
            end
        endcase
    end

    // Output Assignments
    assign result = result_reg;
    assign done = done_reg;

    // Frequency Table Clear Logic (Combinational reset for the memory)
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 145; i = i + 1) begin
                freq_table[i] <= 0;
            end
        end else if (state == IDLE && start) begin
            // Clear table when starting a new calculation
            for (i = 0; i < 145; i = i + 1) begin
                freq_table[i] <= 0;
            end
        end
    end

endmodule