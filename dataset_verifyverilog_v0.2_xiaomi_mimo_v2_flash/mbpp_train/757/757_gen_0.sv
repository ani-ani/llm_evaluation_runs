module reverse_pair_counter (
    input clk,
    input rst_n,
    input start,
    input [7:0] str_data [0:4][0:7],
    output reg [3:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam CHECK_REVERSE = 2'b01;
    localparam COUNT_PAIRS = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] state, next_state;

    // Counter for cycles
    reg [2:0] cycle_cnt;
    reg [3:0] pair_cnt;

    // Temporary registers to store reversed strings
    // reversed_str[i] stores the reversed version of str_data[i]
    reg [7:0] reversed_str [0:4][0:7];

    // Helper signals for comparison logic
    wire [7:0] rev_str [0:4][0:7];
    wire [4:0] match_pair [0:4][0:4];

    // Assign reversed strings for the next cycle
    // During CHECK_REVERSE, we build reversed_str incrementally
    // Actually, to compute reverse: reversed_str[i][k] = str_data[i][7-k]
    // The problem suggests computing this takes 8 cycles, one character per cycle per string.
    // This implies a sequential loading process. Let's use cycle_cnt to index the position.

    integer i, j, k;

    // Combinational logic for comparison (used in COUNT_PAIRS state)
    // We need to check if reversed_str[i] == str_data[j] for all i < j

    // Temporary comparison vectors
    wire [0:7] byte_match [0:4][0:4]; // byte_match[i][j][k] is high if bytes match at index k
    wire [0:4] string_match [0:4]; // string_match[i][j] is high if all bytes match

    // Generate comparison logic for all pairs
    // Note: We check reversed_str[i] vs str_data[j]
    // We assume str_data is an input array of bytes.
    // To access str_data in a combinational block, we need to handle the array unpacked type carefully.

    // The instruction says "Compare all unique pairs (i < j) combinationally in counting state"
    // and "Store reversed strings in temporary registers".

    // Since Verilog doesn't easily support arrays of arrays in always_comb for synthesis in all tools,
    // we will use generate blocks or explicit indexing for the comparison.

    // Because 'str_data' is an input port (unpacked array), it cannot be read in an always_comb block directly
    // in some tools unless a wire array is used. However, standard practice for such problems in this format
    // implies treating the inputs as accessible data.

    // Let's define the comparison logic using standard Verilog loops inside generate or explicit assignments.
    // To ensure robustness, we will flatten or use explicit wires if necessary, but here we can use a loop in a combinational block.

    // Helper wires for comparison used in the COUNT_PAIRS state:

    // We need to define the comparison result for all 10 pairs.
    // The result is packed into a single bit vector for ease of counting.

    wire [9:0] pair_matches;
    reg [3:0] sum_matches;

    generate
        genvar gi, gj, gk;
        for (gi = 0; gi < 5; gi = gi + 1) begin : gen_comp_i
            for (gj = gi + 1; gj < 5; gj = gj + 1) begin : gen_comp_j
                wire match;
                // Check if reversed_str[gi] matches str_data[gj]
                // We need to compare 8 bytes.
                assign match = 
                    (reversed_str[gi][0] == str_data[gj][0]) &&
                    (reversed_str[gi][1] == str_data[gj][1]) &&
                    (reversed_str[gi][2] == str_data[gj][2]) &&
                    (reversed_str[gi][3] == str_data[gj][3]) &&
                    (reversed_str[gi][4] == str_data[gj][4]) &&
                    (reversed_str[gi][5] == str_data[gj][5]) &&
                    (reversed_str[gi][6] == str_data[gj][6]) &&
                    (reversed_str[gi][7] == str_data[gj][7]);

                // Map the pair (gi, gj) to a linear index 0..9
                // Total pairs = 5*4/2 = 10.
                // Mapping: (0,1)->0, (0,2)->1, (0,3)->2, (0,4)->3, (1,2)->4, (1,3)->5, (1,4)->6, (2,3)->7, (2,4)->8, (3,4)->9
                // Function to calculate index:
                localparam int pair_idx = (gi * (9 - gi) / 2) + (gj - gi - 1); // Mathematical formula is tricky in generate
                // Manual mapping using localparam inside loop is not possible, so we use logic.
                // Alternatively, we can just use an always_comb block to populate the pair_matches array.
            end
        end
    endgenerate

    // Since generate loop indexing is complex for arbitrary mapping, let's use a standard always_comb block for comparison
    // The instruction "Compare all unique pairs (i < j) combinationally in counting state" implies a combinational block.
    // We will populate an array match_pair[4:0][4:0], but only the lower triangle is needed.

    always @(*) begin
        // Default values
        // Initialize sum matches
        // We will compute the sum of matches directly here or use a loop.

        sum_matches = 0;

        // Loop through all i < j pairs
        for (i = 0; i < 5; i = i + 1) begin
            for (j = i + 1; j < 5; j = j + 1) begin
                // Compare reversed_str[i] with str_data[j]
                // Note: str_data is input array. Access should be valid in combinational logic if treated as a variable.
                if (
                    (reversed_str[i][0] == str_data[j][0]) &&
                    (reversed_str[i][1] == str_data[j][1]) &&
                    (reversed_str[i][2] == str_data[j][2]) &&
                    (reversed_str[i][3] == str_data[j][3]) &&
                    (reversed_str[i][4] == str_data[j][4]) &&
                    (reversed_str[i][5] == str_data[j][5]) &&
                    (reversed_str[i][6] == str_data[j][6]) &&
                    (reversed_str[i][7] == str_data[j][7])
                ) begin
                    sum_matches = sum_matches + 1;
                end
            end
        end
    end

    // State Register and Next State Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Logic for control signals and counters
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_cnt <= 3'b0;
            pair_cnt <= 4'b0;
            done <= 1'b0;
            result <= 4'b0;
            // Reset reversed_str
            for (k = 0; k < 5; k = k + 1) begin
                for (i = 0; i < 8; i = i + 1) begin
                    reversed_str[k][i] <= 8'b0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        cycle_cnt <= 3'b0;
                    end
                end

                CHECK_REVERSE: begin
                    // Compute reverse of strings over 8 cycles
                    // Cycle 0 to 7
                    // cycle_cnt determines which byte we are processing.
                    // cycle_cnt 0: Load byte 7 of all strings to position 0 of reversed_str
                    // cycle_cnt 1: Load byte 6 of all strings to position 1 of reversed_str
                    // ...
                    // cycle_cnt 7: Load byte 0 of all strings to position 7 of reversed_str

                    // Actually, to meet latency requirements, we do this sequentially or in parallel?
                    // "For each string, compute its reverse in parallel stages"
                    // "... takes 8 cycles, one character per cycle per string"
                    // This phrasing is ambiguous.
                    // "Parallel stages" might mean we have 5 parallel "streams" but each takes 8 cycles.
                    // So in each cycle, we process one character index for ALL strings.

                    if (cycle_cnt < 3'd8) begin
                        // cycle_cnt = k. We process str_data[i][7-k] -> reversed_str[i][k]
                        for (i = 0; i < 5; i = i + 1) begin
                            reversed_str[i][cycle_cnt] <= str_data[i][7 - cycle_cnt];
                        end
                        cycle_cnt <= cycle_cnt + 1;
                    end
                end

                COUNT_PAIRS: begin
                    // The comparison logic is combinational (sum_matches)
                    // We just capture the result here.
                    // Since the comparison logic depends on reversed_str which was updated in previous state,
                    // the combinational logic will settle with the correct values.
                    // We need 1 cycle to latch the result.
                    result <= sum_matches;
                    done <= 1'b1;
                end

                DONE: begin
                    // Hold result and done high until start is asserted again (or reset)
                    // Requirement: "Hold result until next start"
                    // If start is asserted, we should transition to IDLE (handled by next_state) and reset internal logic.
                    if (start) begin
                        done <= 1'b0; // Prepare for next run
                        result <= 4'b0;
                    end
                end
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = CHECK_REVERSE;
                else next_state = IDLE;
            end

            CHECK_REVERSE: begin
                // Requires 8 cycles (cycle_cnt 0..7).
                // When cycle_cnt reaches 8, we are done.
                if (cycle_cnt == 3'd7) next_state = COUNT_PAIRS; // Wait for last update to take effect
                // Actually, if cycle_cnt increments to 8 on the clock edge, we transition.
                // Let's say we check if cycle_cnt == 3'd8 in combinational logic.
                // But cycle_cnt is a register. In the always block, if cycle_cnt == 7, we set next_cycle = 8.
                // Wait, in the always block for state transition, we should look at the current state.
                // We need to be in CHECK_REVERSE for 8 cycles.
                // Let's define that we transition when we finish the 8th cycle.
                // Cycle 0: Reversing index 7 -> 0
                // ...
                // Cycle 7: Reversing index 0 -> 7
                // After Cycle 7, reversed_str is fully computed.
                // So we need to wait for cycle_cnt to be 8 (meaning we just finished cycle 7).

                if (cycle_cnt == 3'd7) next_state = COUNT_PAIRS;
                else next_state = CHECK_REVERSE;
            end

            COUNT_PAIRS: begin
                // One cycle to compute combinational sum and latch result
                next_state = DONE;
            end

            DONE: begin
                // Hold state
                if (start) next_state = IDLE;
                else next_state = DONE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule