module matrix_search(
    input clk,
    input rst_n,
    input start,
    input [127:0] matrix_flat,
    input [63:0] row_lengths,
    input [7:0] target,
    output reg [255:0] result_packed,
    output reg [4:0] result_count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SCAN_ROW = 3'd1;
    localparam [2:0] SCAN_COL = 3'd2;
    localparam [2:0] SORT_INSERT = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] current_row;
    reg [3:0] current_col;
    reg [3:0] found_count;
    reg [3:0] sort_index;
    reg [3:0] compare_index;
    reg [3:0] temp_row;
    reg [3:0] temp_col;
    reg [3:0] row_len;
    reg [7:0] matrix_val;
    reg [3:0] row_length_reg;

    // Temporary buffer for found coordinates (max 16 entries)
    reg [3:0] buffer_row [0:15];
    reg [3:0] buffer_col [0:15];

    // Cycle counter to prevent infinite loops
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1024;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_packed <= 256'd0;
            result_count <= 5'd0;
            done <= 1'b0;
            cycle_count <= 10'd0;
            current_row <= 4'd0;
            current_col <= 4'd0;
            found_count <= 4'd0;
            sort_index <= 4'd0;
            compare_index <= 4'd0;
            temp_row <= 4'd0;
            temp_col <= 4'd0;
            row_len <= 4'd0;
            matrix_val <= 8'd0;
            row_length_reg <= 4'd0;
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                buffer_row[i] <= 4'd0;
                buffer_col[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 10'd1;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SCAN_ROW;
                end
            end

            SCAN_ROW: begin
                if (current_row == 4'd16) begin
                    if (found_count == 4'd0) begin
                        next_state = FINISH;
                    end else begin
                        next_state = SORT_INSERT;
                    end
                end else begin
                    next_state = SCAN_COL;
                end
            end

            SCAN_COL: begin
                if (current_col == row_len) begin
                    next_state = SCAN_ROW;
                end else begin
                    next_state = SCAN_COL;
                end
            end

            SORT_INSERT: begin
                if (sort_index == found_count) begin
                    next_state = FINISH;
                end else begin
                    next_state = SORT_INSERT;
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Data processing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in state transition
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                end

                SCAN_ROW: begin
                    if (current_row == 4'd16) begin
                        // All rows scanned
                    end else begin
                        // Get row length for current row
                        row_length_reg = row_lengths[(current_row * 4) +: 4];
                        current_col <= 4'd0;
                        row_len <= row_length_reg;
                    end
                end

                SCAN_COL: begin
                    if (current_col == row_len) begin
                        // Move to next row
                        current_row <= current_row + 4'd1;
                    end else begin
                        // Read matrix value
                        matrix_val = matrix_flat[(current_row * 8) +: 8];
                        if (matrix_val == target) begin
                            // Found a match, store in buffer
                            buffer_row[found_count] <= current_row;
                            buffer_col[found_count] <= current_col;
                            found_count <= found_count + 4'd1;
                        end
                        current_col <= current_col + 4'd1;
                    end
                end

                SORT_INSERT: begin
                    if (sort_index == found_count) begin
                        // Sorting complete, prepare output
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < found_count) begin
                                result_packed[(i * 16) +: 16] = {buffer_row[i], buffer_col[i]};
                            end else begin
                                result_packed[(i * 16) +: 16] = 16'd0;
                            end
                        end
                        result_count <= found_count;
                    end else begin
                        // Insertion sort: find correct position for current element
                        temp_row <= buffer_row[sort_index];
                        temp_col <= buffer_col[sort_index];
                        compare_index <= sort_index;
                        while (compare_index > 4'd0 && 
                              (buffer_row[compare_index - 4'd1] > temp_row ||
                               (buffer_row[compare_index - 4'd1] == temp_row &&
                                buffer_col[compare_index - 4'd1] < temp_col))) begin
                            buffer_row[compare_index] <= buffer_row[compare_index - 4'd1];
                            buffer_col[compare_index] <= buffer_col[compare_index - 4'd1];
                            compare_index <= compare_index - 4'd1;
                        end
                        buffer_row[compare_index] <= temp_row;
                        buffer_col[compare_index] <= temp_col;
                        sort_index <= sort_index + 4'd1;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Safety check for cycle count
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES) begin
            state <= FINISH;
        end
    end

endmodule