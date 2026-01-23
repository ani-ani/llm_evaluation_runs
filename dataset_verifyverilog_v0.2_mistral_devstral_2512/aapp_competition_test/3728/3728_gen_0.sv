module table_sorter (
    input clk,
    input rst_n,
    input start,
    input [2:0] row_idx,
    input [7:0] col_val_0, col_val_1, col_val_2, col_val_3, col_val_4, col_val_5, col_val_6, col_val_7,
    output reg result,
    output reg done
);

    // Define states
    typedef enum logic [1:0] {
        IDLE,
        LOAD,
        PROCESS,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal table storage (4 rows x 8 columns)
    reg [7:0] table [0:3][0:7];

    // Counters for processing
    reg [2:0] col1_counter;
    reg [2:0] col2_counter;
    reg [2:0] row_check_counter;
    reg [2:0] cycle_counter;

    // Temporary storage for swapped columns
    reg [7:0] temp_table [0:3][0:7];

    // Flags
    reg table_loaded;
    reg found_valid_pair;

    // Initialize registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 0;
            done <= 0;
            table_loaded <= 0;
            found_valid_pair <= 0;
            col1_counter <= 0;
            col2_counter <= 0;
            row_check_counter <= 0;
            cycle_counter <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                    table_loaded = 0;
                    found_valid_pair = 0;
                    result = 0;
                    done = 0;
                end
            end
            LOAD: begin
                if (table_loaded) begin
                    next_state = PROCESS;
                end
            end
            PROCESS: begin
                if (found_valid_pair || cycle_counter >= 1024) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // Load table data
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            table_loaded <= 0;
        end else if (current_state == LOAD && !table_loaded) begin
            // Store the current row
            table[row_idx][0] <= col_val_0;
            table[row_idx][1] <= col_val_1;
            table[row_idx][2] <= col_val_2;
            table[row_idx][3] <= col_val_3;
            table[row_idx][4] <= col_val_4;
            table[row_idx][5] <= col_val_5;
            table[row_idx][6] <= col_val_6;
            table[row_idx][7] <= col_val_7;

            // Check if all rows are loaded
            if (row_idx == 3) begin
                table_loaded <= 1;
            end
        end
    end

    // Processing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col1_counter <= 0;
            col2_counter <= 0;
            row_check_counter <= 0;
            cycle_counter <= 0;
        end else if (current_state == PROCESS) begin
            cycle_counter <= cycle_counter + 1;

            // Initialize or increment column counters
            if (cycle_counter == 0) begin
                col1_counter <= 0;
                col2_counter <= 0;
            end else if (col2_counter == 7) begin
                col1_counter <= col1_counter + 1;
                col2_counter <= col1_counter;
            end else begin
                col2_counter <= col2_counter + 1;
            end

            // Check if we've tried all column pairs
            if (col1_counter == 7 && col2_counter == 7) begin
                found_valid_pair <= 1'b0;
            end else begin
                // Create temporary table with swapped columns
                for (int i = 0; i < 4; i++) begin
                    for (int j = 0; j < 8; j++) begin
                        if (j == col1_counter) begin
                            temp_table[i][j] = table[i][col2_counter];
                        end else if (j == col2_counter) begin
                            temp_table[i][j] = table[i][col1_counter];
                        end else begin
                            temp_table[i][j] = table[i][j];
                        end
                    end
                end

                // Check if all rows are sortable
                reg all_rows_sortable = 1'b1;
                for (int i = 0; i < 4; i++) begin
                    if (!is_row_sortable(temp_table[i])) begin
                        all_rows_sortable = 1'b0;
                    end
                end

                if (all_rows_sortable) begin
                    found_valid_pair <= 1'b1;
                end
            end
        end
    end

    // Check if a row is sortable (differs from identity by at most 2 elements)
    function automatic bit is_row_sortable(input [7:0] row);
        reg [7:0] identity = {1, 2, 3, 4, 5, 6, 7, 8};
        reg [7:0] temp_row;
        integer mismatches;

        temp_row = row;
        mismatches = 0;

        for (int i = 0; i < 8; i++) begin
            if (temp_row[i] != identity[i]) begin
                mismatches = mismatches + 1;
            end
        end

        // Check if we can fix with at most one swap
        if (mismatches == 0) begin
            return 1'b1;
        end else if (mismatches == 2) begin
            // Check if swapping the two mismatched elements fixes the row
            for (int i = 0; i < 8; i++) begin
                if (temp_row[i] != identity[i]) begin
                    for (int j = i + 1; j < 8; j++) begin
                        if (temp_row[j] != identity[j]) begin
                            // Try swapping
                            reg [7:0] swapped_row = temp_row;
                            swapped_row[i] = temp_row[j];
                            swapped_row[j] = temp_row[i];

                            if (swapped_row == identity) begin
                                return 1'b1;
                            end
                        end
                    end
                end
            end
        end

        return 1'b0;
    endfunction

    // Output handling
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            done <= 0;
        end else if (current_state == DONE) begin
            result <= found_valid_pair;
            done <= 1'b1;
        end else begin
            done <= 0;
        end
    end

endmodule