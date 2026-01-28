module PrimeGroupSplit(
    input clk,
    input rst_n,
    input start,
    input [31:0] data_in,
    input valid_in,
    input last_in,
    output reg [1:0] result,
    output reg [15:0] assignment,
    output reg done,
    output reg ready
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COLLECT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] CHECK   = 3'd3;
    localparam [2:0] OUTPUT  = 3'd4;

    reg [2:0] state, next_state;

    // Data collection
    reg [31:0] data_buffer [0:15];
    reg [7:0] prime_mask [0:15];
    reg [3:0] data_count;
    reg [3:0] data_index;

    // Prime factors (hardcoded)
    localparam [31:0] PRIMES [0:7] = '{32'd2, 32'd3, 32'd5, 32'd7, 32'd11, 32'd13, 32'd17, 32'd19};

    // DP computation
    reg [7:0] dp_state [0:255];
    reg [15:0] dp_assignment [0:255];
    reg [7:0] current_mask;
    reg [7:0] target_mask;
    reg [3:0] dp_index;
    reg [3:0] num_index;
    reg found_solution;
    reg [15:0] solution_assignment;

    // Cycle counter
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;

    // Prime factorization function
    function [7:0] compute_prime_mask;
        input [31:0] value;
        integer i;
        reg [7:0] mask;
        begin
            mask = 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                if (value != 0 && value % PRIMES[i] == 0) begin
                    mask[i] = 1'b1;
                end
            end
            compute_prime_mask = mask;
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            data_count <= 4'd0;
            data_index <= 4'd0;
            current_mask <= 8'd0;
            target_mask <= 8'd0;
            dp_index <= 4'd0;
            num_index <= 4'd0;
            found_solution <= 1'b0;
            solution_assignment <= 16'd0;
            cycle_count <= 8'd0;
            result <= 2'd0;
            assignment <= 16'd0;
            done <= 1'b0;
            ready <= 1'b1;

            // Initialize DP buffer
            integer j;
            for (j = 0; j < 256; j = j + 1) begin
                dp_state[j] <= 8'd0;
                dp_assignment[j] <= 16'd0;
            end

            // Initialize data buffer
            integer k;
            for (k = 0; k < 16; k = k + 1) begin
                data_buffer[k] <= 32'd0;
                prime_mask[k] <= 8'd0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    ready <= 1'b1;
                    done <= 1'b0;
                    if (start) begin
                        next_state <= COLLECT;
                        ready <= 1'b0;
                        data_count <= 4'd0;
                        data_index <= 4'd0;
                    end
                end

                COLLECT: begin
                    if (valid_in) begin
                        data_buffer[data_index] <= data_in;
                        prime_mask[data_index] <= compute_prime_mask(data_in);
                        data_index <= data_index + 4'd1;
                        if (last_in) begin
                            data_count <= data_index;
                            next_state <= COMPUTE;
                            // Compute target mask (union of all prime masks)
                            integer i;
                            target_mask <= 8'd0;
                            for (i = 0; i < data_count; i = i + 1) begin
                                target_mask <= target_mask | prime_mask[i];
                            end
                            // Initialize DP
                            dp_state[0] <= 8'd1;  // State 0 is reachable (empty set)
                            dp_assignment[0] <= 16'd0;
                            dp_index <= 4'd0;
                            num_index <= 4'd0;
                        end
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= CHECK;
                    end else begin
                        // DP update: for each reachable state, try adding each number
                        if (dp_index == 4'd0 && num_index == 4'd0) begin
                            // Initialize for new iteration
                            current_mask <= 8'd0;
                        end

                        // Find next reachable state
                        integer i;
                        for (i = 0; i < 256; i = i + 1) begin
                            if (dp_state[i] && !current_mask[7:0]) begin
                                current_mask <= i;
                                break;
                            end
                        end

                        // Try adding each number to current state
                        if (num_index < data_count) begin
                            reg [7:0] new_mask;
                            reg [15:0] new_assignment;
                            new_mask = current_mask | prime_mask[num_index];
                            new_assignment = dp_assignment[current_mask] | (1 << num_index);

                            // Update DP if new state is better
                            if (!dp_state[new_mask] || (new_assignment != 16'd0 && (dp_assignment[new_mask] == 16'd0 || $countones(new_assignment) < $countones(dp_assignment[new_mask])))) begin
                                dp_state[new_mask] <= 1'b1;
                                dp_assignment[new_mask] <= new_assignment;
                            end

                            num_index <= num_index + 4'd1;
                        end else begin
                            num_index <= 4'd0;
                            dp_index <= dp_index + 4'd1;
                            if (dp_index >= data_count) begin
                                next_state <= CHECK;
                            end
                        end
                    end
                end

                CHECK: begin
                    // Check if we have a solution
                    if (dp_state[target_mask] && target_mask != 8'd0) begin
                        // Found a subset that covers all primes
                        solution_assignment <= dp_assignment[target_mask];
                        found_solution <= 1'b1;
                        result <= 2'd1;  // YES_GROUP1
                    end else begin
                        // Check if complement covers all primes
                        integer i;
                        reg [7:0] complement_mask;
                        for (i = 0; i < data_count; i = i + 1) begin
                            if (!(solution_assignment[i])) begin
                                complement_mask <= complement_mask | prime_mask[i];
                            end
                        end
                        if (complement_mask == target_mask && target_mask != 8'd0) begin
                            found_solution <= 1'b1;
                            result <= 2'd2;  // YES_GROUP2
                        end else begin
                            found_solution <= 1'b0;
                            result <= 2'd0;  // NO
                        end
                    end
                    next_state <= OUTPUT;
                end

                OUTPUT: begin
                    if (found_solution) begin
                        assignment <= solution_assignment;
                    end else begin
                        assignment <= 16'd0;
                    end
                    done <= 1'b1;
                    next_state <= IDLE;
                    ready <= 1'b1;
                end

                default: begin
                    next_state <= IDLE;
                    ready <= 1'b1;
                end
            endcase
        end
    end

    // Initialize DP buffer on reset
    integer j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (j = 0; j < 256; j = j + 1) begin
                dp_state[j] <= 8'd0;
                dp_assignment[j] <= 16'd0;
            end
        end
    end

    // Initialize data buffer on reset
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (k = 0; k < 16; k = k + 1) begin
                data_buffer[k] <= 32'd0;
                prime_mask[k] <= 8'd0;
            end
        end
    end

endmodule