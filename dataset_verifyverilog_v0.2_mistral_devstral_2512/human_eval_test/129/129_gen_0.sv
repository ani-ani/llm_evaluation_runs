module minPath(
    input clk,
    input rst_n,
    input start,
    input [1:0][1:0][7:0] grid,
    input [3:0] k,
    output reg [9:0][7:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        INIT,
        PROCESS_STEP,
        CHECK_COMPLETE,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [7:0] current_path [9:0];
    reg [1:0] current_pos [1:0];
    reg [3:0] path_length;
    reg [7:0] min_val;
    reg [1:0] min_pos [1:0];
    reg [7:0] candidate_path [9:0];
    reg [1:0] candidate_pos [1:0];
    reg [3:0] step_counter;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            path_length <= 0;
            step_counter <= 0;
            for (int i = 0; i < 10; i++) begin
                current_path[i] <= 0;
                result[i] <= 0;
            end
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = INIT;
            end
            INIT: begin
                next_state = PROCESS_STEP;
            end
            PROCESS_STEP: begin
                if (step_counter == 19) next_state = CHECK_COMPLETE;
            end
            CHECK_COMPLETE: begin
                if (path_length == k) next_state = DONE;
                else next_state = PROCESS_STEP;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset logic
        end else begin
            case (current_state)
                INIT: begin
                    // Find global minimum (should be 1)
                    min_val = 8'hFF;
                    for (int i = 0; i < 2; i++) begin
                        for (int j = 0; j < 2; j++) begin
                            if (grid[i][j] < min_val) begin
                                min_val = grid[i][j];
                                min_pos[0] = i;
                                min_pos[1] = j;
                            end
                        end
                    end
                    current_path[0] = min_val;
                    current_pos[0] = min_pos[0];
                    current_pos[1] = min_pos[1];
                    path_length = 1;
                    step_counter = 0;
                end
                PROCESS_STEP: begin
                    // Generate candidate paths
                    reg [7:0] best_candidate [9:0];
                    reg [1:0] best_pos [1:0];
                    reg [7:0] temp_path [9:0];
                    reg [1:0] temp_pos [1:0];
                    reg first_candidate = 1;

                    // Check all 4 possible directions
                    for (int i = 0; i < 2; i++) begin
                        for (int j = 0; j < 2; j++) begin
                            // Check if neighbor is valid (not current position)
                            if ((i != current_pos[0] || j != current_pos[1])) begin
                                // Copy current path
                                for (int p = 0; p < 10; p++) begin
                                    temp_path[p] = current_path[p];
                                end
                                temp_path[path_length] = grid[i][j];
                                temp_pos[0] = i;
                                temp_pos[1] = j;

                                // Compare lexicographically
                                if (first_candidate) begin
                                    for (int p = 0; p < 10; p++) begin
                                        best_candidate[p] = temp_path[p];
                                    end
                                    best_pos[0] = temp_pos[0];
                                    best_pos[1] = temp_pos[1];
                                    first_candidate = 0;
                                end else begin
                                    reg [7:0] compare_result = 0;
                                    for (int p = 0; p < 10; p++) begin
                                        if (temp_path[p] != best_candidate[p]) begin
                                            compare_result = (temp_path[p] < best_candidate[p]) ? 1 : 0;
                                            break;
                                        end
                                    end
                                    if (compare_result) begin
                                        for (int p = 0; p < 10; p++) begin
                                            best_candidate[p] = temp_path[p];
                                        end
                                        best_pos[0] = temp_pos[0];
                                        best_pos[1] = temp_pos[1];
                                    end
                                end
                            end
                        end
                    end

                    // Update current path
                    for (int p = 0; p < 10; p++) begin
                        current_path[p] = best_candidate[p];
                    end
                    current_pos[0] = best_pos[0];
                    current_pos[1] = best_pos[1];
                    path_length = path_length + 1;
                    step_counter = step_counter + 1;
                end
                CHECK_COMPLETE: begin
                    if (path_length == k) begin
                        // Copy result
                        for (int i = 0; i < 10; i++) begin
                            result[i] = current_path[i];
                        end
                        done = 1;
                    end
                    step_counter = 0;
                end
                DONE: begin
                    done = 1;
                end
                default: begin
                    // Default case
                end
            endcase
        end
    end

endmodule