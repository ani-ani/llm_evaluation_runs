module gridnavia_solver (
    input clk,
    input rst_n,
    input start,
    input [63:0] single_lang_mask,
    output reg [63:0] lang_a_mask,
    output reg [63:0] lang_b_mask,
    output reg [63:0] lang_c_mask,
    output reg done,
    output reg valid
);

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
        SEED_REGIONS,
        GROW_A,
        GROW_B,
        GROW_C,
        VALIDATE,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [63:0] assigned_mask;
    reg [63:0] temp_a_mask;
    reg [63:0] temp_b_mask;
    reg [63:0] temp_c_mask;
    reg [5:0] cycle_counter;
    reg [5:0] cell_index;
    reg [5:0] seed_a, seed_b, seed_c;

    // Initialize seeds (top-left, top-right, bottom-center)
    parameter SEED_A = 0;      // (0,0)
    parameter SEED_B = 7;      // (0,7)
    parameter SEED_C = 32 + 3; // (4,3)

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            lang_a_mask <= 64'b0;
            lang_b_mask <= 64'b0;
            lang_c_mask <= 64'b0;
            assigned_mask <= 64'b0;
            temp_a_mask <= 64'b0;
            temp_b_mask <= 64'b0;
            temp_c_mask <= 64'b0;
            cycle_counter <= 0;
            cell_index <= 0;
            done <= 0;
            valid <= 0;
        end else begin
            current_state <= next_state;

            case (current_state)
                IDLE: begin
                    if (start) begin
                        next_state <= SEED_REGIONS;
                    end
                end

                SEED_REGIONS: begin
                    // Initialize seeds
                    temp_a_mask <= 64'b0;
                    temp_b_mask <= 64'b0;
                    temp_c_mask <= 64'b0;
                    assigned_mask <= 64'b0;

                    temp_a_mask[SEED_A] <= 1'b1;
                    temp_b_mask[SEED_B] <= 1'b1;
                    temp_c_mask[SEED_C] <= 1'b1;
                    assigned_mask[SEED_A] <= 1'b1;
                    assigned_mask[SEED_B] <= 1'b1;
                    assigned_mask[SEED_C] <= 1'b1;

                    cycle_counter <= 0;
                    cell_index <= 0;
                    next_state <= GROW_A;
                end

                GROW_A: begin
                    if (cycle_counter < 1024) begin
                        if (cell_index < 64) begin
                            // Try to grow region A
                            if (!assigned_mask[cell_index]) begin
                                // Check if adjacent to A and satisfies conditions
                                if (is_adjacent(cell_index, temp_a_mask) && 
                                    (single_lang_mask[cell_index] || 
                                     (temp_b_mask[cell_index] || temp_c_mask[cell_index]))) begin
                                    temp_a_mask[cell_index] <= 1'b1;
                                    assigned_mask[cell_index] <= 1'b1;
                                end
                            end
                            cell_index <= cell_index + 1;
                        end else begin
                            cell_index <= 0;
                            cycle_counter <= cycle_counter + 1;
                        end
                    end else begin
                        next_state <= GROW_B;
                        cycle_counter <= 0;
                        cell_index <= 0;
                    end
                end

                GROW_B: begin
                    if (cycle_counter < 1024) begin
                        if (cell_index < 64) begin
                            // Try to grow region B
                            if (!assigned_mask[cell_index]) begin
                                // Check if adjacent to B and satisfies conditions
                                if (is_adjacent(cell_index, temp_b_mask) && 
                                    (single_lang_mask[cell_index] || 
                                     (temp_a_mask[cell_index] || temp_c_mask[cell_index]))) begin
                                    temp_b_mask[cell_index] <= 1'b1;
                                    assigned_mask[cell_index] <= 1'b1;
                                end
                            end
                            cell_index <= cell_index + 1;
                        end else begin
                            cell_index <= 0;
                            cycle_counter <= cycle_counter + 1;
                        end
                    end else begin
                        next_state <= GROW_C;
                        cycle_counter <= 0;
                        cell_index <= 0;
                    end
                end

                GROW_C: begin
                    if (cycle_counter < 1024) begin
                        if (cell_index < 64) begin
                            // Try to grow region C
                            if (!assigned_mask[cell_index]) begin
                                // Check if adjacent to C and satisfies conditions
                                if (is_adjacent(cell_index, temp_c_mask) && 
                                    (single_lang_mask[cell_index] || 
                                     (temp_a_mask[cell_index] || temp_b_mask[cell_index]))) begin
                                    temp_c_mask[cell_index] <= 1'b1;
                                    assigned_mask[cell_index] <= 1'b1;
                                end
                            end
                            cell_index <= cell_index + 1;
                        end else begin
                            cell_index <= 0;
                            cycle_counter <= cycle_counter + 1;
                        end
                    end else begin
                        next_state <= VALIDATE;
                        cycle_counter <= 0;
                        cell_index <= 0;
                    end
                end

                VALIDATE: begin
                    // Check all cells are assigned
                    if (assigned_mask == 64'b1111111111111111111111111111111111111111111111111111111111111111) begin
                        // Check connectivity for each region
                        if (is_connected(temp_a_mask) && is_connected(temp_b_mask) && is_connected(temp_c_mask)) begin
                            valid <= 1'b1;
                        end else begin
                            valid <= 1'b0;
                        end
                    end else begin
                        valid <= 1'b0;
                    end

                    // Output results
                    lang_a_mask <= temp_a_mask;
                    lang_b_mask <= temp_b_mask;
                    lang_c_mask <= temp_c_mask;
                    done <= 1'b1;
                    next_state <= DONE;
                end

                DONE: begin
                    if (!start) begin
                        next_state <= IDLE;
                        done <= 1'b0;
                        valid <= 1'b0;
                    end
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    // Helper function to check if a cell is adjacent to any set bit in mask
    function automatic bit is_adjacent(input [5:0] cell, input [63:0] mask);
        bit result = 0;
        integer row = cell / 8;
        integer col = cell % 8;

        // Check up
        if (row > 0 && mask[cell - 8]) result = 1;
        // Check down
        if (row < 7 && mask[cell + 8]) result = 1;
        // Check left
        if (col > 0 && mask[cell - 1]) result = 1;
        // Check right
        if (col < 7 && mask[cell + 1]) result = 1;

        return result;
    endfunction

    // Helper function to check connectivity (simple BFS-like check)
    function automatic bit is_connected(input [63:0] mask);
        bit visited [0:63];
        integer i, j;
        integer queue [0:63];
        integer head, tail;

        // Initialize
        for (i = 0; i < 64; i = i + 1) begin
            visited[i] = 0;
        end

        // Find first set bit
        for (i = 0; i < 64; i = i + 1) begin
            if (mask[i]) begin
                head = 0;
                tail = 1;
                queue[0] = i;
                visited[i] = 1;
                break;
            end
        end

        // If no bits set, return 0
        if (i == 64) return 0;

        // BFS
        while (head < tail) begin
            integer current = queue[head];
            head = head + 1;

            // Check neighbors
            integer row = current / 8;
            integer col = current % 8;

            // Up
            if (row > 0 && mask[current - 8] && !visited[current - 8]) begin
                queue[tail] = current - 8;
                tail = tail + 1;
                visited[current - 8] = 1;
            end

            // Down
            if (row < 7 && mask[current + 8] && !visited[current + 8]) begin
                queue[tail] = current + 8;
                tail = tail + 1;
                visited[current + 8] = 1;
            end

            // Left
            if (col > 0 && mask[current - 1] && !visited[current - 1]) begin
                queue[tail] = current - 1;
                tail = tail + 1;
                visited[current - 1] = 1;
            end

            // Right
            if (col < 7 && mask[current + 1] && !visited[current + 1]) begin
                queue[tail] = current + 1;
                tail = tail + 1;
                visited[current + 1] = 1;
            end
        end

        // Check if all set bits were visited
        for (i = 0; i < 64; i = i + 1) begin
            if (mask[i] && !visited[i]) begin
                return 0;
            end
        end

        return 1;
    endfunction

endmodule