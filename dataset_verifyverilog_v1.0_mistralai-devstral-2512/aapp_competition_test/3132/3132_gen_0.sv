module BuildingFinder(
    input clk,
    input rst_n,
    input start,
    input [63:0] grid_in,
    output reg [2:0] r1,
    output reg [2:0] c1,
    output reg [2:0] s1,
    output reg [2:0] r2,
    output reg [2:0] c2,
    output reg [2:0] s2,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] SCAN_SQ1    = 3'd1;
    localparam [2:0] FIND_REMAINING = 3'd2;
    localparam [2:0] SCAN_SQ2    = 3'd3;
    localparam [2:0] OUTPUT      = 3'd4;

    reg [2:0] state;
    reg [7:0] row, col, size;
    reg [7:0] row2, col2, size2;
    reg [7:0] max_size1, max_size2;
    reg [7:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // Grid storage
    reg [63:0] grid;
    reg [7:0] grid_row [0:7];

    // Remaining grid (after first square)
    reg [63:0] remaining_grid;
    reg [7:0] remaining_row [0:7];

    // FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            r1 <= 3'd0;
            c1 <= 3'd0;
            s1 <= 3'd0;
            r2 <= 3'd0;
            c2 <= 3'd0;
            s2 <= 3'd0;
            done <= 1'b0;
            cycle_count <= 10'd0;
            row <= 8'd0;
            col <= 8'd0;
            size <= 8'd0;
            row2 <= 8'd0;
            col2 <= 8'd0;
            size2 <= 8'd0;
            max_size1 <= 8'd0;
            max_size2 <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    if (start) begin
                        state <= SCAN_SQ1;
                        // Store grid
                        grid <= grid_in;
                        // Initialize grid_row
                        integer i, j;
                        for (i = 0; i < 8; i = i + 1) begin
                            grid_row[i] <= grid_in[(i+1)*8-1:i*8];
                        end
                        // Initialize remaining_grid
                        remaining_grid <= 64'd0;
                        for (i = 0; i < 8; i = i + 1) begin
                            remaining_row[i] <= 8'd0;
                        end
                        row <= 8'd0;
                        col <= 8'd0;
                        size <= 8'd0;
                        max_size1 <= 8'd0;
                    end
                end

                SCAN_SQ1: begin
                    cycle_count <= cycle_count + 10'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= OUTPUT;
                    end else begin
                        // Check if current square is valid
                        reg valid;
                        integer r, c;
                        valid = 1'b1;
                        for (r = row; r < row + size; r = r + 1) begin
                            for (c = col; c < col + size; c = c + 1) begin
                                if (r >= 8 || c >= 8 || grid_row[r][c] == 1'b0) begin
                                    valid = 1'b0;
                                end
                            end
                        end

                        if (valid && size > max_size1) begin
                            max_size1 <= size;
                            r1 <= row;
                            c1 <= col;
                            s1 <= size;
                        end

                        // Move to next position
                        if (col + size < 8) begin
                            col <= col + 1'b1;
                        end else if (row + size < 8) begin
                            col <= 8'd0;
                            row <= row + 1'b1;
                        end else if (size < 8) begin
                            col <= 8'd0;
                            row <= 8'd0;
                            size <= size + 1'b1;
                        end else begin
                            state <= FIND_REMAINING;
                        end
                    end
                end

                FIND_REMAINING: begin
                    cycle_count <= cycle_count + 10'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= OUTPUT;
                    end else begin
                        // Mark cells covered by first square
                        integer r, c;
                        for (r = 0; r < 8; r = r + 1) begin
                            for (c = 0; c < 8; c = c + 1) begin
                                if (r >= r1 && r < r1 + s1 && c >= c1 && c < c1 + s1) begin
                                    remaining_row[r][c] <= 1'b0;
                                end else begin
                                    remaining_row[r][c] <= grid_row[r][c];
                                end
                            end
                        end
                        state <= SCAN_SQ2;
                        row2 <= 8'd0;
                        col2 <= 8'd0;
                        size2 <= 8'd0;
                        max_size2 <= 8'd0;
                    end
                end

                SCAN_SQ2: begin
                    cycle_count <= cycle_count + 10'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= OUTPUT;
                    end else begin
                        // Check if current square is valid
                        reg valid;
                        integer r, c;
                        valid = 1'b1;
                        for (r = row2; r < row2 + size2; r = r + 1) begin
                            for (c = col2; c < col2 + size2; c = c + 1) begin
                                if (r >= 8 || c >= 8 || remaining_row[r][c] == 1'b0) begin
                                    valid = 1'b0;
                                end
                            end
                        end

                        if (valid && size2 > max_size2) begin
                            max_size2 <= size2;
                            r2 <= row2;
                            c2 <= col2;
                            s2 <= size2;
                        end

                        // Move to next position
                        if (col2 + size2 < 8) begin
                            col2 <= col2 + 1'b1;
                        end else if (row2 + size2 < 8) begin
                            col2 <= 8'd0;
                            row2 <= row2 + 1'b1;
                        end else if (size2 < 8) begin
                            col2 <= 8'd0;
                            row2 <= 8'd0;
                            size2 <= size2 + 1'b1;
                        end else begin
                            state <= OUTPUT;
                        end
                    end
                end

                OUTPUT: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule