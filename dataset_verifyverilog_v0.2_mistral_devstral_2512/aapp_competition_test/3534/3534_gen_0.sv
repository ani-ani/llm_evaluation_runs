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

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        COLLECT,
        CANDIDATE,
        SIMULATE,
        COMPARE,
        DONE
    } state_t;
    state_t state, next_state;

    // Internal registers
    reg [15:0] notes [0:15];
    reg [31:0] k_values [0:15];
    reg [3:0] note_index;
    reg [3:0] k_count;
    reg [3:0] current_k_index;
    reg [15:0] current_correct;
    reg [31:0] current_k;
    reg [3:0] sim_index;
    reg [15:0] prev_played;
    reg [15:0] correct_count;
    reg [3:0] i, j;
    reg [31:0] diff;
    reg [15:0] expected;
    reg [15:0] played;
    reg [15:0] temp_correct;
    reg [31:0] temp_k;
    reg k_exists;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            note_index <= 0;
            k_count <= 0;
            current_k_index <= 0;
            current_correct <= 0;
            current_k <= 0;
            sim_index <= 0;
            prev_played <= 0;
            correct_count <= 0;
            max_correct <= 0;
            best_k <= 0;
            done <= 0;
            for (i = 0; i < 16; i = i + 1) begin
                notes[i] <= 0;
                k_values[i] <= 0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = COLLECT;
            end
            COLLECT: begin
                if (note_index == num_notes - 1 && note_valid) next_state = CANDIDATE;
            end
            CANDIDATE: begin
                if (k_count > 0) next_state = SIMULATE;
                else next_state = DONE;
            end
            SIMULATE: begin
                if (sim_index == num_notes - 1) next_state = COMPARE;
            end
            COMPARE: begin
                if (current_k_index == k_count - 1) next_state = DONE;
                else next_state = SIMULATE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // State actions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            case (state)
                IDLE: begin
                    note_index <= 0;
                    k_count <= 0;
                    current_k_index <= 0;
                    current_correct <= 0;
                    current_k <= 0;
                    sim_index <= 0;
                    prev_played <= 0;
                    correct_count <= 0;
                    max_correct <= 0;
                    best_k <= 0;
                    done <= 0;
                end
                COLLECT: begin
                    if (note_valid) begin
                        notes[note_index] <= note_data;
                        note_index <= note_index + 1;
                    end
                end
                CANDIDATE: begin
                    // Generate K candidates
                    k_count <= 0;
                    k_values[0] <= 0; // Always include K=0
                    k_count <= 1;
                    for (i = 0; i < num_notes - 1; i = i + 1) begin
                        diff = $signed(notes[i+1]) - $signed(notes[i]);
                        if (diff < 0) diff = -diff;
                        if (diff != 0) begin
                            k_exists = 0;
                            for (j = 0; j < k_count; j = j + 1) begin
                                if (k_values[j] == diff) k_exists = 1;
                            end
                            if (!k_exists && k_count < 16) begin
                                k_values[k_count] <= diff;
                                k_count <= k_count + 1;
                            end
                        end
                    end
                    current_k_index <= 0;
                    current_k <= k_values[0];
                    sim_index <= 0;
                    prev_played <= notes[0];
                    correct_count <= 1;
                end
                SIMULATE: begin
                    if (sim_index < num_notes - 1) begin
                        // Determine expected note
                        if ($signed(notes[sim_index+1]) > $signed(notes[sim_index])) begin
                            expected = $signed(prev_played) + $signed(current_k);
                        end else if ($signed(notes[sim_index+1]) < $signed(notes[sim_index])) begin
                            expected = $signed(prev_played) - $signed(current_k);
                        end else begin
                            expected = prev_played;
                        end
                        // Check match
                        if (expected == notes[sim_index+1]) begin
                            correct_count <= correct_count + 1;
                        end
                        prev_played <= expected;
                        sim_index <= sim_index + 1;
                    end
                end
                COMPARE: begin
                    // Compare with current best
                    if (correct_count > max_correct) begin
                        max_correct <= correct_count;
                        best_k <= current_k;
                    end
                    // Move to next K
                    current_k_index <= current_k_index + 1;
                    if (current_k_index < k_count) begin
                        current_k <= k_values[current_k_index];
                        sim_index <= 0;
                        prev_played <= notes[0];
                        correct_count <= 1;
                    end
                end
                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule