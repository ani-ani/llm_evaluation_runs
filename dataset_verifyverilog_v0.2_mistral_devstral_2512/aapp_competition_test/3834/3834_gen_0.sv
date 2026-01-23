module rectangular_grid_checker (
    input clk,
    input rst_n,
    input start,
    input [7:0] row_data [7:0],
    input [2:0] row_index,
    input load_row,
    output reg [3:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        LOAD_GRID,
        PROCESSING,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Grid storage (8x8)
    reg [7:0] grid [7:0];
    reg [2:0] load_row_counter;

    // Processing counters
    reg [2:0] row_counter;
    reg [2:0] col_counter;
    reg [2:0] invalid_count;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            load_row_counter <= 0;
            row_counter <= 0;
            col_counter <= 0;
            invalid_count <= 0;
            result <= 0;
            done <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = LOAD_GRID;
            end
            LOAD_GRID: begin
                if (load_row_counter == 7) next_state = PROCESSING;
            end
            PROCESSING: begin
                if (row_counter == 6 && col_counter == 6) next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Load grid logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_row_counter <= 0;
        end else if (current_state == LOAD_GRID && load_row) begin
            grid[row_index] <= row_data[row_index];
            load_row_counter <= load_row_counter + 1;
        end
    end

    // Processing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row_counter <= 0;
            col_counter <= 0;
            invalid_count <= 0;
        end else if (current_state == PROCESSING) begin
            // Check current 2x2 subgrid
            if (row_counter < 7 && col_counter < 7) begin
                reg a, b, c, d;
                a = grid[row_counter][col_counter];
                b = grid[row_counter][col_counter + 1];
                c = grid[row_counter + 1][col_counter];
                d = grid[row_counter + 1][col_counter + 1];

                if ((a == d) && (b != c)) begin
                    invalid_count <= invalid_count + 1;
                end
            end

            // Update counters
            if (col_counter == 6) begin
                col_counter <= 0;
                row_counter <= row_counter + 1;
            end else begin
                col_counter <= col_counter + 1;
            end
        end
    end

    // Result logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            done <= 0;
        end else if (current_state == DONE) begin
            if (invalid_count > 4) begin
                result <= 5;
            end else begin
                result <= invalid_count;
            end
            done <= 1;
        end else begin
            done <= 0;
        end
    end

endmodule