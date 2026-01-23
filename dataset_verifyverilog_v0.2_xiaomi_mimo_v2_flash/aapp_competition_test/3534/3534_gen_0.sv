module mirka_optimizer (
    input clk,
    input rst_n,
    input start,
    input [3:0] num_notes,
    input [15:0] note_data,
    input note_valid,
    output reg [15:0] max_correct,
    output reg [31:0] best_k,
    output reg done
);

    // State Encoding
    localparam IDLE      = 5'b00001;
    localparam COLLECT   = 5'b00010;
    localparam CANDIDATE = 5'b00100;
    localparam SIMULATE  = 5'b01000;
    localparam COMPARE   = 5'b01001;
    localparam DONE      = 5'b10000;

    // Registers
    reg [4:0] state;
    reg [3:0] index;           // General purpose index (0-15)
    reg [3:0] index_2;         // Secondary index
    reg [15:0] notes [0:15];   // Buffer for input notes
    reg [31:0] k_values [0:15]; // Buffer for candidate K values
    reg [3:0] k_count;         // Number of unique K candidates
    reg [3:0] current_k_index; // Currently testing K index
    reg signed [15:0] prev_played;
    reg signed [15:0] current_note;
    reg signed [15:0] prev_note;
    reg [15:0] correct_count;
    reg [31:0] current_k;
    reg signed [31:0] temp_diff; // Stores difference for abs calc
    reg signed [31:0] expected;
    reg is_greater;
    reg is_less;
    reg [15:0] abs_low; // For storing lower 16 bits of abs diff
    reg [15:0] abs_high; // For storing upper 16 bits of abs diff
    reg [31:0] candidate_val;
    reg found;
    
    // Helper variables for loop unrolling/logic (not strictly registers but used in logic)
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            max_correct <= 0;
            best_k <= 0;
            index <= 0;
            index_2 <= 0;
            k_count <= 0;
            current_k_index <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        index <= 0; // Reset buffer index
                        state <= COLLECT;
                    end
                end

                COLLECT: begin
                    if (note_valid) begin
                        notes[index] <= note_data;
                        index <= index + 1;
                        if (index + 1 >= num_notes) begin // Collected N notes (0 to N-1)
                            index <= 0;
                            state <= CANDIDATE;
                        end
                    end
                end

                CANDIDATE: begin
                    // Logic: Generate K candidates (|notes[i+1] - notes[i]|) and 0
                    // We iterate i from 0 to num_notes-2
                    // If k_count reaches 16, stop adding new candidates
                    // We need to check uniqueness against existing k_values[0...k_count-1]

                    if (index < num_notes - 1) begin
                        // Calculate abs diff of notes[index+1] - notes[index]
                        // notes are 16-bit signed, diff can be -65535 to +65535 (fits in 17 bits)
                        // Promote to 32-bit for safety
                        temp_diff <= (notes[index+1] - notes[index]);

                        // Check K=0 inclusion (done at the end of candidate generation usually, 
                        // but here we do it before generating diffs to ensure 0 is present if not in diffs)
                        // Actually, it is easier to add 0 first.

                        // Let's restructure: 
                        // Step 1: If index == 0 and k_count == 0, add K=0.
                        // Step 2: Calculate diff, check if unique, add.
                        // Step 3: Move to next index.

                        state <= CANDIDATE; // Stay here

                        if (index == 0 && k_count == 0) begin
                            k_values[0] <= 0;
                            k_count <= 1;
                        end else begin
                            // We are processing diffs
                            // Check uniqueness
                            found <= 0;
                            for (i = 0; i < 16; i = i + 1) begin
                                if (i < k_count && k_values[i] == temp_diff[31:0]) begin
                                    found <= 1;
                                end
                            end

                            if (!found && k_count < 16 && temp_diff[31:0] != 0) begin // 0 is already added or to be added
                                k_values[k_count] <= temp_diff[31:0];
                                k_count <= k_count + 1;
                            end
                            index <= index + 1;
                        end
                    end else begin
                        // Finished collecting diffs
                        index <= 0;
                        current_k_index <= 0;
                        max_correct <= 0;
                        best_k <= 0;
                        state <= SIMULATE;
                    end
                end

                SIMULATE: begin
                    // For each K, simulate playing
                    // If current_k_index >= k_count, go to COMPARE
                    if (current_k_index >= k_count) begin
                        state <= COMPARE;
                    end else begin
                        // Initialize simulation
                        current_k <= k_values[current_k_index];
                        prev_played <= notes[0];
                        correct_count <= 1; // First note always matches
                        index <= 1; // Start from second note
                        state <= SIMULATE; // Stay in simulate loop
                    end
                end

                COMPARE: begin
                    // Update max_correct and best_k
                    if (correct_count > max_correct) begin
                        max_correct <= correct_count;
                        best_k <= current_k;
                    end else if (correct_count == max_correct) begin
                        if (current_k < best_k || (max_correct == 0 && current_k_index == 0)) begin
                            best_k <= current_k;
                        end
                    end

                    // Move to next K or finish
                    current_k_index <= current_k_index + 1;
                    index <= 0; // Reset for next simulation
                    state <= SIMULATE;
                end

                DONE: begin
                    done <= 1;
                    if (!start) state <= IDLE; // Wait for start to go low to reset? Or just stay done.
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Combinational Logic for CANDIDATE Uniqueness Check
    // This is needed because we can't loop inside the sequential block efficiently.
    reg is_unique;
    integer i;
    always @(*) begin
        is_unique = 1;
        // Calculate diff
        diff_calc = notes[index+1] - notes[index];
        if (diff_calc[31]) diff_calc = -diff_calc;

        // Check against existing candidates
        if (state == CANDIDATE && index < num_notes - 1) begin
            for (i = 0; i < 16; i = i + 1) begin
                if (i < k_count && k_values[i] == diff_calc) begin
                    is_unique = 0;
                end
            end
        end
    end

endmodule