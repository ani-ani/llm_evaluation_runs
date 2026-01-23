module josip_painter (
    input clk,
    input rst_n,
    input start,
    input [2:0] target_addr,
    input [7:0] target_row,
    input target_write_en,
    output reg [6:0] min_diff,
    output reg done
);

    // Internal state machine
    typedef enum logic [1:0] {
        IDLE,
        LOAD,
        COMPUTE,
        OUTPUT
    } state_t;
    state_t state, next_state;

    // Target grid memory (8x8)
    reg [7:0] target_grid [0:7];

    // Intermediate result storage
    reg [6:0] dp_result [0:3][0:7][0:7]; // [level][row][col]
    reg [1:0] dp_choice [0:3][0:7][0:7]; // Stores quadrant choices

    // Current computation state
    reg [1:0] current_level;
    reg [2:0] current_row, current_col;
    reg [1:0] quadrant;

    // Temporary storage for quadrant processing
    reg [6:0] temp_costs [0:5];
    reg [1:0] temp_choices [0:5];

    // Load counter
    reg [2:0] load_counter;

    // Compute counters
    reg [3:0] level_counter;
    reg [5:0] square_counter;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            min_diff <= 0;
            load_counter <= 0;
            current_level <= 0;
            current_row <= 0;
            current_col <= 0;
            quadrant <= 0;
            level_counter <= 0;
            square_counter <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
            end
            LOAD: begin
                if (load_counter == 7) next_state = COMPUTE;
            end
            COMPUTE: begin
                if (level_counter == 4 && square_counter == 0) next_state = OUTPUT;
            end
            OUTPUT: begin
                next_state = IDLE;
            end
        endcase
    end

    // Load target grid
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_counter <= 0;
        end else if (state == LOAD && target_write_en) begin
            target_grid[target_addr] <= target_row;
            if (target_addr == load_counter) begin
                load_counter <= load_counter + 1;
            end
        end
    end

    // Compute state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            level_counter <= 0;
            square_counter <= 0;
            current_level <= 0;
            current_row <= 0;
            current_col <= 0;
            quadrant <= 0;
        end else if (state == COMPUTE) begin
            // Process levels 0 to 3
            if (level_counter < 4) begin
                // Process all squares at current level
                if (square_counter < (8 >> level_counter) * (8 >> level_counter)) begin
                    // Compute current square position
                    current_row <= (square_counter >> level_counter) << level_counter;
                    current_col <= (square_counter & ((1 << (2*level_counter)) - 1)) << level_counter;

                    // Process quadrants for current level
                    if (level_counter > 0) begin
                        // For levels > 0, we need to process 6 permutations
                        // This is simplified for hardware implementation
                        // We'll process one permutation per cycle
                        if (quadrant < 6) begin
                            // Compute cost for current permutation
                            // This is a simplified version - actual implementation would need
                            // to properly compute the quadrant costs and recursive costs
                            temp_costs[quadrant] <= compute_quadrant_cost(current_level, current_row, current_col, quadrant);
                            quadrant <= quadrant + 1;
                        end else begin
                            // Find minimum cost among permutations
                            reg [6:0] min_cost = temp_costs[0];
                            reg [1:0] best_choice = 0;
                            for (int i = 1; i < 6; i++) begin
                                if (temp_costs[i] < min_cost) begin
                                    min_cost = temp_costs[i];
                                    best_choice = i;
                                end
                            end
                            dp_result[level_counter][current_row][current_col] <= min_cost;
                            dp_choice[level_counter][current_row][current_col] <= best_choice;

                            // Move to next square
                            square_counter <= square_counter + 1;
                            quadrant <= 0;
                        end
                    end else begin
                        // Level 0: simple pixel comparison
                        reg [6:0] white_cost = compute_pixel_cost(current_row, current_col, 0);
                        reg [6:0] black_cost = compute_pixel_cost(current_row, current_col, 1);
                        if (white_cost < black_cost) begin
                            dp_result[0][current_row][current_col] <= white_cost;
                            dp_choice[0][current_row][current_col] <= 0; // 0 = white
                        end else begin
                            dp_result[0][current_row][current_col] <= black_cost;
                            dp_choice[0][current_row][current_col] <= 1; // 1 = black
                        end
                        square_counter <= square_counter + 1;
                    end
                end else begin
                    // Move to next level
                    level_counter <= level_counter + 1;
                    square_counter <= 0;
                end
            end
        end
    end

    // Compute pixel cost for level 0
    function [6:0] compute_pixel_cost;
        input [2:0] row;
        input [2:0] col;
        input color;
        begin
            compute_pixel_cost = (target_grid[row][col] != color) ? 1 : 0;
        end
    endfunction

    // Compute quadrant cost for higher levels
    function [6:0] compute_quadrant_cost;
        input [1:0] level;
        input [2:0] row;
        input [2:0] col;
        input [1:0] perm;
        reg [6:0] cost;
        begin
            // Simplified quadrant cost calculation
            // In a real implementation, this would:
            // 1. Determine which quadrants are white/black based on permutation
            // 2. Sum the costs of those quadrants
            // 3. Add the recursive cost of the remaining two quadrants
            // For this example, we'll just return a dummy value
            cost = 0;
            compute_quadrant_cost = cost;
        end
    endfunction

    // Output state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
        end else if (state == OUTPUT) begin
            min_diff <= dp_result[3][0][0]; // Final result is at level 3, position 0,0
            done <= 1;
        end
    end

endmodule