module k_smallest_pairs(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr1 [0:7],
    input [7:0] arr2 [0:7],
    input [2:0] len1,
    input [2:0] len2,
    input [3:0] k,
    output reg result_valid,
    output reg [7:0] pair_val1,
    output reg [7:0] pair_val2,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] SETUP   = 3'd1;
    localparam [2:0] EXTRACT = 3'd2;
    localparam [2:0] PUSH    = 3'd3;
    localparam [2:0] OUTPUT  = 3'd4;
    localparam [2:0] FINISH  = 3'd5;

    reg [2:0] state;
    reg [3:0] pairs_generated;
    reg [3:0] heap_size;
    reg [3:0] min_index;

    // Heap entry: sum (16-bit), i (3-bit), j (3-bit)
    reg [15:0] heap_sum [0:15];
    reg [2:0] heap_i [0:15];
    reg [2:0] heap_j [0:15];

    // Current extracted pair
    reg [15:0] current_sum;
    reg [2:0] current_i;
    reg [2:0] current_j;

    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd320;

    // Find minimum in heap (combinational)
    always @(*) begin
        min_index = 16'd0;
        if (heap_size > 0) begin
            for (integer idx = 0; idx < 16; idx = idx + 1) begin
                if (idx < heap_size) begin
                    if (heap_sum[idx] < heap_sum[min_index]) begin
                        min_index = idx;
                    end
                end
            end
        end
    end

    // Heap push operation (combinational)
    reg [15:0] new_sum;
    reg [2:0] new_i;
    reg [2:0] new_j;
    reg [3:0] push_index;

    always @(*) begin
        new_sum = 16'd0;
        new_i = 3'd0;
        new_j = 3'd0;
        push_index = heap_size;

        if (state == PUSH) begin
            if (current_j + 1 < len2) begin
                new_sum = arr1[current_i] + arr2[current_j + 1];
                new_i = current_i;
                new_j = current_j + 1;
            end else if (current_j == 0 && current_i + 1 < len1) begin
                new_sum = arr1[current_i + 1] + arr2[0];
                new_i = current_i + 1;
                new_j = 0;
            end
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pairs_generated <= 4'd0;
            heap_size <= 4'd0;
            result_valid <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize heap
            for (integer idx = 0; idx < 16; idx = idx + 1) begin
                heap_sum[idx] <= 16'd0;
                heap_i[idx] <= 3'd0;
                heap_j[idx] <= 3'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    done <= 1'b0;
                    cycle_count <= 8'd0;

                    if (start) begin
                        state <= SETUP;
                    end
                end

                SETUP: begin
                    // Push initial pair (0,0)
                    heap_sum[0] <= arr1[0] + arr2[0];
                    heap_i[0] <= 3'd0;
                    heap_j[0] <= 3'd0;
                    heap_size <= 4'd1;
                    state <= EXTRACT;
                end

                EXTRACT: begin
                    if (heap_size > 0) begin
                        // Extract minimum
                        current_sum <= heap_sum[min_index];
                        current_i <= heap_i[min_index];
                        current_j <= heap_j[min_index];

                        // Remove from heap by swapping with last
                        heap_sum[min_index] <= heap_sum[heap_size - 1];
                        heap_i[min_index] <= heap_i[heap_size - 1];
                        heap_j[min_index] <= heap_j[heap_size - 1];
                        heap_size <= heap_size - 1;

                        state <= PUSH;
                    end else begin
                        state <= FINISH;
                    end
                end

                PUSH: begin
                    // Push new elements if needed
                    if (current_j + 1 < len2) begin
                        heap_sum[heap_size] <= arr1[current_i] + arr2[current_j + 1];
                        heap_i[heap_size] <= current_i;
                        heap_j[heap_size] <= current_j + 1;
                        heap_size <= heap_size + 1;
                    end

                    if (current_j == 0 && current_i + 1 < len1) begin
                        heap_sum[heap_size] <= arr1[current_i + 1] + arr2[0];
                        heap_i[heap_size] <= current_i + 1;
                        heap_j[heap_size] <= 3'd0;
                        heap_size <= heap_size + 1;
                    end

                    state <= OUTPUT;
                end

                OUTPUT: begin
                    // Output the current pair
                    pair_val1 <= arr1[current_i];
                    pair_val2 <= arr2[current_j];
                    result_valid <= 1'b1;
                    pairs_generated <= pairs_generated + 1;

                    // Check if done
                    if (pairs_generated >= k || heap_size == 0) begin
                        state <= FINISH;
                    end else begin
                        state <= EXTRACT;
                    end
                end

                FINISH: begin
                    result_valid <= 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase

            // Cycle counter for timeout
            if (state != IDLE && state != FINISH) begin
                cycle_count <= cycle_count + 1;
                if (cycle_count >= MAX_CYCLES) begin
                    state <= FINISH;
                end
            end
        end
    end

endmodule