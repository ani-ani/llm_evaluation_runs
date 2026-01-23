module construct_sequence (
    input clk,
    input rst_n,
    input start,
    input [4:0] N_in,
    input [4:0] K_in,
    output reg [4:0] sequence_out,
    output reg valid,
    output reg done,
    output reg error
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam SETUP = 2'b01;
    localparam GENERATE = 2'b10;
    localparam FINISHED = 2'b11;

    reg [1:0] state;
    reg [1:0] next_state;

    // Internal registers
    reg [4:0] N_reg;
    reg [4:0] K_reg;
    reg [4:0] M_reg; // Number of blocks (equals K_reg in valid case)
    reg [4:0] Q_reg; // Quotient (base size)
    reg [4:0] R_reg; // Remainder
    reg [4:0] count_blocks; // Current block index
    reg [4:0] count_in_block; // Current position within block
    reg [4:0] current_start; // Start value of current block
    reg [4:0] current_end; // End value of current block
    reg [4:0] out_val_next;
    reg valid_next;
    reg done_next;
    reg error_next;

    // State transition logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = SETUP;
            SETUP: begin
                // If valid, go to GENERATE, else go to FINISHED (which sets error)
                if (error_next) next_state = FINISHED;
                else next_state = GENERATE;
            end
            GENERATE: begin
                // Check if finished outputting all N values
                // We output N values. Done condition: count_blocks >= M_reg AND count_in_block > current_size
                // But easier: we track total output count or just compare against N_reg.
                // Let's use a counter for total outputs or derive from state.
                // Logic inside GENERATE will determine if done.
                // We'll use a separate logic check here.
                // If count_blocks == M_reg (exhausted all blocks), go to FINISHED.
                // Since we process block by block, we can transition when block is done and no more blocks.
                // Actually, we update counters inside GENERATE.
                // Let's define done condition as (count_blocks == M_reg).
                // But we need to output the last value first.
                // Let's say we transition when we are about to start a block that doesn't exist.
                // Or simpler: if (count_blocks == M_reg && count_in_block == 0) -> FINISHED (but we never enter GENERATE for non-existent block).
                // So we need to detect end of generation inside the FSM logic.
                // Let's use a 'gen_done' flag.
                if (count_blocks == M_reg && count_in_block == 0) next_state = FINISHED;
            end
            FINISHED: if (start) next_state = SETUP; // Reset capability
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(*) begin
        // Default assignments
        out_val_next = sequence_out;
        valid_next = 1'b0;
        done_next = 1'b0;
        error_next = error; // Preserve error unless updated
        // next_state handled above, but we need to calculate internal logic for update
        
        case (state)
            IDLE: begin
                error_next = 1'b0;
            end
            
            SETUP: begin
                // Validation Logic
                // Condition 1: K > N or K < 1
                if (K_in > N_in || K_in < 1) begin
                    error_next = 1'b1;
                end
                // Condition 2: K = 1 and N > 1
                else if (K_in == 1 && N_in > 1) begin
                    error_next = 1'b1;
                end
                // Condition 3: N > K * K
                // Since K is up to 16, K*K fits in 9 bits. K_in is 5 bits.
                else if (N_in > (K_in * K_in)) begin
                    error_next = 1'b1;
                end
                else begin
                    error_next = 1'b0;
                end
            end

            GENERATE: begin
                if (error) begin
                    // If we entered GENERATE with error (shouldn't happen based on transition), 
                    // but safety.
                    valid_next = 1'b0;
                end else begin
                    // We are in GENERATE. We output a value.
                    // Sequence: 
                    // Block 0: values (Start + Size - 1) down to Start
                    // ...
                    // Block i: values (Start_i + Size_i - 1) down to Start_i
                    
                    // Determine current block size
                    // Block 0..R-1: Q+1, Block R..M-1: Q
                    // M = K
                    // R = N % K
                    // Q = N / K
                    
                    // We need to know current Start and current Value to output.
                    // Current Value logic:
                    // Value = (Start + Current_Block_Size - 1) - count_in_block
                    // Example: Block 0, Start=1, Size=3. Output 3, 2, 1.
                    // count_in_block 0 -> 3 = 1+3-1-0 = 3. 
                    // count_in_block 1 -> 2 = 1+3-1-1 = 2.
                    
                    // Pre-calculate block size for current block index
                    reg [4:0] current_size;
                    if (count_blocks < R_reg) current_size = Q_reg + 1;
                    else current_size = Q_reg;

                    // Check if we are within bounds of current block
                    if (count_blocks < M_reg && count_in_block < current_size) begin
                        // Calculate output value
                        out_val_next = current_start + current_size - 1 - count_in_block;
                        valid_next = 1'b1;
                    end else begin
                        // This case is handled by state transition or wait logic
                        // We stay in GENERATE and output nothing (valid=0) until next block or finish
                        valid_next = 1'b0;
                    end
                end
            end
            
            FINISHED: begin
                done_next = 1'b1;
            end
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sequence_out <= 0;
            valid <= 0;
            done <= 0;
            error <= 0;
            count_blocks <= 0;
            count_in_block <= 0;
            current_start <= 0;
            N_reg <= 0;
            K_reg <= 0;
        end else begin
            state <= next_state;
            valid <= valid_next;
            done <= done_next;
            error <= error_next;
            sequence_out <= out_val_next;

            case (state)
                IDLE: begin
                    if (start) begin
                        N_reg <= N_in;
                        K_reg <= K_in;
                        // Reset counters
                        count_blocks <= 0;
                        count_in_block <= 0;
                        current_start <= 1; // Values start from 1
                    end
                end

                SETUP: begin
                    // Calculate block parameters here to use in GENERATE
                    // We use the registered inputs N_reg and K_reg
                    // M = K_reg (if valid)
                    // Q = N_reg / K_reg
                    // R = N_reg % K_reg
                    // We can compute these using combinational logic or sequential.
                    // Since inputs are valid (or error is set), we can compute now.
                    // Division logic is complex in hardware, but K is small (<=16).
                    // We can use a simple loop or explicit logic.
                    // However, SETUP is only 1 cycle. We need to do division in 1 cycle.
                    // 16-bit division is trivial for a synthesizer.
                    if (!error_next) begin
                        M_reg <= K_reg; // M = K
                        // Manual division to ensure no DSP inference if not desired, but standard division is fine.
                        // Or just assign logic:
                        // Q_reg <= N_reg / K_reg; (Verilog division is okay for synthesis if constants/known width)
                        // R_reg <= N_reg % K_reg;
                        // Let's do it explicitly to be safe and clear.
                        // Since K_reg <= 16, we can unroll or just use operator.
                        Q_reg <= N_reg / K_reg;
                        R_reg <= N_reg % K_reg;
                    end
                end

                GENERATE: begin
                    // Update counters for output generation
                    // We update only if we output a value (valid_next is 1)
                    // But we need to handle moving to next block.
                    // If valid_next, we consumed a value in current block.
                    // If count_in_block + 1 >= current_size (next state), we increment block and reset in-block counter.
                    // However, we need current_size to check limit.
                    // current_size depends on count_blocks.
                    // Let's compute current_size combinationally above.
                    // We can update counters unconditionally based on internal logic, 
                    // but we need to be careful not to skip states.
                    
                    // If valid_next (we output), increment in_block counter
                    if (valid_next) begin
                        count_in_block <= count_in_block + 1;
                    end

                    // Check if we finished current block
                    // We need current_size again.
                    reg [4:0] current_size_seq;
                    if (count_blocks < R_reg) current_size_seq = Q_reg + 1;
                    else current_size_seq = Q_reg;

                    // If we just pushed the last value of the block OR we were waiting (valid=0) but need to advance
                    // Actually, if count_in_block reached size, we move to next block on next cycle.
                    // But we need to know if we are done with the block.
                    // We need to check if (count_in_block + 1 == current_size_seq) after increment.
                    // Wait, if we increment count_in_block, we should check if it equals current_size_seq.
                    // But current_size_seq is based on *old* count_blocks.
                    
                    if (valid_next) begin
                        if (count_in_block + 1 == current_size_seq) begin
                            count_blocks <= count_blocks + 1;
                            count_in_block <= 0;
                            // Update current_start for next block
                            // current_start was updated in previous cycle or here?
                            // We update it here.
                            current_start <= current_start + current_size_seq;
                        end
                    end
                    // If we didn't output (gap or finished), logic handles it.
                    // If we are at the end of all blocks, we transition to FINISHED.
                end

                FINISHED: begin
                    // Hold state or reset logic
                end
            endcase
        end
    end

endmodule