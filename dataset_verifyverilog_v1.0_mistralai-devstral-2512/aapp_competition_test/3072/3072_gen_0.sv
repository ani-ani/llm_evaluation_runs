module MaxPerimeterFinder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] grid [0:7],
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] COMPUTE   = 3'd1;
    localparam [2:0] FINISH    = 3'd2;

    // Internal registers
    reg [2:0] state;
    reg [7:0] r1, c1, r2, c2;
    reg [15:0] max_perimeter;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;

    // Prefix sum array (8x8)
    reg [7:0] prefix [0:7];
    reg [7:0] prefix_row [0:7];

    // Compute prefix sums combinational
    always @(*) begin
        // Compute row prefix sums
        prefix_row[0] = grid[0];
        prefix_row[1] = grid[0] & grid[1];
        prefix_row[2] = prefix_row[1] & grid[2];
        prefix_row[3] = prefix_row[2] & grid[3];
        prefix_row[4] = prefix_row[3] & grid[4];
        prefix_row[5] = prefix_row[4] & grid[5];
        prefix_row[6] = prefix_row[5] & grid[6];
        prefix_row[7] = prefix_row[6] & grid[7];

        // Compute 2D prefix sums
        prefix[0] = prefix_row;
        prefix[1][0] = prefix_row[0] & grid[1][0];
        prefix[1][1] = prefix_row[1] & grid[1][1];
        prefix[1][2] = prefix_row[2] & grid[1][2];
        prefix[1][3] = prefix_row[3] & grid[1][3];
        prefix[1][4] = prefix_row[4] & grid[1][4];
        prefix[1][5] = prefix_row[5] & grid[1][5];
        prefix[1][6] = prefix_row[6] & grid[1][6];
        prefix[1][7] = prefix_row[7] & grid[1][7];

        prefix[2][0] = prefix[1][0] & grid[2][0];
        prefix[2][1] = prefix[1][1] & grid[2][1];
        prefix[2][2] = prefix[1][2] & grid[2][2];
        prefix[2][3] = prefix[1][3] & grid[2][3];
        prefix[2][4] = prefix[1][4] & grid[2][4];
        prefix[2][5] = prefix[1][5] & grid[2][5];
        prefix[2][6] = prefix[1][6] & grid[2][6];
        prefix[2][7] = prefix[1][7] & grid[2][7];

        prefix[3][0] = prefix[2][0] & grid[3][0];
        prefix[3][1] = prefix[2][1] & grid[3][1];
        prefix[3][2] = prefix[2][2] & grid[3][2];
        prefix[3][3] = prefix[2][3] & grid[3][3];
        prefix[3][4] = prefix[2][4] & grid[3][4];
        prefix[3][5] = prefix[2][5] & grid[3][5];
        prefix[3][6] = prefix[2][6] & grid[3][6];
        prefix[3][7] = prefix[2][7] & grid[3][7];

        prefix[4][0] = prefix[3][0] & grid[4][0];
        prefix[4][1] = prefix[3][1] & grid[4][1];
        prefix[4][2] = prefix[3][2] & grid[4][2];
        prefix[4][3] = prefix[3][3] & grid[4][3];
        prefix[4][4] = prefix[3][4] & grid[4][4];
        prefix[4][5] = prefix[3][5] & grid[4][5];
        prefix[4][6] = prefix[3][6] & grid[4][6];
        prefix[4][7] = prefix[3][7] & grid[4][7];

        prefix[5][0] = prefix[4][0] & grid[5][0];
        prefix[5][1] = prefix[4][1] & grid[5][1];
        prefix[5][2] = prefix[4][2] & grid[5][2];
        prefix[5][3] = prefix[4][3] & grid[5][3];
        prefix[5][4] = prefix[4][4] & grid[5][4];
        prefix[5][5] = prefix[4][5] & grid[5][5];
        prefix[5][6] = prefix[4][6] & grid[5][6];
        prefix[5][7] = prefix[4][7] & grid[5][7];

        prefix[6][0] = prefix[5][0] & grid[6][0];
        prefix[6][1] = prefix[5][1] & grid[6][1];
        prefix[6][2] = prefix[5][2] & grid[6][2];
        prefix[6][3] = prefix[5][3] & grid[6][3];
        prefix[6][4] = prefix[5][4] & grid[6][4];
        prefix[6][5] = prefix[5][5] & grid[6][5];
        prefix[6][6] = prefix[5][6] & grid[6][6];
        prefix[6][7] = prefix[5][7] & grid[6][7];

        prefix[7][0] = prefix[6][0] & grid[7][0];
        prefix[7][1] = prefix[6][1] & grid[7][1];
        prefix[7][2] = prefix[6][2] & grid[7][2];
        prefix[7][3] = prefix[6][3] & grid[7][3];
        prefix[7][4] = prefix[6][4] & grid[7][4];
        prefix[7][5] = prefix[6][5] & grid[7][5];
        prefix[7][6] = prefix[6][6] & grid[7][6];
        prefix[7][7] = prefix[6][7] & grid[7][7];
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            r1 <= 8'd0;
            c1 <= 8'd0;
            r2 <= 8'd0;
            c2 <= 8'd0;
            max_perimeter <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        r1 <= 8'd0;
                        c1 <= 8'd0;
                        r2 <= 8'd0;
                        c2 <= 8'd0;
                        max_perimeter <= 16'd0;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Check if current rectangle is valid
                    reg valid;
                    if (r1 <= r2 && c1 <= c2) begin
                        // Check using prefix sums
                        reg [7:0] top_left, bottom_right, top_right, bottom_left;
                        top_left = (r1 == 0 || c1 == 0) ? 8'd0 : prefix[r1-1][c1-1];
                        bottom_right = prefix[r2][c2];
                        top_right = (r1 == 0) ? 8'd0 : prefix[r1-1][c2];
                        bottom_left = (c1 == 0) ? 8'd0 : prefix[r2][c1-1];

                        // Calculate the rectangle sum
                        reg [7:0] rect_sum;
                        rect_sum = bottom_right ^ top_right ^ bottom_left ^ top_left;
                        valid = (rect_sum == 8'd0);
                    end else begin
                        valid = 1'b0;
                    end

                    // Calculate perimeter if valid
                    if (valid) begin
                        reg [15:0] current_perimeter;
                        current_perimeter = 2 * ((r2 - r1 + 1) + (c2 - c1 + 1));
                        if (current_perimeter > max_perimeter) begin
                            max_perimeter = current_perimeter;
                        end
                    end

                    // Move to next rectangle
                    if (c2 == 7) begin
                        if (r2 == 7) begin
                            if (c1 == 7) begin
                                if (r1 == 7) begin
                                    state <= FINISH;
                                end else begin
                                    r1 <= r1 + 8'd1;
                                    c1 <= 8'd0;
                                    r2 <= r1;
                                    c2 <= 8'd0;
                                end
                            end else begin
                                c1 <= c1 + 8'd1;
                                r2 <= r1;
                                c2 <= c1;
                            end
                        end else begin
                            r2 <= r2 + 8'd1;
                            c2 <= 8'd0;
                        end
                    end else begin
                        c2 <= c2 + 8'd1;
                    end

                    // Safety check for max cycles
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    result <= max_perimeter;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule