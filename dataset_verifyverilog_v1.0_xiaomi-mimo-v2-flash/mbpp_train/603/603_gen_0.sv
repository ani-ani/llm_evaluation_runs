module ludic_sieve (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    output reg done,
    output reg result_valid,
    output reg [3:0] result_count,
    output reg [3:0] result_data_0,
    output reg [3:0] result_data_1,
    output reg [3:0] result_data_2,
    output reg [3:0] result_data_3,
    output reg [3:0] result_data_4,
    output reg [3:0] result_data_5,
    output reg [3:0] result_data_6,
    output reg [3:0] result_data_7,
    output reg [3:0] result_data_8,
    output reg [3:0] result_data_9,
    output reg result_data_valid
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] INIT    = 3'd1;
    localparam [2:0] SIEVE   = 3'd2;
    localparam [2:0] OUTPUT  = 3'd3;
    localparam [2:0] DONE    = 3'd4;

    // Internal registers for array (16 elements, 4-bit each)
    reg [3:0] array [0:15];
    reg [3:0] array_next [0:15];
    
    // Counter and index registers
    reg [2:0] state;
    reg [2:0] state_next;
    reg [3:0] sieve_pos;        // Position in array for current sieve step
    reg [3:0] sieve_pos_next;
    reg [3:0] sieve_step;       // Step value (from array[sieve_pos])
    reg [3:0] sieve_step_next;
    reg [3:0] scan_pos;         // Scanning position within sieve
    reg [3:0] scan_pos_next;
    reg [3:0] shift_pos;        // Position for shifting
    reg [3:0] shift_pos_next;
    reg [3:0] valid_count;      // Count of valid elements
    reg [3:0] valid_count_next;
    reg [3:0] output_idx;       // Index for output
    reg [3:0] output_idx_next;
    reg [3:0] cycle_count;      // Safety counter
    reg [3:0] cycle_count_next;
    
    // Output registers
    reg done_next;
    reg result_valid_next;
    reg [3:0] result_count_next;
    reg [3:0] result_data_0_next;
    reg [3:0] result_data_1_next;
    reg [3:0] result_data_2_next;
    reg [3:0] result_data_3_next;
    reg [3:0] result_data_4_next;
    reg [3:0] result_data_5_next;
    reg [3:0] result_data_6_next;
    reg [3:0] result_data_7_next;
    reg [3:0] result_data_8_next;
    reg [3:0] result_data_9_next;
    reg result_data_valid_next;

    // Sequential logic for state transitions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sieve_pos <= 4'd0;
            sieve_step <= 4'd0;
            scan_pos <= 4'd0;
            shift_pos <= 4'd0;
            valid_count <= 4'd0;
            output_idx <= 4'd0;
            cycle_count <= 4'd0;
            done <= 1'b0;
            result_valid <= 1'b0;
            result_count <= 4'd0;
            result_data_0 <= 4'd0;
            result_data_1 <= 4'd0;
            result_data_2 <= 4'd0;
            result_data_3 <= 4'd0;
            result_data_4 <= 4'd0;
            result_data_5 <= 4'd0;
            result_data_6 <= 4'd0;
            result_data_7 <= 4'd0;
            result_data_8 <= 4'd0;
            result_data_9 <= 4'd0;
            result_data_valid <= 1'b0;
            // Initialize array
            array[0] <= 4'd1;
            array[1] <= 4'd2;
            array[2] <= 4'd3;
            array[3] <= 4'd4;
            array[4] <= 4'd5;
            array[5] <= 4'd6;
            array[6] <= 4'd7;
            array[7] <= 4'd8;
            array[8] <= 4'd9;
            array[9] <= 4'd10;
            array[10] <= 4'd11;
            array[11] <= 4'd12;
            array[12] <= 4'd13;
            array[13] <= 4'd14;
            array[14] <= 4'd15;
            array[15] <= 4'd16;
        end else begin
            state <= state_next;
            sieve_pos <= sieve_pos_next;
            sieve_step <= sieve_step_next;
            scan_pos <= scan_pos_next;
            shift_pos <= shift_pos_next;
            valid_count <= valid_count_next;
            output_idx <= output_idx_next;
            cycle_count <= cycle_count_next;
            done <= done_next;
            result_valid <= result_valid_next;
            result_count <= result_count_next;
            result_data_0 <= result_data_0_next;
            result_data_1 <= result_data_1_next;
            result_data_2 <= result_data_2_next;
            result_data_3 <= result_data_3_next;
            result_data_4 <= result_data_4_next;
            result_data_5 <= result_data_5_next;
            result_data_6 <= result_data_6_next;
            result_data_7 <= result_data_7_next;
            result_data_8 <= result_data_8_next;
            result_data_9 <= result_data_9_next;
            result_data_valid <= result_data_valid_next;
            // Update array
            array[0] <= array_next[0];
            array[1] <= array_next[1];
            array[2] <= array_next[2];
            array[3] <= array_next[3];
            array[4] <= array_next[4];
            array[5] <= array_next[5];
            array[6] <= array_next[6];
            array[7] <= array_next[7];
            array[8] <= array_next[8];
            array[9] <= array_next[9];
            array[10] <= array_next[10];
            array[11] <= array_next[11];
            array[12] <= array_next[12];
            array[13] <= array_next[13];
            array[14] <= array_next[14];
            array[15] <= array_next[15];
        end
    end

    // Combinational logic for next state and outputs
    always @(*) begin
        // Default assignments
        state_next = state;
        sieve_pos_next = sieve_pos;
        sieve_step_next = sieve_step;
        scan_pos_next = scan_pos;
        shift_pos_next = shift_pos;
        valid_count_next = valid_count;
        output_idx_next = output_idx;
        cycle_count_next = cycle_count;
        done_next = 1'b0;
        result_valid_next = 1'b0;
        result_count_next = result_count;
        result_data_0_next = result_data_0;
        result_data_1_next = result_data_1;
        result_data_2_next = result_data_2;
        result_data_3_next = result_data_3;
        result_data_4_next = result_data_4;
        result_data_5_next = result_data_5;
        result_data_6_next = result_data_6;
        result_data_7_next = result_data_7;
        result_data_8_next = result_data_8;
        result_data_9_next = result_data_9;
        result_data_valid_next = result_data_valid;
        
        // Array next state default
        for (int i = 0; i < 16; i = i + 1) begin
            array_next[i] = array[i];
        end

        case (state)
            IDLE: begin
                done_next = 1'b0;
                result_valid_next = 1'b0;
                result_data_valid_next = 1'b0;
                if (start) begin
                    state_next = INIT;
                    sieve_pos_next = 4'd1;  // Start from position 1 (value 2)
                    valid_count_next = n;    // We want n Ludic numbers
                    if (n > 4'd10) valid_count_next = 4'd10;  // Cap at 10
                    cycle_count_next = 4'd0;
                end
            end

            INIT: begin
                // Reset array to initial state (1-16)
                array_next[0] = 4'd1;
                array_next[1] = 4'd2;
                array_next[2] = 4'd3;
                array_next[3] = 4'd4;
                array_next[4] = 4'd5;
                array_next[5] = 4'd6;
                array_next[6] = 4'd7;
                array_next[7] = 4'd8;
                array_next[8] = 4'd9;
                array_next[9] = 4'd10;
                array_next[10] = 4'd11;
                array_next[11] = 4'd12;
                array_next[12] = 4'd13;
                array_next[13] = 4'd14;
                array_next[14] = 4'd15;
                array_next[15] = 4'd16;
                
                sieve_pos_next = 4'd1;
                scan_pos_next = 4'd0;
                shift_pos_next = 4'd0;
                state_next = SIEVE;
            end

            SIEVE: begin
                cycle_count_next = cycle_count + 4'd1;
                
                // Check if we've exceeded the array or cycle limit
                if (sieve_pos >= 4'd15 || cycle_count >= 4'd15) begin
                    state_next = OUTPUT;
                    output_idx_next = 4'd0;
                end else begin
                    // Get step value from current position
                    sieve_step_next = array[sieve_pos];
                    
                    // Check if step is valid (non-zero)
                    if (sieve_step_next > 4'd0 && sieve_step_next < 4'd16) begin
                        scan_pos_next = sieve_pos + sieve_step_next;
                        state_next = SIEVE;  // Continue to scan
                    end else begin
                        // Skip to next position
                        sieve_pos_next = sieve_pos + 4'd1;
                        state_next = SIEVE;
                    end
                end
                
                // Combinational removal logic
                // Remove elements at positions sieve_pos + n * sieve_step
                if (scan_pos >= sieve_pos && scan_pos < 4'd16) begin
                    // Check if position has valid data
                    if (array[scan_pos] > 4'd0) begin
                        // Mark for removal by shifting subsequent elements
                        // We'll do a bubble-shift: move all later elements down
                        for (int i = scan_pos; i < 15; i = i + 1) begin
                            array_next[i] = array[i + 1];
                        end
                        array_next[15] = 4'd0;  // Clear last position
                        
                        // Stay at same scan position to check next removal
                        scan_pos_next = scan_pos;
                    end else begin
                        // Move to next potential removal position
                        scan_pos_next = scan_pos + sieve_step;
                    end
                end
                
                // If we've finished scanning this sieve position
                if (scan_pos >= 4'd16) begin
                    sieve_pos_next = sieve_pos + 4'd1;
                    scan_pos_next = sieve_pos + 4'd1;  // Reset for next
                end
            end

            OUTPUT: begin
                // Output valid Ludic numbers (non-zero values)
                if (output_idx < 4'd10) begin
                    case (output_idx)
                        4'd0: begin result_data_0_next = array[0]; result_data_valid_next = 1'b1; end
                        4'd1: result_data_1_next = array[1];
                        4'd2: result_data_2_next = array[2];
                        4'd3: result_data_3_next = array[3];
                        4'd4: result_data_4_next = array[4];
                        4'd5: result_data_5_next = array[5];
                        4'd6: result_data_6_next = array[6];
                        4'd7: result_data_7_next = array[7];
                        4'd8: result_data_8_next = array[8];
                        4'd9: result_data_9_next = array[9];
                        default: ;
                    endcase
                    output_idx_next = output_idx + 4'd1;
                end else begin
                    // Count actual valid elements (non-zero)
                    result_count_next = 4'd0;
                    if (array[0] > 4'd0) result_count_next = result_count_next + 4'd1;
                    if (array[1] > 4'd0) result_count_next = result_count_next + 4'd1;
                    if (array[2] > 4'd0) result_count_next = result_count_next + 4'd1;
                    if (array[3] > 4'd0) result_count_next = result_count_next + 4'd1;
                    if (array[4] > 4'd0) result_count_next = result_count_next + 4'd1;
                    if (array[5] > 4'd0) result_count_next = result_count_next + 4'd1;
                    if (array[6] > 4'd0) result_count_next = result_count_next + 4'd1;
                    if (array[7] > 4'd0) result_count_next = result_count_next + 4'd1;
                    if (array[8] > 4'd0) result_count_next = result_count_next + 4'd1;
                    if (array[9] > 4'd0) result_count_next = result_count_next + 4'd1;
                    
                    result_valid_next = 1'b1;
                    state_next = DONE;
                end
            end

            DONE: begin
                done_next = 1'b1;
                result_valid_next = result_valid;
                result_data_valid_next = result_data_valid;
                state_next = IDLE;
            end

            default: begin
                state_next = IDLE;
                sieve_pos_next = 4'd0;
                sieve_step_next = 4'd0;
                scan_pos_next = 4'd0;
                shift_pos_next = 4'd0;
                valid_count_next = 4'd0;
                output_idx_next = 4'd0;
                cycle_count_next = 4'd0;
                done_next = 1'b0;
                result_valid_next = 1'b0;
                result_data_valid_next = 1'b0;
            end
        endcase
    end

endmodule