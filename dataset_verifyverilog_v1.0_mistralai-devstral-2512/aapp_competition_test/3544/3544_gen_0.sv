module CinemaSeating(
    input clk,
    input rst_n,
    input start,
    input [3:0] group_count [1:12],
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] CALCULATE = 2'd1;
    localparam [1:0] CHECK_X   = 2'd2;
    localparam [1:0] DONE      = 2'd3;

    // Registers
    reg [1:0] state, next_state;
    reg [3:0] x_counter;           // Current X being tested (3 to 12)
    reg [3:0] row_index;          // Current row index (0 to X-1)
    reg [3:0] remaining_seats;    // Remaining seats in current row
    reg [5:0] group_counter;      // Counter for groups of current size
    reg [3:0] group_size;         // Current group size being processed
    reg [3:0] total_groups;       // Total groups to place
    reg [3:0] placed_groups;      // Groups placed so far
    reg [3:0] row_seats [0:11];   // Remaining seats per row (max 12 rows)
    reg [5:0] group_count_reg [1:12]; // Local copy of group counts
    reg [7:0] cycle_count;       // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd250;

    // Initialize all registers in reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            x_counter <= 4'd0;
            row_index <= 4'd0;
            remaining_seats <= 4'd0;
            group_counter <= 6'd0;
            group_size <= 4'd0;
            total_groups <= 4'd0;
            placed_groups <= 4'd0;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize row_seats array
            integer i;
            for (i = 0; i < 12; i = i + 1) begin
                row_seats[i] <= 4'd0;
            end

            // Initialize group_count_reg array
            for (i = 1; i <= 12; i = i + 1) begin
                group_count_reg[i] <= 6'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Calculate total groups
                        integer i;
                        total_groups = 4'd0;
                        for (i = 1; i <= 12; i = i + 1) begin
                            group_count_reg[i] <= group_count[i];
                            total_groups <= total_groups + group_count[i];
                        end

                        if (total_groups == 4'd0) begin
                            result <= 8'd3;  // No groups, minimum X is 3
                            next_state <= DONE;
                        end else begin
                            x_counter <= 4'd3;  // Start with X=3
                            next_state <= CALCULATE;
                        end
                    end
                end

                CALCULATE: begin
                    // Initialize row seats for current X
                    integer i;
                    for (i = 0; i < x_counter; i = i + 1) begin
                        row_seats[i] <= x_counter - i;
                    end

                    row_index <= 4'd0;
                    remaining_seats <= row_seats[0];
                    group_size <= 4'd12;  // Start with largest groups
                    placed_groups <= 4'd0;
                    next_state <= CHECK_X;
                end

                CHECK_X: begin
                    // Try to place groups
                    if (group_size == 4'd0) begin
                        // All group sizes processed
                        if (placed_groups == total_groups) begin
                            // Found valid X
                            result <= x_counter;
                            next_state <= DONE;
                        end else begin
                            // Try next X
                            if (x_counter == 4'd12) begin
                                result <= 8'hFF;  // Impossible
                                next_state <= DONE;
                            end else begin
                                x_counter <= x_counter + 4'd1;
                                next_state <= CALCULATE;
                            end
                        end
                    end else if (group_count_reg[group_size] == 6'd0) begin
                        // No more groups of this size
                        group_size <= group_size - 4'd1;
                    end else if (remaining_seats == 4'd0) begin
                        // Current row full, move to next row
                        if (row_index == x_counter - 4'd1) begin
                            // All rows full, try next X
                            if (x_counter == 4'd12) begin
                                result <= 8'hFF;  // Impossible
                                next_state <= DONE;
                            end else begin
                                x_counter <= x_counter + 4'd1;
                                next_state <= CALCULATE;
                            end
                        end else begin
                            row_index <= row_index + 4'd1;
                            remaining_seats <= row_seats[row_index];
                        end
                    end else begin
                        // Try to place a group
                        if (group_size <= remaining_seats) begin
                            // Place group
                            if (group_size == remaining_seats) begin
                                // At row end, no separator needed
                                remaining_seats <= 4'd0;
                            end else begin
                                remaining_seats <= remaining_seats - (group_size + 4'd1);
                            end
                            group_count_reg[group_size] <= group_count_reg[group_size] - 6'd1;
                            placed_groups <= placed_groups + 4'd1;
                            group_counter <= group_count_reg[group_size];
                        end else begin
                            // Can't place this group, move to next row
                            if (row_index == x_counter - 4'd1) begin
                                // All rows full, try next X
                                if (x_counter == 4'd12) begin
                                    result <= 8'hFF;  // Impossible
                                    next_state <= DONE;
                                end else begin
                                    x_counter <= x_counter + 4'd1;
                                    next_state <= CALCULATE;
                                end
                            end else begin
                                row_index <= row_index + 4'd1;
                                remaining_seats <= row_seats[row_index];
                            end
                        end
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    // Safety: prevent infinite loops
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES) begin
            result <= 8'hFF;
            done <= 1'b1;
            state <= IDLE;
            next_state <= IDLE;
        end
    end

endmodule