module KthRootPermutation(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [7:0] k,
    input wire [3:0] a [0:15],
    output reg [3:0] result [0:15],
    output reg done,
    output reg valid
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] FIND_CYCLES = 3'd2;
    localparam [2:0] COMPUTE_ROOTS = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [3:0] i, j, cycle_start, cycle_length;
    reg [7:0] cycle_count, cycle_index;
    reg [3:0] visited [0:15];
    reg [3:0] cycle_members [0:15];
    reg [3:0] temp_result [0:15];
    reg [7:0] k_mod_l;
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            i <= 4'd0;
            j <= 4'd0;
            cycle_start <= 4'd0;
            cycle_length <= 4'd0;
            cycle_count <= 8'd0;
            cycle_index <= 8'd0;
            k_mod_l <= 8'd0;
            cycle_counter <= 8'd0;
            done <= 1'b0;
            valid <= 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                visited[i] <= 4'd0;
                cycle_members[i] <= 4'd0;
                result[i] <= 4'd0;
                temp_result[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    // Initialize visited array
                    for (i = 0; i < 16; i = i + 1) begin
                        visited[i] <= 4'd0;
                    end
                    i <= 4'd0;
                    cycle_count <= 8'd0;
                    cycle_counter <= 8'd0;
                    next_state <= FIND_CYCLES;
                end

                FIND_CYCLES: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    if (cycle_counter >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                        valid <= 1'b0;
                    end else if (i < n) begin
                        if (visited[i] == 4'd0) begin
                            // Found new cycle
                            cycle_start <= i;
                            cycle_length <= 4'd0;
                            j <= i;
                            next_state <= FIND_CYCLES;
                        end else begin
                            i <= i + 4'd1;
                            next_state <= FIND_CYCLES;
                        end
                    end else begin
                        // All cycles found
                        i <= 4'd0;
                        cycle_index <= 8'd0;
                        next_state <= COMPUTE_ROOTS;
                    end
                end

                COMPUTE_ROOTS: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    if (cycle_counter >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                        valid <= 1'b0;
                    end else if (cycle_index < cycle_count) begin
                        // Compute K-th root for this cycle
                        k_mod_l <= k % cycle_length;
                        if (k_mod_l == 8'd0) begin
                            // Identity permutation
                            for (j = 0; j < cycle_length; j = j + 1) begin
                                temp_result[cycle_members[j]] <= cycle_members[j];
                            end
                        end else begin
                            // Shift backwards by k_mod_l positions
                            for (j = 0; j < cycle_length; j = j + 1) begin
                                if (j < k_mod_l) begin
                                    temp_result[cycle_members[j]] <= cycle_members[cycle_length - k_mod_l + j];
                                end else begin
                                    temp_result[cycle_members[j]] <= cycle_members[j - k_mod_l];
                                end
                            end
                        end
                        cycle_index <= cycle_index + 8'd1;
                        next_state <= COMPUTE_ROOTS;
                    end else begin
                        // Copy temp_result to result
                        for (i = 0; i < 16; i = i + 1) begin
                            result[i] <= temp_result[i];
                        end
                        valid <= 1'b1;
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    valid <= 1'b0;
                end
            endcase
        end
    end

    // Cycle detection logic
    always @(posedge clk) begin
        if (state == FIND_CYCLES && visited[i] == 4'd0) begin
            if (visited[j] == 4'd0) begin
                visited[j] <= 4'd1;
                cycle_members[cycle_length] <= j;
                cycle_length <= cycle_length + 4'd1;
                j <= a[j] - 4'd1; // Convert to 0-indexed
            end else begin
                // Cycle complete
                i <= i + 4'd1;
                cycle_count <= cycle_count + 8'd1;
            end
        end
    end

endmodule