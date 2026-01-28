module magic_checkerboard (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] grid_in [0:15],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_CONFLICTS = 3'd1;
    localparam [2:0] PROPAGATE_BOUNDS = 3'd2;
    localparam [2:0] CALCULATE_SUM = 3'd3;
    localparam [2:0] FINISHED = 3'd4;

    reg [2:0] state, next_state;
    reg [15:0] grid_val [0:15];
    reg [5:0] iteration;
    reg [5:0] cycle_count;
    localparam [5:0] MAX_CYCLES = 6'd64;
    localparam [5:0] MAX_ITERATIONS = 6'd16;

    integer i, j;
    reg [15:0] temp_val;
    reg [15:0] sum;
    reg valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            iteration <= 6'd0;
            cycle_count <= 6'd0;
            for (i = 0; i < 16; i = i + 1) begin
                grid_val[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    // Initialize grid_val
                    for (i = 0; i < 16; i = i + 1) begin
                        if (grid_in[i] == 16'd0) begin
                            grid_val[i] = 16'd0;
                        end else begin
                            grid_val[i] = grid_in[i];
                        end
                    end
                    next_state = CHECK_CONFLICTS;
                    iteration <= 6'd0;
                    cycle_count <= 6'd0;
                end
            end

            CHECK_CONFLICTS: begin
                // Check for immediate conflicts (rows/columns not increasing)
                valid = 1'b1;
                for (i = 0; i < 4; i = i + 1) begin
                    for (j = 0; j < 3; j = j + 1) begin
                        if (grid_val[i*4 + j] != 16'd0 && grid_val[i*4 + j+1] != 16'd0 && 
                            grid_val[i*4 + j] >= grid_val[i*4 + j+1]) begin
                            valid = 1'b0;
                        end
                    end
                end
                for (j = 0; j < 4; j = j + 1) begin
                    for (i = 0; i < 3; i = i + 1) begin
                        if (grid_val[i*4 + j] != 16'd0 && grid_val[(i+1)*4 + j] != 16'd0 && 
                            grid_val[i*4 + j] >= grid_val[(i+1)*4 + j]) begin
                            valid = 1'b0;
                        end
                    end
                end

                if (valid) begin
                    next_state = PROPAGATE_BOUNDS;
                end else begin
                    next_state = FINISHED;
                    result = 16'd0 - 16'd1; // -1 for error
                end
            end

            PROPAGATE_BOUNDS: begin
                // Forward pass
                for (i = 0; i < 4; i = i + 1) begin
                    for (j = 0; j < 4; j = j + 1) begin
                        if (grid_val[i*4 + j] == 16'd0) begin
                            temp_val = 16'd0;
                            if (i > 0 && grid_val[(i-1)*4 + j] != 16'd0) begin
                                temp_val = grid_val[(i-1)*4 + j] + 16'd1;
                            end
                            if (j > 0 && grid_val[i*4 + (j-1)] != 16'd0) begin
                                if (grid_val[i*4 + (j-1)] + 16'd1 > temp_val) begin
                                    temp_val = grid_val[i*4 + (j-1)] + 16'd1;
                                end
                            end
                            grid_val[i*4 + j] = temp_val;
                        end
                    end
                end

                // Backward pass
                for (i = 3; i >= 0; i = i - 1) begin
                    for (j = 3; j >= 0; j = j - 1) begin
                        if (grid_val[i*4 + j] == 16'd0) begin
                            temp_val = 16'd0;
                            if (i < 3 && grid_val[(i+1)*4 + j] != 16'd0) begin
                                temp_val = grid_val[(i+1)*4 + j] - 16'd1;
                            end
                            if (j < 3 && grid_val[i*4 + (j+1)] != 16'd0) begin
                                if (grid_val[i*4 + (j+1)] - 16'd1 > temp_val) begin
                                    temp_val = grid_val[i*4 + (j+1)] - 16'd1;
                                end
                            end
                            if (temp_val > grid_val[i*4 + j]) begin
                                grid_val[i*4 + j] = temp_val;
                            end
                        end
                    end
                end

                iteration <= iteration + 6'd1;
                if (iteration >= MAX_ITERATIONS) begin
                    next_state = CALCULATE_SUM;
                end
            end

            CALCULATE_SUM: begin
                // Check parity constraints
                valid = 1'b1;
                for (i = 0; i < 3; i = i + 1) begin
                    for (j = 0; j < 3; j = j + 1) begin
                        if (grid_val[i*4 + j] != 16'd0 && grid_val[(i+1)*4 + (j+1)] != 16'd0 && 
                            (grid_val[i*4 + j] % 2'd2) == (grid_val[(i+1)*4 + (j+1)] % 2'd2)) begin
                            // Fix parity by incrementing
                            grid_val[(i+1)*4 + (j+1)] = grid_val[(i+1)*4 + (j+1)] + 16'd1;
                        end
                    end
                end

                // Calculate sum
                sum = 16'd0;
                for (i = 0; i < 16; i = i + 1) begin
                    if (grid_val[i] == 16'd0) begin
                        valid = 1'b0;
                    end
                    sum = sum + grid_val[i];
                end

                if (valid) begin
                    result = sum;
                end else begin
                    result = 16'd0 - 16'd1; // -1 for error
                end
                next_state = FINISHED;
            end

            FINISHED: begin
                done <= 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Cycle counter to prevent infinite loops
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 6'd0;
        end else if (state != IDLE && state != FINISHED) begin
            cycle_count <= cycle_count + 6'd1;
            if (cycle_count >= MAX_CYCLES) begin
                state <= FINISHED;
                result <= 16'd0 - 16'd1; // -1 for timeout
                done <= 1'b1;
            end
        end
    end

endmodule