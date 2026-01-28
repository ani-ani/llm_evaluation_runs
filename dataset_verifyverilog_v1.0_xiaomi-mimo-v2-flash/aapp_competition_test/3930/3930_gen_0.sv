module CountPowerSubarrays(
    input clk,
    input rst_n,
    input start,
    input signed [7:0] arr [0:15],
    input [3:0] len,
    input [2:0] k,
    output reg [15:0] result,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PREP_POWERS = 3'd1;
    localparam [2:0] COMPUTE_PREFIX = 3'd2;
    localparam [2:0] BUILD_FREQ = 3'd3;
    localparam [2:0] COUNT_SEGMENTS = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Power definitions
    localparam [15:0] MAX_POWER_VAL = 16'd65535;
    localparam [15:0] MIN_POWER_VAL = 16'd65536; // -65536 in 2's complement

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] idx; // General index for loops
    reg [3:0] jdx; // Second index
    reg [3:0] power_idx;
    reg [3:0] freq_idx;
    reg [3:0] num_powers;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd12;

    // Storage for prefix sums (16 entries, 16-bit signed)
    reg signed [15:0] prefix [0:15];
    // Storage for powers (max 17 entries for k=-1 case: 1, -1, 1, -1... but we only need 2)
    reg signed [31:0] powers [0:16]; // 32-bit for intermediate calc
    // Frequency table: stores prefix sum values (16 entries) and their counts (4-bit)
    reg [15:0] freq_prefix [0:15];
    reg [3:0] freq_count [0:15];
    reg [3:0] freq_ptr;

    // Temporary values
    reg signed [15:0] current_prefix;
    reg signed [31:0] target_val;
    reg signed [31:0] check_val;
    reg found;
    reg [15:0] temp_count;

    // Combinational next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = PREP_POWERS;
                else
                    next_state = IDLE;
            end
            PREP_POWERS: begin
                // Just a setup cycle
                next_state = COMPUTE_PREFIX;
            end
            COMPUTE_PREFIX: begin
                if (idx >= len)
                    next_state = BUILD_FREQ;
                else
                    next_state = COMPUTE_PREFIX;
            end
            BUILD_FREQ: begin
                if (idx > len)
                    next_state = COUNT_SEGMENTS;
                else
                    next_state = BUILD_FREQ;
            end
            COUNT_SEGMENTS: begin
                // Main logic loops: outer (i), inner (powers), inner (j)
                // Managed by cycle_count and flags
                // Transition to FINISH when done
                if (cycle_count >= MAX_CYCLES && idx >= len)
                    next_state = FINISH;
                else
                    next_state = COUNT_SEGMENTS;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            idx <= 4'd0;
            jdx <= 4'd0;
            power_idx <= 4'd0;
            freq_idx <= 4'd0;
            cycle_count <= 4'd0;
            num_powers <= 4'd0;
            freq_ptr <= 4'd0;
            // Initialize arrays
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                prefix[i] <= 16'd0;
                powers[i] <= 32'd0;
                freq_prefix[i] <= 16'd0;
                freq_count[i] <= 4'd0;
            end
        end else begin
            done <= 1'b0; // Default done low
            
            case (state)
                IDLE: begin
                    idx <= 4'd0;
                    jdx <= 4'd0;
                    power_idx <= 4'd0;
                    freq_idx <= 4'd0;
                    cycle_count <= 4'd0;
                    freq_ptr <= 4'd0;
                    // Ensure result is cleared when starting new operation
                    if (start) begin
                        result <= 16'd0;
                    end
                end

                PREP_POWERS: begin
                    // Precompute powers of k
                    // k is 3-bit signed. Handle k=0, 1, -1 special cases
                    if (k == 3'b101) begin // -3
                        num_powers <= 4'd10; // 1, -3, 9, -27, 81, -243, 729, -2187, 6561, -19683
                        powers[0] <= 32'd1;
                        powers[1] <= -32'd3;
                        powers[2] <= 32'd9;
                        powers[3] <= -32'd27;
                        powers[4] <= 32'd81;
                        powers[5] <= -32'd243;
                        powers[6] <= 32'd729;
                        powers[7] <= -32'd2187;
                        powers[8] <= 32'd6561;
                        powers[9] <= -32'd19683;
                    end else if (k == 3'b010) begin // 2
                        num_powers <= 4'd17; // 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536
                        powers[0] <= 32'd1;
                        powers[1] <= 32'd2;
                        powers[2] <= 32'd4;
                        powers[3] <= 32'd8;
                        powers[4] <= 32'd16;
                        powers[5] <= 32'd32;
                        powers[6] <= 32'd64;
                        powers[7] <= 32'd128;
                        powers[8] <= 32'd256;
                        powers[9] <= 32'd512;
                        powers[10] <= 32'd1024;
                        powers[11] <= 32'd2048;
                        powers[12] <= 32'd4096;
                        powers[13] <= 32'd8192;
                        powers[14] <= 32'd16384;
                        powers[15] <= 32'd32768;
                        powers[16] <= 32'd65536;
                    end else if (k == 3'b110) begin // -2
                        num_powers <= 4'd16; // 1, -2, 4, -8, 16, -32, 64, -128, 256, -512, 1024, -2048, 4096, -8192, 16384, -32768
                        powers[0] <= 32'd1;
                        powers[1] <= -32'd2;
                        powers[2] <= 32'd4;
                        powers[3] <= -32'd8;
                        powers[4] <= 32'd16;
                        powers[5] <= -32'd32;
                        powers[6] <= 32'd64;
                        powers[7] <= -32'd128;
                        powers[8] <= 32'd256;
                        powers[9] <= -32'd512;
                        powers[10] <= 32'd1024;
                        powers[11] <= -32'd2048;
                        powers[12] <= 32'd4096;
                        powers[13] <= -32'd8192;
                        powers[14] <= 32'd16384;
                        powers[15] <= -32'd32768;
                    end else if (k == 3'b011) begin // 3
                        num_powers <= 4'd11; // 1, 3, 9, 27, 81, 243, 729, 2187, 6561, 19683, 59049
                        powers[0] <= 32'd1;
                        powers[1] <= 32'd3;
                        powers[2] <= 32'd9;
                        powers[3] <= 32'd27;
                        powers[4] <= 32'd81;
                        powers[5] <= 32'd243;
                        powers[6] <= 32'd729;
                        powers[7] <= 32'd2187;
                        powers[8] <= 32'd6561;
                        powers[9] <= 32'd19683;
                        powers[10] <= 32'd59049;
                    end else if (k == 3'b001) begin // 1
                        num_powers <= 4'd1;
                        powers[0] <= 32'd1;
                    end else if (k == 3'b111) begin // -1
                        num_powers <= 4'd2;
                        powers[0] <= 32'd1;
                        powers[1] <= -32'd1;
                    end else begin // k = 0
                        num_powers <= 4'd1;
                        powers[0] <= 32'd1;
                    end
                    idx <= 4'd0;
                end

                COMPUTE_PREFIX: begin
                    // Compute prefix sums: prefix[i] = prefix[i-1] + arr[i]
                    // Note: array is passed as individual wires in interface, accessing here
                    if (idx == 4'd0) begin
                        prefix[0] <= { {8{arr[0][7]}}, arr[0] }; // Sign extend 8 to 16 bits
                    end else if (idx < len) begin
                        prefix[idx] <= prefix[idx-1] + { {8{arr[idx][7]}}, arr[idx] };
                    end
                    idx <= idx + 4'd1;
                end

                BUILD_FREQ: begin
                    // Initialize frequency table with 0 prefix sum at index 0
                    if (idx == 4'd0) begin
                        freq_prefix[0] <= 16'd0;
                        freq_count[0] <= 4'd1;
                        freq_ptr <= 4'd1;
                    end else if (idx <= len) begin
                        // Add prefix sum to frequency table
                        if (freq_ptr < 4'd16) begin
                            freq_prefix[freq_ptr] <= prefix[idx-1];
                            freq_count[freq_ptr] <= 4'd1;
                            freq_ptr <= freq_ptr + 4'd1;
                        end
                    end
                    idx <= idx + 4'd1;
                end

                COUNT_SEGMENTS: begin
                    // Main counting logic
                    // Logic: For each i (0 to len-1), for each power p, check if (prefix[i] - p) exists in previous prefix sums
                    // We iterate i from 1 to len-1 (since j < i)
                    // We use cycle_count to manage nested loops
                    
                    if (cycle_count == 4'd0) begin
                        // Initialize for i=1
                        idx <= 4'd1; // i starts at 1
                        power_idx <= 4'd0;
                        jdx <= 4'd0;
                        cycle_count <= 4'd1;
                    end else begin
                        // Complex loop structure
                        // Outer: i from 1 to len-1
                        // Middle: p from 0 to num_powers-1
                        // Inner: j from 0 to i-1
                        
                        // Check condition for current i, p, j
                        // target = prefix[i] - powers[power_idx]
                        // check = prefix[j]
                        target_val <= prefix[idx] - powers[power_idx];
                        check_val <= prefix[jdx];
                        
                        // Determine next indices
                        if (jdx < idx - 1) begin
                            // Still checking previous prefix sums for current power
                            jdx <= jdx + 4'd1;
                        end else begin
                            // Finished checking all j for this power
                            jdx <= 4'd0;
                            if (power_idx < num_powers - 1) begin
                                // Move to next power
                                power_idx <= power_idx + 4'd1;
                            end else begin
                                // Finished all powers for this i
                                power_idx <= 4'd0;
                                if (idx < len) begin
                                    // Move to next i
                                    idx <= idx + 4'd1;
                                end else begin
                                    // Finished all i
                                    cycle_count <= 4'd15; // Mark finish
                                end
                            end
                        end
                    end

                    // Comparison and counting
                    // Use a separate combinational block or do it here
                    // Since we need to update 'result', do it in sequential block
                    if (cycle_count > 4'd0 && cycle_count < 4'd15) begin
                        if (check_val[15:0] == target_val[15:0]) begin
                            // Match found, check if valid prefix (j < i)
                            // jdx is always < idx here due to loop control
                            result <= result + 16'd1;
                        end
                    end
                    
                    if (cycle_count == 4'd15) begin
                        cycle_count <= 4'd11; // Go to finish
                    end else if (cycle_count > 4'd0 && cycle_count < 4'd11) begin
                        cycle_count <= cycle_count + 4'd1;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    // State transitions to IDLE in next cycle
                end
            endcase
        end
    end

endmodule