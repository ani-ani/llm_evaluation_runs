module karen_and_game (
    input clk,
    input rst_n,
    input start,
    output reg output_valid,
    output reg [7:0] output_char,
    output reg done
);

    // Parameters
    localparam N_ROWS = 4;
    localparam N_COLS = 4;
    localparam MAX_VAL = 15;

    // States
    typedef enum logic [1:0] {
        IDLE,
        SOLVE,
        OUTPUT
    } state_t;

    // State registers
    state_t state, next_state;

    // Grid input (assumed to be provided via some mechanism, here we'll use registers for simulation)
    reg [3:0] grid [0:N_ROWS-1][0:N_COLS-1];

    // Solver stage registers
    reg [3:0] base_col;
    reg [3:0] col_increments [0:N_COLS-1];
    reg [3:0] row_increments [0:N_ROWS-1];
    reg [7:0] best_sum;
    reg [3:0] best_col_increments [0:N_COLS-1];
    reg [3:0] best_row_increments [0:N_ROWS-1];
    reg valid_solution;

    // Output stage registers
    reg [1:0] output_idx;
    reg [1:0] move_idx;
    reg [3:0] current_value;
    reg [7:0] char_counter;

    // Initialize grid (for simulation, in real design this would be input)
    initial begin
        grid[0][0] = 4'd1; grid[0][1] = 4'd2; grid[0][2] = 4'd3; grid[0][3] = 4'd4;
        grid[1][0] = 4'd2; grid[1][1] = 4'd3; grid[1][2] = 4'd4; grid[1][3] = 4'd5;
        grid[2][0] = 4'd3; grid[2][1] = 4'd4; grid[2][2] = 4'd5; grid[2][3] = 4'd6;
        grid[3][0] = 4'd4; grid[3][1] = 4'd5; grid[3][2] = 4'd6; grid[3][3] = 4'd7;
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            base_col <= 0;
            output_idx <= 0;
            move_idx <= 0;
            char_counter <= 0;
            output_valid <= 0;
            done <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = SOLVE;
            end
            SOLVE: begin
                if (base_col == MAX_VAL) next_state = OUTPUT;
            end
            OUTPUT: begin
                if (done) next_state = IDLE;
            end
        endcase
    end

    // Solver stage logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            base_col <= 0;
            best_sum <= 8'd255;
            valid_solution <= 0;
        end else if (state == SOLVE) begin
            // Calculate col_increments for current base_col
            col_increments[0] = base_col;
            for (int j = 1; j < N_COLS; j = j + 1) begin
                col_increments[j] = grid[0][j] - grid[0][0] + base_col;
            end

            // Calculate row_increments
            row_increments[0] = 0;
            for (int i = 1; i < N_ROWS; i = i + 1) begin
                row_increments[i] = grid[i][0] - col_increments[0];
            end

            // Check validity
            reg valid = 1;
            for (int i = 0; i < N_ROWS; i = i + 1) begin
                if (row_increments[i] < 0) valid = 0;
            end
            for (int j = 0; j < N_COLS; j = j + 1) begin
                if (col_increments[j] < 0) valid = 0;
            end

            // Check consistency
            for (int i = 0; i < N_ROWS; i = i + 1) begin
                for (int j = 0; j < N_COLS; j = j + 1) begin
                    if (grid[i][j] != row_increments[i] + col_increments[j]) valid = 0;
                end
            end

            // Calculate sum
            reg [7:0] current_sum = 0;
            for (int i = 0; i < N_ROWS; i = i + 1) begin
                current_sum = current_sum + row_increments[i];
            end
            for (int j = 0; j < N_COLS; j = j + 1) begin
                current_sum = current_sum + col_increments[j];
            end

            // Update best solution
            if (valid && current_sum < best_sum) begin
                best_sum = current_sum;
                for (int i = 0; i < N_ROWS; i = i + 1) begin
                    best_row_increments[i] = row_increments[i];
                end
                for (int j = 0; j < N_COLS; j = j + 1) begin
                    best_col_increments[j] = col_increments[j];
                end
                valid_solution = 1;
            end

            // Increment base_col
            if (base_col == MAX_VAL) begin
                base_col <= 0;
            end else begin
                base_col <= base_col + 1;
            end
        end
    end

    // Output stage logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            output_idx <= 0;
            move_idx <= 0;
            char_counter <= 0;
            output_valid <= 0;
            done <= 0;
        end else if (state == OUTPUT) begin
            if (char_counter == 0) begin
                // Determine current value and string
                if (output_idx < N_ROWS) begin
                    current_value = best_row_increments[output_idx];
                end else begin
                    current_value = best_col_increments[output_idx - N_ROWS];
                end

                // Output string based on move_idx
                case (move_idx)
                    0: output_char <= "row ";
                    1: output_char <= output_idx < N_ROWS ? (output_idx + 1) + "0" : ((output_idx - N_ROWS) + 1) + "0";
                    2: output_char <= "
";
                endcase

                // Increment counters
                if (move_idx == 2) begin
                    move_idx <= 0;
                    if (output_idx == (N_ROWS + N_COLS - 1)) begin
                        done <= 1;
                    end else begin
                        output_idx <= output_idx + 1;
                    end
                end else begin
                    move_idx <= move_idx + 1;
                end

                char_counter <= char_counter + 1;
                output_valid <= 1;
            end else begin
                output_valid <= 0;
            end
        end else begin
            output_valid <= 0;
        end
    end

endmodule