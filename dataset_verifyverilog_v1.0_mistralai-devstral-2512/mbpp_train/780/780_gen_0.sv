module pairwise_sum_generator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] coord_x [0:7],
    input wire [15:0] coord_y [0:7],
    input wire [3:0] num_coords,
    output reg [15:0] result_pairs_x [0:7],
    output reg [15:0] result_pairs_y [0:7],
    output reg [3:0] num_results,
    output reg done,
    output reg valid,
    output reg overflow
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] OUTPUT  = 3'd3;
    localparam [2:0] DONE    = 3'd4;

    reg [2:0] state, next_state;

    // Internal registers
    reg [15:0] coords_x_reg [0:7];
    reg [15:0] coords_y_reg [0:7];
    reg [3:0] num_coords_reg;

    // Combination generation registers
    reg [3:0] i_reg, j_reg;
    reg [3:0] result_count;
    reg [15:0] sum_x, sum_y;

    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            overflow <= 1'b0;
            num_results <= 4'd0;
            cycle_count <= 8'd0;

            // Initialize all output registers
            integer k;
            for (k = 0; k < 8; k = k + 1) begin
                result_pairs_x[k] <= 16'd0;
                result_pairs_y[k] <= 16'd0;
            end

            // Initialize coordinate registers
            for (k = 0; k < 8; k = k + 1) begin
                coords_x_reg[k] <= 16'd0;
                coords_y_reg[k] <= 16'd0;
            end

            i_reg <= 4'd0;
            j_reg <= 4'd0;
            result_count <= 4'd0;
            sum_x <= 16'd0;
            sum_y <= 16'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    overflow <= 1'b0;
                    cycle_count <= 8'd0;

                    if (start) begin
                        next_state <= LOAD;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD: begin
                    // Store input coordinates
                    integer k;
                    for (k = 0; k < 8; k = k + 1) begin
                        coords_x_reg[k] <= coord_x[k];
                        coords_y_reg[k] <= coord_y[k];
                    end
                    num_coords_reg <= num_coords;

                    // Initialize counters
                    i_reg <= 4'd0;
                    j_reg <= 4'd0;
                    result_count <= 4'd0;

                    // Check for edge case: num_coords < 2
                    if (num_coords < 2) begin
                        next_state <= DONE;
                    end else begin
                        next_state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Calculate number of expected results
                    reg [3:0] expected_results;
                    expected_results = (num_coords_reg * (num_coords_reg - 4'd1)) >> 1;

                    // Check for overflow
                    if (expected_results > 8) begin
                        overflow <= 1'b1;
                        next_state <= DONE;
                    end else begin
                        // Generate combinations
                        if (j_reg < num_coords_reg) begin
                            if (i_reg < j_reg) begin
                                // Compute sum
                                sum_x <= coords_x_reg[i_reg] + coords_x_reg[j_reg];
                                sum_y <= coords_y_reg[i_reg] + coords_y_reg[j_reg];

                                // Store result
                                if (result_count < 8) begin
                                    result_pairs_x[result_count] <= sum_x;
                                    result_pairs_y[result_count] <= sum_y;
                                end

                                result_count <= result_count + 4'd1;
                                j_reg <= j_reg + 4'd1;
                            end else begin
                                i_reg <= i_reg + 4'd1;
                                j_reg <= i_reg + 4'd1;
                            end

                            // Check if all combinations done
                            if (i_reg >= num_coords_reg - 4'd1) begin
                                num_results <= result_count;
                                next_state <= OUTPUT;
                            end
                        end
                    end

                    // Timeout check
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE;
                    end
                end

                OUTPUT: begin
                    valid <= 1'b1;
                    next_state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule