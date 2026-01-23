module team_selection (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [2:0] p,
    input [2:0] s,
    input [7:0] a [0:7],
    input [7:0] b [0:7],
    output reg [15:0] max_strength,
    output reg [2:0] prog_indices [0:7],
    output reg [2:0] sports_indices [0:7],
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        PREPARE,
        GENERATE_COMBOS,
        EVALUATE,
        UPDATE,
        DONE
    } state_t;

    state_t state, next_state;

    // Counters and masks
    reg [7:0] prog_mask;
    reg [7:0] sports_mask;
    reg [7:0] prog_counter;
    reg [7:0] sports_counter;
    reg [7:0] student_counter;

    // Current strength calculation
    reg [15:0] current_strength;
    reg [15:0] prog_sum;
    reg [15:0] sports_sum;

    // Best masks storage
    reg [7:0] best_prog_mask;
    reg [7:0] best_sports_mask;

    // Helper signals
    reg [7:0] remaining_students;
    reg [7:0] temp_mask;
    reg [7:0] temp_counter;

    // Initialize outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_strength <= 0;
            done <= 0;
            for (int i = 0; i < 8; i++) begin
                prog_indices[i] <= 0;
                sports_indices[i] <= 0;
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all internal signals
            prog_mask <= 0;
            sports_mask <= 0;
            prog_counter <= 0;
            sports_counter <= 0;
            student_counter <= 0;
            current_strength <= 0;
            prog_sum <= 0;
            sports_sum <= 0;
            best_prog_mask <= 0;
            best_sports_mask <= 0;
            remaining_students <= 0;
            temp_mask <= 0;
            temp_counter <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        next_state = PREPARE;
                    end else begin
                        next_state = IDLE;
                    end
                end

                PREPARE: begin
                    // Initialize counters and masks
                    prog_mask <= 0;
                    sports_mask <= 0;
                    prog_counter <= 0;
                    sports_counter <= 0;
                    student_counter <= 0;
                    current_strength <= 0;
                    prog_sum <= 0;
                    sports_sum <= 0;
                    best_prog_mask <= 0;
                    best_sports_mask <= 0;
                    max_strength <= 0;
                    done <= 0;
                    next_state = GENERATE_COMBOS;
                end

                GENERATE_COMBOS: begin
                    // Generate next programming mask with exactly p bits set
                    if (prog_counter == 0) begin
                        prog_mask <= (1 << p) - 1;
                    end else begin
                        // Find next combination
                        temp_mask = prog_mask;
                        temp_counter = prog_counter;
                        repeat (8) begin
                            temp_mask = temp_mask + 1;
                            if (count_ones(temp_mask) == p) begin
                                prog_mask <= temp_mask;
                                temp_counter = temp_counter + 1;
                            end
                        end
                        prog_counter <= temp_counter;
                    end

                    // Check if we've exhausted all programming combinations
                    if (prog_counter >= (1 << n) && count_ones(prog_mask) != p) begin
                        next_state = DONE;
                    end else begin
                        // Generate sports mask from remaining students
                        remaining_students = ~prog_mask & ((1 << n) - 1);
                        sports_mask <= 0;
                        sports_counter <= 0;
                        next_state = EVALUATE;
                    end
                end

                EVALUATE: begin
                    // Calculate programming sum
                    prog_sum = 0;
                    for (int i = 0; i < 8; i++) begin
                        if (prog_mask[i]) begin
                            prog_sum = prog_sum + a[i];
                        end
                    end

                    // Calculate sports sum
                    sports_sum = 0;
                    for (int i = 0; i < 8; i++) begin
                        if (sports_mask[i] && remaining_students[i]) begin
                            sports_sum = sports_sum + b[i];
                        end
                    end

                    current_strength = prog_sum + sports_sum;
                    next_state = UPDATE;
                end

                UPDATE: begin
                    // Compare and update if better
                    if (current_strength > max_strength) begin
                        max_strength <= current_strength;
                        best_prog_mask <= prog_mask;
                        best_sports_mask <= sports_mask;
                    end

                    // Generate next sports mask
                    if (sports_counter == 0) begin
                        sports_mask <= (1 << s) - 1;
                    end else begin
                        // Find next combination in remaining students
                        temp_mask = sports_mask;
                        temp_counter = sports_counter;
                        repeat (8) begin
                            temp_mask = (temp_mask + 1) & remaining_students;
                            if (count_ones(temp_mask) == s) begin
                                sports_mask <= temp_mask;
                                temp_counter = temp_counter + 1;
                            end
                        end
                        sports_counter <= temp_counter;
                    end

                    // Check if we've exhausted sports combinations for current programming mask
                    if (sports_counter >= (1 << (n - p)) && count_ones(sports_mask) != s) begin
                        prog_counter <= prog_counter + 1;
                        next_state = GENERATE_COMBOS;
                    end else begin
                        next_state = EVALUATE;
                    end
                end

                DONE: begin
                    // Output the best indices
                    student_counter = 0;
                    for (int i = 0; i < 8; i++) begin
                        if (best_prog_mask[i]) begin
                            prog_indices[student_counter] <= i;
                            student_counter = student_counter + 1;
                        end
                    end

                    student_counter = 0;
                    for (int i = 0; i < 8; i++) begin
                        if (best_sports_mask[i]) begin
                            sports_indices[student_counter] <= i;
                            student_counter = student_counter + 1;
                        end
                    end

                    done <= 1;
                    next_state = IDLE;
                end

                default: next_state = IDLE;
            endcase
        end
    end

    // Helper function to count number of 1s in a bit vector
    function automatic integer count_ones;
        input [7:0] vec;
        integer i;
        integer count;
        begin
            count = 0;
            for (i = 0; i < 8; i = i + 1) begin
                if (vec[i]) count = count + 1;
            end
            count_ones = count;
        end
    endfunction

endmodule