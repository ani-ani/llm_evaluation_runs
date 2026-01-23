module stamp_verification(
    input clk,
    input rst_n,
    input start,
    input [1:0] row_idx,
    input [1:0] col_idx,
    input [1:0] target_color,
    output reg result,
    output reg done
);

    // State definition
    localparam IDLE = 5'b00001;
    localparam LOAD = 5'b00010;
    localparam CHECK_A = 5'b00100;
    localparam CHECK_B = 5'b00101;
    localparam CHECK_C = 5'b00110;
    localparam CHECK_D = 5'b00111;
    localparam VALID = 5'b01000;
    localparam INVALID = 5'b01001;

    reg [4:0] state, next_state;

    // 4x4 grid storage
    reg [1:0] target_grid [0:3][0:3];

    // Counter for loading
    reg [3:0] load_counter;

    // Intermediate checks
    reg check_pass;
    reg [1:0] unique_cell_color;

    integer i, j;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
                else next_state = IDLE;
            end
            LOAD: begin
                if (load_counter == 15) next_state = CHECK_A;
                else next_state = LOAD;
            end
            CHECK_A: next_state = CHECK_B;
            CHECK_B: next_state = CHECK_C;
            CHECK_C: next_state = CHECK_D;
            CHECK_D: begin
                if (check_pass) next_state = VALID;
                else next_state = INVALID;
            end
            VALID, INVALID: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Output logic and datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            done <= 0;
            load_counter <= 0;
            // Initialize grid to white (default)
            for (i = 0; i < 4; i = i + 1) begin
                for (j = 0; j < 4; j = j + 1) begin
                    target_grid[i][j] <= 2'b00;
                end
            end
            check_pass <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        load_counter <= 0;
                        check_pass <= 0;
                    end
                end

                LOAD: begin
                    // Store input color at specified position
                    target_grid[row_idx][col_idx] <= target_color;
                    load_counter <= load_counter + 1;
                end

                CHECK_A: begin
                    // Placeholder for pipeline stage
                end

                CHECK_B: begin
                    // Placeholder
                end

                CHECK_C: begin
                    // Placeholder
                end

                CHECK_D: begin
                    // Perform full verification
                    // We need to know the colors of A, B, C, D.
                    // These are determined by the exclusive cells.
                    // A_color = target_grid[0][0]
                    // B_color = target_grid[0][3]
                    // C_color = target_grid[3][0]
                    // D_color = target_grid[3][3]

                    // Now check consistency for all cells.
                    // For each cell (r,c), we define a set of allowed colors.
                    // We can use combinational logic to compute if all 16 cells satisfy the condition.

                    // Let's define the check logic:
                    // reg is_valid;
                    // is_valid = 1;
                    // if (target[0][0] != target[0][0]) is_valid = 0; // redundant
                    // if (target[0][1] != A_color && target[0][1] != B_color) is_valid = 0;
                    // ...

                    // Since we are in sequential logic, we need to compute this combinationally.
                    // We will calculate check_pass based on current target_grid.
                end

                VALID: begin
                    result <= 1;
                    done <= 1;
                end

                INVALID: begin
                    result <= 0;
                    done <= 1;
                end
            endcase
        end
    end

    // Combinational check logic for CHECK_D state
    always @(*) begin
        // Default to fail
        check_pass = 0;

        // Extract stamp colors
        // Note: This logic runs continuously, but we only care when state == CHECK_D
        // However, in always @(posedge clk), the update happens. 
        // The 'check_pass' signal in the sequential block should be updated at CHECK_D.
        // Since we use non-blocking assignments for state transitions, we need to be careful.
        // Actually, let's move the check logic inside the sequential block for CHECK_D.
        // We can use an auxiliary always_comb block to compute the validity.
    end

    // Combinational validity check
    wire validity_check;

    // Extract colors
    wire [1:0] A_col = target_grid[0][0];
    wire [1:0] B_col = target_grid[0][3];
    wire [1:0] C_col = target_grid[3][0];
    wire [1:0] D_col = target_grid[3][3];

    // Check function
    // Returns 1 if the grid matches the stamp constraints
    function logic check_grid;
        input [1:0] grid [0:3][0:3];
        input [1:0] A, B, C, D;
        integer r, c;
        logic ok;
        logic covered_by_A, covered_by_B, covered_by_C, covered_by_D;
        logic match;
        begin
            ok = 1;
            for (r = 0; r < 4; r = r + 1) begin
                for (c = 0; c < 4; c = c + 1) begin
                    // Determine coverage
                    covered_by_A = (r < 3 && c < 3);
                    covered_by_B = (r < 3 && c > 0);
                    covered_by_C = (r > 0 && c < 3);
                    covered_by_D = (r > 0 && c > 0);

                    // Check if cell color is covered by at least one stamp that can paint it
                    // Actually, the condition is: if the cell is covered by a set of stamps,
                    // the target color must be one of the colors of those stamps.
                    match = 0;
                    if (covered_by_A && grid[r][c] == A) match = 1;
                    if (covered_by_B && grid[r][c] == B) match = 1;
                    if (covered_by_C && grid[r][c] == C) match = 1;
                    if (covered_by_D && grid[r][c] == D) match = 1;

                    // Special case: If a cell is not covered by ANY stamp, it must remain white (00).
                    // But in 4x4 grid with 3x3 stamps, all cells are covered by at least one stamp? 
                    // No. Corners are covered. Center is covered.
                    // Let's re-verify coverage:
                    // A: 0,0 to 2,2
                    // B: 0,1 to 2,3
                    // C: 1,0 to 3,2
                    // D: 1,1 to 3,3
                    // (0,0): A
                    // (0,1): A, B
                    // (0,2): A, B
                    // (0,3): B
                    // (1,0): A, C
                    // (1,1): A, B, C, D
                    // (1,2): A, B, C, D
                    // (1,3): B, D
                    // (2,0): A, C
                    // (2,1): A, B, C, D
                    // (2,2): A, B, C, D
                    // (2,3): B, D
                    // (3,0): C
                    // (3,1): C, D
                    // (3,2): C, D
                    // (3,3): D
                    // Yes, every cell is covered by at least one stamp.

                    if (!match) ok = 0;
                end
            end
            return ok;
        end
    endfunction

    assign validity_check = check_grid(target_grid, A_col, B_col, C_col, D_col);

    // Update check_pass in CHECK_D state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            check_pass <= 0;
        end else if (state == CHECK_D) begin
            check_pass <= validity_check;
        end
    end

endmodule