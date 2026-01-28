module knight_generator(
    input clk,
    input rst_n,
    input start,
    input [9:0] n,
    output reg [10:0] x,
    output reg [1:0] y,
    output reg valid,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] OUTPUT = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [9:0] knight_counter;      // Tracks current knight index (0 to n-1)
    reg [9:0] total_knights;       // Stores n value
    reg [9:0] groups;              // Calculated groups = n / 3
    reg [1:0] remainder;           // Calculated remainder = n % 3
    reg [9:0] knights_in_groups;   // Number of knights from groups (groups * 3)
    reg [9:0] cycle_count;         // Prevent infinite loops
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // Computation for groups and remainder
    // n is 10-bit (max 1000), groups max = 333, remainder 0-2
    always @(*) begin
        groups = n / 10'd3;
        remainder = n % 10'd3;
        knights_in_groups = groups * 10'd3;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            knight_counter <= 10'd0;
            total_knights <= 10'd0;
            x <= 11'd0;
            y <= 2'd0;
            valid <= 1'b0;
            done <= 1'b0;
            cycle_count <= 10'd0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                    knight_counter <= 10'd0;
                    cycle_count <= 10'd0;
                    if (start && n != 10'd0) begin
                        total_knights <= n;
                        state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    done <= 1'b0;
                    cycle_count <= cycle_count + 10'd1;

                    // Determine coordinates for current knight
                    if (knight_counter < knights_in_groups) begin
                        // Knights from groups: groups of 3
                        // Each group i produces 3 knights: (2*i, 0), (2*i+1, 0), (2*i+1, 3)
                        // knight_index = 3*i + offset (0, 1, 2)
                        reg [9:0] i;
                        reg [1:0] offset;
                        i = knight_counter / 10'd3;          // Group index
                        offset = knight_counter % 10'd3;      // Position in group

                        case (offset)
                            2'd0: begin x <= {1'b0, i[9:0], 1'b0}; y <= 2'd0; end // (2*i, 0)
                            2'd1: begin x <= {1'b0, i[9:0], 1'b1}; y <= 2'd0; end // (2*i+1, 0)
                            2'd2: begin x <= {1'b0, i[9:0], 1'b1}; y <= 2'd3; end // (2*i+1, 3)
                            default: begin x <= 11'd0; y <= 2'd0; end
                        endcase
                    end else begin
                        // Knights from remainder
                        // Remaining indices from knights_in_groups to n-1
                        // Mapped to offset 0, 1, 2 (for remainder 1, 2, or 3)
                        reg [9:0] offset_idx;
                        offset_idx = knight_counter - knights_in_groups;

                        if (offset_idx < remainder) begin
                            x <= {1'b0, groups[9:0], 1'b0} + offset_idx; // (2*groups + i)
                            y <= 2'd0;
                        end else begin
                            x <= 11'd0;
                            y <= 2'd0;
                        end
                    end

                    valid <= 1'b1;
                    knight_counter <= knight_counter + 10'd1;

                    // Check if all knights are done
                    if (knight_counter == total_knights - 10'd1 || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    valid <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule