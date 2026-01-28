module gcd_table_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire num_valid,
    input wire [31:0] num_in,
    input wire [7:0] table_len,
    output reg result_valid,
    output reg [15:0][31:0] result_array,
    output reg [3:0] result_len,
    output reg busy,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] ACCUMULATE = 3'd1;
    localparam [2:0] PRE_RECONSTRUCT = 3'd2;
    localparam [2:0] RECONSTRUCT = 3'd3;
    localparam [2:0] COMPLETE = 3'd4;
    localparam [2:0] ERROR = 3'd5;

    // Internal signals and registers
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Accumulation phase
    reg [7:0] acc_idx;
    reg [31:0] input_buffer [0:255];  // FIFO for input values
    reg [7:0] input_write_ptr;
    reg [7:0] input_read_ptr;
    reg [7:0] input_count;
    
    // Counter table (frequency tracking)
    reg [3:0] counter_table [0:255];  // Max count = 16
    reg [7:0] counter_idx;
    reg [7:0] counter_max_idx;
    
    // Candidate selection
    reg [7:0] candidate_ptr;
    reg [31:0] current_candidate;
    reg [3:0] candidate_count;
    
    // Result management
    reg [3:0] result_idx;  // How many elements in result
    reg [3:0] valid_idx;   // Index of current valid candidate
    reg [7:0] check_ptr;   // Pointer for checking existing results
    reg [7:0] update_ptr;  // Pointer for counter updates
    reg [3:0] temp_count;
    
    // GCD computation
    reg [31:0] gcd_a;
    reg [31:0] gcd_b;
    reg gcd_start;
    reg gcd_busy;
    reg [31:0] gcd_result;
    reg gcd_done;
    reg [5:0] gcd_iter;  // Iteration counter
    
    // Output pulse generation
    reg result_valid_pulse;
    reg done_pulse;
    
    // Cycle counter for timeout
    reg [12:0] cycle_count;
    localparam [12:0] MAX_CYCLES = 13'd4096;
    
    integer i;

    // GCD Computation Module (iterative Euclidean algorithm)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gcd_busy <= 1'b0;
            gcd_done <= 1'b0;
            gcd_result <= 32'd0;
            gcd_iter <= 6'd0;
        end else begin
            if (gcd_start && !gcd_busy) begin
                gcd_busy <= 1'b1;
                gcd_done <= 1'b0;
                gcd_iter <= 6'd0;
            end else if (gcd_busy) begin
                gcd_iter <= gcd_iter + 6'd1;
                
                // Euclidean algorithm: a mod b
                if (gcd_b != 32'd0) begin
                    if (gcd_a >= gcd_b) begin
                        gcd_a <= gcd_a - gcd_b;
                    end else begin
                        // Swap
                        gcd_a <= gcd_b;
                        gcd_b <= gcd_a;
                    end
                end else begin
                    // Done
                    gcd_result <= gcd_a;
                    gcd_done <= 1'b1;
                    gcd_busy <= 1'b0;
                end
                
                // Safety timeout for GCD
                if (gcd_iter >= 6'd32) begin
                    gcd_result <= (gcd_a > gcd_b) ? gcd_a : gcd_b;
                    gcd_done <= 1'b1;
                    gcd_busy <= 1'b0;
                end
            end else begin
                gcd_done <= 1'b0;
            end
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            busy <= 1'b0;
            done <= 1'b0;
            result_valid <= 1'b0;
            result_len <= 4'd0;
            result_idx <= 4'd0;
            input_write_ptr <= 8'd0;
            input_count <= 8'd0;
            acc_idx <= 8'd0;
            cycle_count <= 13'd0;
            
            // Initialize result array
            for (i = 0; i < 16; i = i + 1) begin
                result_array[i] <= 32'd0;
            end
            
            // Initialize counter table
            for (i = 0; i < 256; i = i + 1) begin
                counter_table[i] <= 4'd0;
            end
            
            // Reset candidate pointers
            candidate_ptr <= 8'd0;
            candidate_count <= 4'd0;
            check_ptr <= 8'd0;
            update_ptr <= 8'd0;
            
        end else begin
            // Default assignments
            result_valid <= result_valid_pulse;
            done <= done_pulse;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    result_valid <= 1'b0;
                    result_len <= 4'd0;
                    result_idx <= 4'd0;
                    input_write_ptr <= 8'd0;
                    input_count <= 8'd0;
                    acc_idx <= 8'd0;
                    cycle_count <= 13'd0;
                    
                    for (i = 0; i < 16; i = i + 1) begin
                        result_array[i] <= 32'd0;
                    end
                    
                    for (i = 0; i < 256; i = i + 1) begin
                        counter_table[i] <= 4'd0;
                    end
                    
                    candidate_ptr <= 8'd0;
                    candidate_count <= 4'd0;
                    check_ptr <= 8'd0;
                    update_ptr <= 8'd0;
                    
                    if (start) begin
                        state <= ACCUMULATE;
                        busy <= 1'b1;
                    end
                end
                
                ACCUMULATE: begin
                    if (num_valid) begin
                        input_buffer[input_write_ptr] <= num_in;
                        input_write_ptr <= input_write_ptr + 8'd1;
                        input_count <= input_count + 8'd1;
                        acc_idx <= acc_idx + 8'd1;
                    end
                    
                    if (acc_idx >= table_len && !num_valid) begin
                        state <= PRE_RECONSTRUCT;
                    end
                end
                
                PRE_RECONSTRUCT: begin
                    // Build counter table from accumulated inputs
                    if (input_read_ptr < input_count) begin
                        // Check if value already in counter table
                        reg found;
                        reg [7:0] idx;
                        reg [7:0] dup_idx;
                        
                        found = 1'b0;
                        for (idx = 8'd0; idx < counter_max_idx && !found; idx = idx + 8'd1) begin
                            if (input_buffer[input_read_ptr] == input_buffer[idx]) begin
                                found = 1'b1;
                                dup_idx = idx;
                            end
                        end
                        
                        if (found) begin
                            // Increment existing counter
                            if (counter_table[dup_idx] < 4'd15) begin
                                counter_table[dup_idx] <= counter_table[dup_idx] + 4'd1;
                            end
                        end else begin
                            // Add new entry
                            counter_table[counter_max_idx] <= 4'd1;
                            counter_max_idx <= counter_max_idx + 8'd1;
                        end
                        
                        input_read_ptr <= input_read_ptr + 8'd1;
                    end else begin
                        state <= RECONSTRUCT;
                        candidate_ptr <= 8'd0;
                        cycle_count <= 13'd0;
                    end
                end
                
                RECONSTRUCT: begin
                    cycle_count <= cycle_count + 13'd1;
                    
                    // Timeout protection
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= ERROR;
                    end
                    
                    // Find next valid candidate
                    if (candidate_ptr < counter_max_idx) begin
                        if (counter_table[candidate_ptr] > 4'd0) begin
                            // Found a candidate
                            current_candidate <= input_buffer[candidate_ptr];
                            candidate_count <= counter_table[candidate_ptr];
                            valid_idx <= candidate_ptr;
                            check_ptr <= 8'd0;
                            
                            // Add to result array
                            if (result_idx < 4'd16) begin
                                result_array[result_idx] <= input_buffer[candidate_ptr];
                                result_idx <= result_idx + 4'd1;
                            end
                            
                            // Update candidate pointer for next iteration
                            candidate_ptr <= candidate_ptr + 8'd1;
                            state <= RECONSTRUCT;
                        end else begin
                            candidate_ptr <= candidate_ptr + 8'd1;
                        end
                    end else begin
                        // All candidates processed
                        if (result_idx >= table_len[3:0]) begin
                            state <= COMPLETE;
                            result_len <= table_len[3:0];
                        end else begin
                            // Not enough candidates found
                            state <= ERROR;
                        end
                    end
                    
                    // Update counters for GCDs with current result
                    if (candidate_count > 4'd0 && check_ptr < counter_max_idx) begin
                        if (counter_table[check_ptr] > 4'd0 && check_ptr != valid_idx) begin
                            // Compute GCD between current_candidate and input_buffer[check_ptr]
                            if (!gcd_busy) begin
                                gcd_a <= current_candidate;
                                gcd_b <= input_buffer[check_ptr];
                                gcd_start <= 1'b1;
                            end else begin
                                gcd_start <= 1'b0;
                            end
                            
                            if (gcd_done) begin
                                // For each element in result array, decrement counter for matching GCD
                                for (i = 0; i < 16; i = i + 1) begin
                                    if (result_array[i] == gcd_result && i < result_idx) begin
                                        if (counter_table[check_ptr] > 4'd0) begin
                                            counter_table[check_ptr] <= counter_table[check_ptr] - 4'd1;
                                        end
                                    end
                                end
                            end
                        end
                        check_ptr <= check_ptr + 8'd1;
                    end else if (candidate_count > 4'd0) begin
                        // Decrement the candidate's own counter
                        counter_table[valid_idx] <= counter_table[valid_idx] - 4'd1;
                    end
                end
                
                COMPLETE: begin
                    result_valid_pulse <= 1'b1;
                    done_pulse <= 1'b1;
                    state <= IDLE;
                    busy <= 1'b0;
                end
                
                ERROR: begin
                    // Timeout or error state
                    result_len <= 4'd0;
                    result_valid <= 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                    busy <= 1'b0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Pulse generation for result_valid and done
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_valid_pulse <= 1'b0;
            done_pulse <= 1'b0;
        end else begin
            result_valid_pulse <= (state == COMPLETE) && (next_state == IDLE);
            done_pulse <= (state == COMPLETE) && (next_state == IDLE);
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = ACCUMULATE;
                else next_state = IDLE;
            end
            ACCUMULATE: begin
                if (acc_idx >= table_len && !num_valid) next_state = PRE_RECONSTRUCT;
                else next_state = ACCUMULATE;
            end
            PRE_RECONSTRUCT: begin
                if (input_read_ptr >= input_count) next_state = RECONSTRUCT;
                else next_state = PRE_RECONSTRUCT;
            end
            RECONSTRUCT: begin
                if (result_idx >= table_len[3:0]) next_state = COMPLETE;
                else if (cycle_count >= MAX_CYCLES) next_state = ERROR;
                else next_state = RECONSTRUCT;
            end
            COMPLETE: next_state = IDLE;
            ERROR: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Initialize unused signals
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            input_read_ptr <= 8'd0;
            counter_max_idx <= 8'd0;
            gcd_start <= 1'b0;
        end
    end

endmodule