module deduce_common (
    input clk,
    input rst_n,
    input start,
    input [3:0] n_a,
    input [7:0][1:0][3:0] set_a,
    input [3:0] m_b,
    input [7:0][1:0][3:0] set_b,
    output reg [3:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        PROCESSING,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal signals
    reg [3:0] candidates [0:8]; // Up to 9 candidates (1-9)
    reg [3:0] candidate_count;
    reg [3:0] candidate_temp;
    reg [3:0] i, j, k;
    reg [3:0] shared_num;
    reg [3:0] pair_a_num1, pair_a_num2;
    reg [3:0] pair_b_num1, pair_b_num2;
    reg [3:0] intersection_a [0:7]; // For each pair in A
    reg [3:0] intersection_b [0:7]; // For each pair in B
    reg [3:0] intersection_count_a [0:7];
    reg [3:0] intersection_count_b [0:7];
    reg determinism_a, determinism_b;
    reg [3:0] temp_intersection [0:8];
    reg [3:0] temp_count;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            result <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = PROCESSING;
                else next_state = IDLE;
            end
            PROCESSING: begin
                next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
                else next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Main processing logic (combinational)
    always @(*) begin
        if (current_state == PROCESSING) begin
            // Initialize
            candidate_count = 0;
            for (k = 0; k < 9; k = k + 1) begin
                candidates[k] = 0;
            end

            // Step 1: Find all candidate numbers
            for (i = 0; i < n_a; i = i + 1) begin
                if (set_a[i][0] != 0 && set_a[i][1] != 0) begin
                    pair_a_num1 = set_a[i][0];
                    pair_a_num2 = set_a[i][1];
                    for (j = 0; j < m_b; j = j + 1) begin
                        if (set_b[j][0] != 0 && set_b[j][1] != 0) begin
                            pair_b_num1 = set_b[j][0];
                            pair_b_num2 = set_b[j][1];
                            // Check if exactly one number is shared
                            if ((pair_a_num1 == pair_b_num1 || pair_a_num1 == pair_b_num2) &&
                                (pair_a_num2 != pair_b_num1 && pair_a_num2 != pair_b_num2)) begin
                                shared_num = pair_a_num1;
                            end else if ((pair_a_num2 == pair_b_num1 || pair_a_num2 == pair_b_num2) &&
                                        (pair_a_num1 != pair_b_num1 && pair_a_num1 != pair_b_num2)) begin
                                shared_num = pair_a_num2;
                            end else begin
                                shared_num = 0;
                            end
                            // Add to candidates if valid
                            if (shared_num != 0) begin
                                // Check if already in candidates
                                candidate_temp = 0;
                                for (k = 0; k < candidate_count; k = k + 1) begin
                                    if (candidates[k] == shared_num) begin
                                        candidate_temp = 1;
                                    end
                                end
                                if (!candidate_temp && candidate_count < 9) begin
                                    candidates[candidate_count] = shared_num;
                                    candidate_count = candidate_count + 1;
                                end
                            end
                        end
                    end
                end
            end

            // Step 2: Check candidate count
            if (candidate_count == 1) begin
                result = candidates[0];
            end else begin
                // Step 3: Check determinism
                determinism_a = 1;
                determinism_b = 1;

                // For each pair in A, find intersection with all pairs in B
                for (i = 0; i < n_a; i = i + 1) begin
                    if (set_a[i][0] != 0 && set_a[i][1] != 0) begin
                        // Initialize intersection
                        temp_count = 0;
                        for (k = 0; k < 9; k = k + 1) begin
                            temp_intersection[k] = 0;
                        end
                        // Find possible shared numbers
                        for (j = 0; j < m_b; j = j + 1) begin
                            if (set_b[j][0] != 0 && set_b[j][1] != 0) begin
                                pair_a_num1 = set_a[i][0];
                                pair_a_num2 = set_a[i][1];
                                pair_b_num1 = set_b[j][0];
                                pair_b_num2 = set_b[j][1];
                                // Check if exactly one number is shared
                                if ((pair_a_num1 == pair_b_num1 || pair_a_num1 == pair_b_num2) &&
                                    (pair_a_num2 != pair_b_num1 && pair_a_num2 != pair_b_num2)) begin
                                    shared_num = pair_a_num1;
                                end else if ((pair_a_num2 == pair_b_num1 || pair_a_num2 == pair_b_num2) &&
                                            (pair_a_num1 != pair_b_num1 && pair_a_num1 != pair_b_num2)) begin
                                    shared_num = pair_a_num2;
                                end else begin
                                    shared_num = 0;
                                end
                                // Add to intersection if valid
                                if (shared_num != 0) begin
                                    // Check if already in intersection
                                    candidate_temp = 0;
                                    for (k = 0; k < temp_count; k = k + 1) begin
                                        if (temp_intersection[k] == shared_num) begin
                                            candidate_temp = 1;
                                        end
                                    end
                                    if (!candidate_temp && temp_count < 9) begin
                                        temp_intersection[temp_count] = shared_num;
                                        temp_count = temp_count + 1;
                                    end
                                end
                            end
                        end
                        // Store intersection
                        intersection_count_a[i] = temp_count;
                        for (k = 0; k < temp_count; k = k + 1) begin
                            intersection_a[i * 9 + k] = temp_intersection[k];
                        end
                        // Check determinism
                        if (temp_count != 1) begin
                            determinism_a = 0;
                        end
                    end
                end

                // For each pair in B, find intersection with all pairs in A
                for (j = 0; j < m_b; j = j + 1) begin
                    if (set_b[j][0] != 0 && set_b[j][1] != 0) begin
                        // Initialize intersection
                        temp_count = 0;
                        for (k = 0; k < 9; k = k + 1) begin
                            temp_intersection[k] = 0;
                        end
                        // Find possible shared numbers
                        for (i = 0; i < n_a; i = i + 1) begin
                            if (set_a[i][0] != 0 && set_a[i][1] != 0) begin
                                pair_a_num1 = set_a[i][0];
                                pair_a_num2 = set_a[i][1];
                                pair_b_num1 = set_b[j][0];
                                pair_b_num2 = set_b[j][1];
                                // Check if exactly one number is shared
                                if ((pair_b_num1 == pair_a_num1 || pair_b_num1 == pair_a_num2) &&
                                    (pair_b_num2 != pair_a_num1 && pair_b_num2 != pair_a_num2)) begin
                                    shared_num = pair_b_num1;
                                end else if ((pair_b_num2 == pair_a_num1 || pair_b_num2 == pair_a_num2) &&
                                            (pair_b_num1 != pair_a_num1 && pair_b_num1 != pair_a_num2)) begin
                                    shared_num = pair_b_num2;
                                end else begin
                                    shared_num = 0;
                                end
                                // Add to intersection if valid
                                if (shared_num != 0) begin
                                    // Check if already in intersection
                                    candidate_temp = 0;
                                    for (k = 0; k < temp_count; k = k + 1) begin
                                        if (temp_intersection[k] == shared_num) begin
                                            candidate_temp = 1;
                                        end
                                    end
                                    if (!candidate_temp && temp_count < 9) begin
                                        temp_intersection[temp_count] = shared_num;
                                        temp_count = temp_count + 1;
                                    end
                                end
                            end
                        end
                        // Store intersection
                        intersection_count_b[j] = temp_count;
                        for (k = 0; k < temp_count; k = k + 1) begin
                            intersection_b[j * 9 + k] = temp_intersection[k];
                        end
                        // Check determinism
                        if (temp_count != 1) begin
                            determinism_b = 0;
                        end
                    end
                end

                // Determine result
                if (determinism_a && determinism_b) begin
                    result = 0;
                end else begin
                    result = 15; // -1
                end
            end
            done = 1;
        end else begin
            done = 0;
        end
    end

endmodule