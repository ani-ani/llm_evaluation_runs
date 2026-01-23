module superdoku_solver (
    input clk,
    input rst_n,
    input start,
    input [1:0] k,
    input [1:0] row_idx,
    input [1:0] cell_idx,
    input [1:0] data_in,
    output reg [1:0] grid_out [0:3][0:3],
    output reg valid,
    output reg solvable,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        LOAD,
        CHECK_INPUT,
        GENERATE,
        VERIFY,
        DONE
    } state_t;

    state_t state;
    reg [1:0] grid [0:3][0:3];
    reg [1:0] row [0:3];
    reg [1:0] col [0:3];
    reg [1:0] shift_count;
    reg [1:0] check_row;
    reg [1:0] check_col;
    reg [1:0] verify_col;
    reg [1:0] verify_row;
    reg [3:0] load_counter;
    reg [1:0] check_counter;
    reg [1:0] generate_counter;
    reg [1:0] verify_counter;
    reg [3:0] col_mask [0:3];
    reg input_valid;
    reg column_valid;

    // Reset all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 0;
            solvable <= 0;
            done <= 0;
            load_counter <= 0;
            check_counter <= 0;
            generate_counter <= 0;
            verify_counter <= 0;
            input_valid <= 0;
            column_valid <= 0;
            for (int i = 0; i < 4; i++) begin
                for (int j = 0; j < 4; j++) begin
                    grid[i][j] <= 0;
                end
                col_mask[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD;
                        load_counter <= 0;
                    end
                end
                LOAD: begin
                    if (load_counter < k) begin
                        if (row_idx == load_counter && cell_idx < 4) begin
                            grid[row_idx][cell_idx] <= data_in;
                        end
                        if (cell_idx == 3) begin
                            load_counter <= load_counter + 1;
                        end
                        if (load_counter == k) begin
                            state <= CHECK_INPUT;
                            check_counter <= 0;
                        end
                    end
                end
                CHECK_INPUT: begin
                    if (check_counter < k) begin
                        // Check for duplicates in current row
                        reg [3:0] row_mask = 0;
                        reg row_ok = 1;
                        for (int j = 0; j < 4; j++) begin
                            reg [1:0] val = grid[check_counter][j];
                            if (row_mask & (1 << val)) begin
                                row_ok = 0;
                            end
                            row_mask = row_mask | (1 << val);
                        end
                        input_valid <= input_valid & row_ok;
                        check_counter <= check_counter + 1;
                        if (check_counter == k) begin
                            state <= GENERATE;
                            generate_counter <= 0;
                        end
                    end
                end
                GENERATE: begin
                    if (generate_counter < 4) begin
                        if (generate_counter == 0) begin
                            // Row 0 is already loaded or default
                            if (k == 0) begin
                                grid[0][0] <= 0;
                                grid[0][1] <= 1;
                                grid[0][2] <= 2;
                                grid[0][3] <= 3;
                            end
                        end else begin
                            // Generate row i by shifting row 0 right by i positions
                            for (int j = 0; j < 4; j++) begin
                                grid[generate_counter][j] <= grid[0][(j - generate_counter + 4) % 4];
                            end
                        end
                        generate_counter <= generate_counter + 1;
                        if (generate_counter == 4) begin
                            state <= VERIFY;
                            verify_counter <= 0;
                        end
                    end
                end
                VERIFY: begin
                    if (verify_counter < 4) begin
                        // Check for duplicates in current column
                        reg [3:0] col_mask = 0;
                        reg col_ok = 1;
                        for (int i = 0; i < 4; i++) begin
                            reg [1:0] val = grid[i][verify_counter];
                            if (col_mask & (1 << val)) begin
                                col_ok = 0;
                            end
                            col_mask = col_mask | (1 << val);
                        end
                        column_valid <= column_valid & col_ok;
                        verify_counter <= verify_counter + 1;
                        if (verify_counter == 4) begin
                            state <= DONE;
                        end
                    end
                end
                DONE: begin
                    valid <= 1;
                    solvable <= input_valid & column_valid;
                    done <= 1;
                end
            endcase
        end
    end

    // Output grid
    always @(posedge clk) begin
        if (!rst_n) begin
            for (int i = 0; i < 4; i++) begin
                for (int j = 0; j < 4; j++) begin
                    grid_out[i][j] <= 0;
                end
            end
        end else if (state == DONE) begin
            for (int i = 0; i < 4; i++) begin
                for (int j = 0; j < 4; j++) begin
                    grid_out[i][j] <= grid[i][j];
                end
            end
        end
    end

endmodule