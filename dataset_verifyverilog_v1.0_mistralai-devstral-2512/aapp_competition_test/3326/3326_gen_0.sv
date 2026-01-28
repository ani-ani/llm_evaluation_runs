module monotonic_subgrid_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] INIT       = 3'd1;
    localparam [2:0] CHECK_SUBGRID = 3'd2;
    localparam [2:0] COUNT      = 3'd3;
    localparam [2:0] FINISH     = 3'd4;

    reg [2:0] state, next_state;

    // Hardcoded 3x3 grid (4-bit values)
    localparam [3:0] grid [0:2][0:2] = '{'{4'd1, 4'd2, 4'd5}, '{4'd7, 4'd6, 4'd4}, '{4'd9, 4'd8, 4'd3}};

    // Subset iteration counters
    reg [5:0] row_mask;
    reg [5:0] col_mask;
    reg [5:0] row_mask_count;
    reg [5:0] col_mask_count;

    // Subgrid extraction
    reg [3:0] subgrid [0:2][0:2];
    reg [3:0] temp_row [0:2];
    reg [3:0] temp_col [0:2];

    // Monotonicity check
    reg row_increasing;
    reg row_decreasing;
    reg col_increasing;
    reg col_decreasing;
    reg row_valid;
    reg col_valid;
    reg subgrid_valid;

    // Count register
    reg [7:0] count;

    // Cycle counter for safety
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            count <= 8'd0;
            row_mask <= 6'd0;
            col_mask <= 6'd0;
            row_mask_count <= 6'd0;
            col_mask_count <= 6'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end

            INIT: begin
                next_state = CHECK_SUBGRID;
            end

            CHECK_SUBGRID: begin
                next_state = COUNT;
            end

            COUNT: begin
                if (row_mask_count == 6'd63 && col_mask_count == 6'd63) begin
                    next_state = FINISH;
                end else begin
                    next_state = CHECK_SUBGRID;
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Row mask iteration
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row_mask <= 6'd0;
            row_mask_count <= 6'd0;
        end else if (state == INIT) begin
            row_mask <= 6'd1;
            row_mask_count <= 6'd1;
        end else if (state == COUNT && row_mask_count < 6'd63) begin
            row_mask <= row_mask + 6'd1;
            row_mask_count <= row_mask_count + 6'd1;
        end else if (state == COUNT && row_mask_count == 6'd63 && col_mask_count < 6'd63) begin
            row_mask <= 6'd1;
            row_mask_count <= 6'd1;
        end
    end

    // Column mask iteration
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_mask <= 6'd0;
            col_mask_count <= 6'd0;
        end else if (state == INIT) begin
            col_mask <= 6'd1;
            col_mask_count <= 6'd1;
        end else if (state == COUNT && col_mask_count < 6'd63 && row_mask_count == 6'd63) begin
            col_mask <= col_mask + 6'd1;
            col_mask_count <= col_mask_count + 6'd1;
        end
    end

    // Extract subgrid
    always @(*) begin
        if (state == CHECK_SUBGRID) begin
            // Initialize subgrid to zeros
            integer i, j;
            for (i = 0; i < 3; i = i + 1) begin
                for (j = 0; j < 3; j = j + 1) begin
                    subgrid[i][j] = 4'd0;
                end
            end

            // Extract rows based on row_mask
            integer row_idx;
            for (i = 0; i < 3; i = i + 1) begin
                if (row_mask[i]) begin
                    for (j = 0; j < 3; j = j + 1) begin
                        subgrid[row_idx][j] = grid[i][j];
                    end
                    row_idx = row_idx + 1;
                end
            end

            // Extract columns based on col_mask
            integer col_idx;
            for (j = 0; j < 3; j = j + 1) begin
                if (col_mask[j]) begin
                    for (i = 0; i < 3; i = i + 1) begin
                        temp_col[i] = subgrid[i][col_idx];
                    end
                    col_idx = col_idx + 1;
                end
            end
        end
    end

    // Check row monotonicity
    always @(*) begin
        if (state == CHECK_SUBGRID) begin
            integer i;
            row_increasing = 1'b1;
            row_decreasing = 1'b1;

            for (i = 0; i < 2; i = i + 1) begin
                if (temp_row[i] >= temp_row[i+1]) begin
                    row_increasing = 1'b0;
                end
                if (temp_row[i] <= temp_row[i+1]) begin
                    row_decreasing = 1'b0;
                end
            end

            row_valid = row_increasing || row_decreasing;
        end
    end

    // Check column monotonicity
    always @(*) begin
        if (state == CHECK_SUBGRID) begin
            integer i;
            col_increasing = 1'b1;
            col_decreasing = 1'b1;

            for (i = 0; i < 2; i = i + 1) begin
                if (temp_col[i] >= temp_col[i+1]) begin
                    col_increasing = 1'b0;
                end
                if (temp_col[i] <= temp_col[i+1]) begin
                    col_decreasing = 1'b0;
                end
            end

            col_valid = col_increasing || col_decreasing;
        end
    end

    // Determine subgrid validity
    always @(*) begin
        if (state == CHECK_SUBGRID) begin
            subgrid_valid = row_valid && col_valid;
        end
    end

    // Count valid subgrids
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 8'd0;
        end else if (state == COUNT && subgrid_valid) begin
            count <= count + 8'd1;
        end else if (state == FINISH) begin
            result <= count;
        end
    end

    // Done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else if (state == FINISH) begin
            done <= 1'b1;
        end else if (state == IDLE && start) begin
            done <= 1'b0;
        end
    end

    // Safety: prevent infinite loops
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES) begin
            state <= FINISH;
        end
    end

endmodule