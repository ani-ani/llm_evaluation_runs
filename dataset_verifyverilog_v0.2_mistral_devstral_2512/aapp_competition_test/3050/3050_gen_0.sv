module robot_trail_calculator (
    input clk,
    input rst_n,
    input start,
    input [7:0] grid_data,
    input [7:0] prog_char,
    output reg [7:0] result,
    output reg done,
    output reg grid_addr_valid,
    output reg prog_addr_valid,
    output reg [7:0] grid_addr,
    output reg [7:0] prog_addr
);

    // State definitions
    typedef enum logic [5:0] {
        IDLE,
        LOAD_GRID,
        LOAD_PROG,
        UPDATE_STATE,
        CHECK_CYCLE,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Registers for robot state
    reg [7:0] row, col, prog_index;
    reg [7:0] step_count;
    reg [7:0] first_step;
    reg [7:0] cycle_length;

    // Visited state memory (200x200x200 = 8M bits, but we'll use a smaller memory for synthesis)
    reg [7:0] visited_memory [0:199999]; // Address = (row * 200 + col) * 200 + prog_index

    // Trail buffer (FIFO style)
    reg [7:0] trail_row [0:199999];
    reg [7:0] trail_col [0:199999];

    // Program length (assumed to be <= 200)
    reg [7:0] prog_len;

    // Temporary registers for grid and program data
    reg [7:0] current_grid_data;
    reg [7:0] current_prog_char;

    // Initialize state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            row <= 0;
            col <= 0;
            prog_index <= 0;
            step_count <= 0;
            first_step <= 0;
            cycle_length <= 0;
            done <= 0;
            grid_addr_valid <= 0;
            prog_addr_valid <= 0;
            grid_addr <= 0;
            prog_addr <= 0;
            result <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = current_state;
        grid_addr_valid = 0;
        prog_addr_valid = 0;
        grid_addr = 0;
        prog_addr = 0;
        done = 0;
        result = 0;

        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_GRID;
                    // Initialize robot state
                    row = 0;
                    col = 0;
                    prog_index = 0;
                    step_count = 0;
                    first_step = 0;
                    cycle_length = 0;
                    done = 0;
                    result = 0;
                end
            end

            LOAD_GRID: begin
                grid_addr_valid = 1;
                grid_addr = {row, col};
                next_state = LOAD_PROG;
            end

            LOAD_PROG: begin
                prog_addr_valid = 1;
                prog_addr = prog_index;
                next_state = UPDATE_STATE;
            end

            UPDATE_STATE: begin
                // Process grid and program data
                if (current_grid_data == "." || current_grid_data == "R") begin
                    // Update robot position
                    row = row + 1; // Example movement (adjust based on program instruction)
                    col = col + 1;
                    // Store trail
                    trail_row[step_count] = row;
                    trail_col[step_count] = col;
                end
                // Update program index
                prog_index = (prog_index + 1) % prog_len;
                step_count = step_count + 1;
                next_state = CHECK_CYCLE;
            end

            CHECK_CYCLE: begin
                // Calculate visited memory address
                reg [17:0] visited_addr = (row * 200 + col) * 200 + prog_index;
                if (visited_memory[visited_addr] == 1) begin
                    // Cycle detected
                    first_step = visited_memory[visited_addr];
                    cycle_length = step_count - first_step;
                    result = cycle_length;
                    done = 1;
                    next_state = DONE;
                end else begin
                    // Mark as visited
                    visited_memory[visited_addr] = step_count;
                    next_state = LOAD_GRID;
                end
            end

            DONE: begin
                done = 1;
                result = cycle_length;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Update current grid and program data
    always @(posedge clk) begin
        if (grid_addr_valid) begin
            current_grid_data <= grid_data;
        end
        if (prog_addr_valid) begin
            current_prog_char <= prog_char;
        end
    end

endmodule