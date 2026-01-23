module ludic_sieve(
    input clk,
    input rst_n,
    input start,
    input [5:0] max_value,
    output reg [5:0] result_index,
    output reg [5:0] result_value,
    output reg result_valid,
    output reg done
);

    // State encoding
    localparam IDLE = 3'd0;
    localparam INIT_ARRAY = 3'd1;
    localparam PROCESS_SIEVE = 3'd2;
    localparam OUTPUT_RESULTS = 3'd3;
    localparam DONE = 3'd4;

    // Registers for state machine
    reg [2:0] state;
    reg [2:0] next_state;

    // RAM and control signals
    reg [5:0] array_ram [0:63];  // 64 entries, 6 bits each
    reg valid_ram [0:63];         // Valid flags for each entry
    
    // Temporary registers for processing
    reg [5:0] init_idx;
    reg [5:0] sieve_idx;
    reg [5:0] sieve_val;
    reg [5:0] mark_idx;
    reg [5:0] compact_idx;
    reg [5:0] output_idx;
    reg [5:0] output_count;
    reg [5:0] active_count;
    
    // Phase control for sieve processing
    reg [1:0] sieve_phase; // 0: get value, 1: mark multiples, 2: compact
    reg [1:0] next_sieve_phase;
    
    // Marking loop control
    reg [5:0] mark_counter;
    
    // Compact loop control
    reg [5:0] compact_dest;
    reg compacting;

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = INIT_ARRAY;
            end
            
            INIT_ARRAY: begin
                if (init_idx >= max_value)
                    next_state = PROCESS_SIEVE;
            end
            
            PROCESS_SIEVE: begin
                // Check if sieve is complete
                // After processing first element, if active_count <= 1, done
                if (sieve_phase == 2 && !compacting && active_count <= 1 && sieve_idx > 0) begin
                    next_state = OUTPUT_RESULTS;
                end else if (sieve_phase == 2 && !compacting && sieve_idx >= active_count) begin
                    // Moved past all active elements
                    next_state = OUTPUT_RESULTS;
                end else begin
                    next_state = PROCESS_SIEVE;
                end
            end
            
            OUTPUT_RESULTS: begin
                if (output_count >= active_count)
                    next_state = DONE;
            end
            
            DONE: begin
                next_state = IDLE;  // Auto-reset or stay done
            end
            
            default: next_state = IDLE;
        endcase
    end

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Main processing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all control registers
            init_idx <= 6'd0;
            sieve_idx <= 6'd1;  // Start from index 1 (0 is 1)
            sieve_val <= 6'd0;
            mark_idx <= 6'd0;
            compact_idx <= 6'd0;
            output_idx <= 6'd0;
            output_count <= 6'd0;
            active_count <= 6'd0;
            sieve_phase <= 2'd0;
            next_sieve_phase <= 2'd0;
            mark_counter <= 6'd0;
            compact_dest <= 6'd0;
            compacting <= 1'b0;
            result_index <= 6'd0;
            result_value <= 6'd0;
            result_valid <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        init_idx <= 6'd0;
                        sieve_idx <= 6'd1;
                        sieve_phase <= 2'd0;
                        output_count <= 6'd0;
                        output_idx <= 6'd0;
                        result_index <= 6'd0;
                    end
                end
                
                INIT_ARRAY: begin
                    // Initialize array_ram with 1..max_value and valid flags
                    if (init_idx < max_value) begin
                        array_ram[init_idx] <= init_idx + 6'd1;
                        valid_ram[init_idx] <= 1'b1;
                        init_idx <= init_idx + 6'd1;
                    end else if (init_idx == max_value) begin
                        // Also initialize the last one if needed
                        if (max_value < 64) begin
                            array_ram[init_idx] <= init_idx + 6'd1;
                            valid_ram[init_idx] <= 1'b1;
                        end
                        init_idx <= init_idx + 6'd1;
                    end else begin
                        // Initialize the rest as invalid
                        if (init_idx < 64) begin
                            valid_ram[init_idx] <= 1'b0;
                            init_idx <= init_idx + 6'd1;
                        end else begin
                            active_count <= max_value;
                            sieve_idx <= 6'd1; // Start from second element
                            sieve_phase <= 2'd0;
                        end
                    end
                end
                
                PROCESS_SIEVE: begin
                    case (sieve_phase)
                        2'd0: begin // Get current value
                            if (sieve_idx < active_count) begin
                                // Find next valid element at or after sieve_idx
                                if (valid_ram[sieve_idx]) begin
                                    sieve_val <= array_ram[sieve_idx];
                                    mark_idx <= sieve_idx + 1;  // Start marking from next position
                                    sieve_phase <= 2'd1;
                                end else begin
                                    // Shouldn't happen if compaction works, but handle it
                                    sieve_idx <= sieve_idx + 6'd1;
                                end
                            end else begin
                                // Processed all, go to output
                                sieve_phase <= 2'd2; // Force completion
                            end
                        end
                        
                        2'd1: begin // Mark multiples for removal
                            if (mark_idx < active_count) begin
                                // Check if this position is a multiple of sieve_val
                                if (valid_ram[mark_idx] && ((mark_idx - sieve_idx + 1) % sieve_val == 0)) begin
                                    valid_ram[mark_idx] <= 1'b0;
                                end
                                mark_idx <= mark_idx + 6'd1;
                            end else begin
                                // Done marking, need to compact
                                compact_idx <= 6'd0;
                                compact_dest <= 6'd0;
                                compacting <= 1'b1;
                                sieve_phase <= 2'd2;
                            end
                        end
                        
                        2'd2: begin // Compact the array
                            if (compacting) begin
                                if (compact_idx < active_count) begin
                                    if (valid_ram[compact_idx]) begin
                                        // Keep this element
                                        if (compact_idx != compact_dest) begin
                                            array_ram[compact_dest] <= array_ram[compact_idx];
                                        end
                                        compact_dest <= compact_dest + 6'd1;
                                    end
                                    compact_idx <= compact_idx + 6'd1;
                                end else begin
                                    // Compaction complete
                                    active_count <= compact_dest;
                                    compacting <= 1'b0;
                                    
                                    // Move to next element
                                    if (sieve_idx + 1 < active_count) begin
                                        sieve_idx <= sieve_idx + 6'd1;
                                        sieve_phase <= 2'd0;
                                    end else begin
                                        // All done
                                        sieve_phase <= 2'd0; // Ready for next or completion
                                    end
                                end
                            end else begin
                                // Just finished or skipped, check if continue
                                if (sieve_idx < active_count && sieve_idx + 1 < active_count) begin
                                    sieve_idx <= sieve_idx + 6'd1;
                                    sieve_phase <= 2'd0;
                                end else if (active_count <= 1) begin
                                    // Only first element left, done
                                end else if (sieve_idx >= active_count - 1) begin
                                    // All elements processed
                                end else begin
                                    // Continue
                                    sieve_idx <= sieve_idx + 6'd1;
                                    sieve_phase <= 2'd0;
                                end
                            end
                        end
                    endcase
                end
                
                OUTPUT_RESULTS: begin
                    if (output_count < active_count) begin
                        // Output current element
                        result_index <= output_count;
                        result_value <= array_ram[output_count];
                        result_valid <= 1'b1;
                        output_count <= output_count + 6'd1;
                    end else begin
                        result_valid <= 1'b0;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    result_valid <= 1'b0;
                end
            endcase
        end
    end

endmodule
