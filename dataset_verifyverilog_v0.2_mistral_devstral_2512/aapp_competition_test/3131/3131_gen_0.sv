module max_subset_sum (
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [3:0] K,
    input [31:0] data_in,
    input [3:0] write_idx,
    output reg [31:0] result,
    output reg done,
    output reg busy
);

    // Parameters
    localparam MOD = 32'h3B9ACA07;
    localparam MAX_N = 16;
    localparam MAX_K = 8;

    // Internal registers
    reg [31:0] array [0:MAX_N-1];
    reg [31:0] accumulator;
    reg [3:0] load_count;
    reg [15:0] combo_count;
    reg [15:0] max_combo_count;
    reg [15:0] current_combo;
    reg [3:0] bit_pos;
    reg [3:0] max_val;
    reg [3:0] max_idx;
    reg [3:0] selected_count;
    reg [3:0] temp_idx;
    reg [31:0] temp_max;

    // State machine
    typedef enum logic [2:0] {
        IDLE,
        LOAD_ARRAY,
        GENERATE_COMBOS,
        DONE
    } state_t;
    state_t state, next_state;

    // State registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            busy <= 1'b0;
            done <= 1'b0;
            result <= 32'b0;
            load_count <= 4'b0;
            combo_count <= 16'b0;
            current_combo <= 16'b0;
            bit_pos <= 4'b0;
            selected_count <= 4'b0;
            max_val <= 4'b0;
            max_idx <= 4'b0;
            accumulator <= 32'b0;
            temp_max <= 32'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_ARRAY;
                    busy = 1'b1;
                    done = 1'b0;
                    load_count = 4'b0;
                    accumulator = 32'b0;
                end
            end
            LOAD_ARRAY: begin
                if (load_count == N - 1) begin
                    next_state = GENERATE_COMBOS;
                    combo_count = 16'b0;
                    current_combo = 16'b0;
                    bit_pos = 4'b0;
                    selected_count = 4'b0;
                    max_val = 4'b0;
                    max_idx = 4'b0;
                    // Calculate total combinations: C(N, K)
                    max_combo_count = combination_count(N, K);
                end
            end
            GENERATE_COMBOS: begin
                if (combo_count == max_combo_count - 1) begin
                    next_state = DONE;
                    done = 1'b1;
                    busy = 1'b0;
                    result = accumulator;
                end
            end
            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                    done = 1'b0;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // Load array data
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_count <= 4'b0;
        end else if (state == LOAD_ARRAY) begin
            if (write_idx < N) begin
                array[write_idx] <= data_in;
                load_count <= load_count + 1;
            end
        end
    end

    // Combination generation and processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            combo_count <= 16'b0;
            current_combo <= 16'b0;
            bit_pos <= 4'b0;
            selected_count <= 4'b0;
            max_val <= 4'b0;
            max_idx <= 4'b0;
            temp_max <= 32'b0;
        end else if (state == GENERATE_COMBOS) begin
            // Process current combination
            if (bit_pos == 0) begin
                // Start new combination
                temp_max <= 32'b0;
                max_idx <= 4'b0;
                selected_count <= 4'b0;
            end

            // Check if current bit is set in combination
            if (current_combo[bit_pos]) begin
                selected_count <= selected_count + 1;
                if (array[bit_pos] > temp_max) begin
                    temp_max <= array[bit_pos];
                end
            end

            // Move to next bit
            bit_pos <= bit_pos + 1;

            // If all bits processed
            if (bit_pos == N) begin
                // Add max to accumulator
                accumulator <= accumulator + temp_max;
                if (accumulator >= MOD) begin
                    accumulator <= accumulator - MOD;
                end

                // Move to next combination
                combo_count <= combo_count + 1;
                current_combo <= next_combination(current_combo, N, K);
                bit_pos <= 4'b0;
            end
        end
    end

    // Function to calculate combinations C(n, k)
    function [15:0] combination_count;
        input [3:0] n, k;
        reg [15:0] result;
        reg [15:0] i;
        begin
            if (k == 0 || k == n) begin
                result = 1;
            end else if (k == 1) begin
                result = n;
            end else if (k > n) begin
                result = 0;
            end else begin
                result = 1;
                for (i = 1; i <= k; i = i + 1) begin
                    result = result * (n - k + i) / i;
                end
            end
            combination_count = result;
        end
    endfunction

    // Function to generate next combination
    function [15:0] next_combination;
        input [15:0] current;
        input [3:0] n, k;
        reg [15:0] next;
        reg [3:0] i;
        reg [3:0] ones_count;
        begin
            next = current;
            ones_count = 0;

            // Find rightmost 1 that can be moved
            for (i = 0; i < n; i = i + 1) begin
                if (next[i]) begin
                    ones_count = ones_count + 1;
                    if (next[i+1] == 0 && (n - i - 1) >= (k - ones_count)) begin
                        next[i] = 0;
                        next[i+1] = 1;
                        // Move all ones to the right
                        for (j = 0; j < i; j = j + 1) begin
                            if (next[j]) begin
                                next[j] = 0;
                                next[i - ones_count + 1 + j] = 1;
                            end
                        end
                        return next;
                    end
                end
            end

            // If no next combination, return all zeros
            next_combination = 16'b0;
        end
    endfunction

endmodule