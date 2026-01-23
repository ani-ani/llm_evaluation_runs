module prince_of_python (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [2:0] level [0:7],
    input [2:0] x [0:7],
    input [31:0] s [0:7],
    input [31:0] a [0:7][0:8],
    output reg [39:0] result,
    output reg done,
    output reg error
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        CALCULATING,
        DONE
    } state_t;

    state_t state;
    reg [39:0] min_sum;
    reg [39:0] current_sum;
    reg [7:0] level_mask;
    reg [8:0] item_mask;
    reg [2:0] current_level;
    reg [2:0] depth;
    reg [2:0] current_item;
    reg [39:0] temp_sum;

    // Initialize registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_sum <= 0;
            current_sum <= 0;
            level_mask <= 0;
            item_mask <= 0;
            current_level <= 0;
            depth <= 0;
            current_item <= 0;
            temp_sum <= 0;
            result <= 0;
            done <= 0;
            error <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        // Validate inputs
                        if (n == 0 || n > 8) begin
                            error <= 1;
                            state <= IDLE;
                        end else begin
                            error <= 0;
                            state <= CALCULATING;
                            min_sum <= 40'hFFFFFFFFF;
                            current_sum <= 0;
                            level_mask <= 0;
                            item_mask <= 1 << 0; // Start with item 0
                            current_level <= 0;
                            depth <= 0;
                            current_item <= 0;
                        end
                    end
                end
                CALCULATING: begin
                    if (depth == n) begin
                        // All levels completed
                        if (current_sum < min_sum) begin
                            min_sum <= current_sum;
                        end
                        // Backtrack
                        depth <= depth - 1;
                        level_mask <= level_mask & ~(1 << current_level);
                        current_item <= current_item - 1;
                        item_mask <= item_mask & ~(1 << current_item);
                        current_sum <= current_sum - (a[current_level][current_item] == 0 ? s[current_level] : a[current_level][current_item]);
                    end else begin
                        // Try next level
                        current_level <= current_level + 1;
                        if (current_level >= n) begin
                            current_level <= 0;
                        end
                        // Check if level is already used
                        if (level_mask & (1 << current_level)) begin
                            // Skip used level
                        end else begin
                            // Check if item is available
                            if (item_mask & (1 << current_item)) begin
                                // Use current item
                                temp_sum <= current_sum + (a[current_level][current_item] == 0 ? s[current_level] : a[current_level][current_item]);
                                if (temp_sum < min_sum) begin
                                    current_sum <= temp_sum;
                                    level_mask <= level_mask | (1 << current_level);
                                    depth <= depth + 1;
                                    current_item <= current_item + 1;
                                    item_mask <= item_mask | (1 << current_item);
                                end
                            end else begin
                                // Try shortcut if item is available
                                if (item_mask & (1 << x[current_level])) begin
                                    temp_sum <= current_sum + s[current_level];
                                    if (temp_sum < min_sum) begin
                                        current_sum <= temp_sum;
                                        level_mask <= level_mask | (1 << current_level);
                                        depth <= depth + 1;
                                        // No new item obtained via shortcut
                                    end
                                end
                            end
                        end
                    end
                    // Check if all permutations are done
                    if (depth == 0 && current_level == n - 1) begin
                        state <= DONE;
                        result <= min_sum;
                        done <= 1;
                    end
                end
                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule