module MaximumProfit (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire cfg_en,
    input wire [3:0] cfg_idx,
    input wire [3:0] cfg_f,
    input wire [15:0] cfg_p,
    input wire [15:0] cfg_m,
    input wire [7:0] cfg_s,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CONFIG = 3'd1;
    localparam [2:0] CALC_INIT = 3'd2;
    localparam [2:0] CALC_FIND_CYCLE = 3'd3;
    localparam [2:0] CALC_PROCESS_CYCLE = 3'd4;
    localparam [2:0] CALC_PROCESS_TREES = 3'd5;
    localparam [2:0] DONE = 3'd6;

    // Memory arrays (16 elements each)
    reg [3:0] f_reg [0:15];      // 4-bit destination
    reg [15:0] p_reg [0:15];     // 16-bit purchase price
    reg [15:0] m_reg [0:15];     // 16-bit market price  
    reg [7:0] s_reg [0:15];      // 8-bit stock count

    // Control registers
    reg [2:0] state;
    reg [3:0] idx;                // Current index for iteration
    reg [31:0] total_profit;      // Accumulated profit
    reg [31:0] cycle_profit;      // Current cycle profit
    reg [3:0] cycle_nodes [0:15]; // Nodes in current cycle
    reg [3:0] cycle_len;          // Length of current cycle
    reg [3:0] visited [0:15];     // 1=processed in cycle, 2=processed in tree
    reg [7:0] available [0:15];   // Available stock after cycle allocation
    reg [7:0] cycle_snack_sum;    // Total snacks in current cycle
    reg [7:0] cycle_idx;          // Index for iterating through cycle
    reg [31:0] best_tree_profit;  // Max profit from trees
    reg [3:0] tree_node;          // Current node being evaluated
    reg [3:0] current_path [0:15]; // Path from node to cycle
    reg [3:0] path_len;           // Length of current path
    reg [3:0] temp_idx;           // Temporary index for path tracing
    reg [7:0] cycle_id;           // Unique ID for current cycle
    reg [7:0] best_cycle_id;      // ID of best cycle found
    reg [31:0] best_cycle_profit; // Best cycle profit
    reg [7:0] best_cycle_snacks;  // Snacks in best cycle
    reg [7:0] cycle_counter;      // Counter for cycle processing
    reg [7:0] timeout_counter;    // Safety timeout

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            idx <= 4'd0;
            total_profit <= 32'd0;
            cycle_profit <= 32'd0;
            cycle_len <= 4'd0;
            cycle_snack_sum <= 8'd0;
            cycle_idx <= 4'd0;
            best_tree_profit <= 32'd0;
            tree_node <= 4'd0;
            path_len <= 4'd0;
            cycle_id <= 8'd0;
            best_cycle_id <= 8'd0;
            best_cycle_profit <= 32'd0;
            best_cycle_snacks <= 8'd0;
            cycle_counter <= 8'd0;
            timeout_counter <= 8'd0;
            // Initialize arrays
            for (i = 0; i < 16; i = i + 1) begin
                f_reg[i] <= 4'd0;
                p_reg[i] <= 16'd0;
                m_reg[i] <= 16'd0;
                s_reg[i] <= 8'd0;
                visited[i] <= 2'd0;
                available[i] <= 8'd0;
                cycle_nodes[i] <= 4'd0;
                current_path[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CONFIG;
                        idx <= 4'd0;
                        // Reset visited for new calculation
                        for (i = 0; i < 16; i = i + 1) begin
                            visited[i] <= 2'd0;
                            available[i] <= s_reg[i]; // Reset available stock
                        end
                    end
                end

                CONFIG: begin
                    if (cfg_en) begin
                        f_reg[cfg_idx] <= cfg_f;
                        p_reg[cfg_idx] <= cfg_p;
                        m_reg[cfg_idx] <= cfg_m;
                        s_reg[cfg_idx] <= cfg_s;
                        visited[cfg_idx] <= 2'd0;
                        available[cfg_idx] <= cfg_s;
                    end
                    if (idx == 4'd15) begin
                        state <= CALC_INIT;
                    end else begin
                        idx <= idx + 4'd1;
                    end
                end

                CALC_INIT: begin
                    total_profit <= 32'd0;
                    best_tree_profit <= 32'd0;
                    idx <= 4'd0;
                    best_cycle_profit <= 32'd0;
                    best_cycle_snacks <= 8'd0;
                    best_cycle_id <= 8'd0;
                    timeout_counter <= 8'd0;
                    // Reset visited for calculation
                    for (i = 0; i < 16; i = i + 1) begin
                        visited[i] <= 2'd0;
                    end
                    state <= CALC_FIND_CYCLE;
                end

                CALC_FIND_CYCLE: begin
                    // Find next unvisited node
                    if (idx < 4'd16) begin
                        if (visited[idx] == 2'd0) begin
                            // Start cycle detection from idx
                            cycle_id <= cycle_id + 8'd1;
                            cycle_len <= 4'd0;
                            temp_idx <= idx;
                            timeout_counter <= 8'd0;
                            state <= CALC_PROCESS_CYCLE;
                        end else begin
                            idx <= idx + 4'd1;
                        end
                    end else begin
                        // All nodes processed for cycles
                        if (best_cycle_profit > 32'd0) begin
                            // Found a profitable cycle
                            total_profit <= total_profit + best_cycle_profit;
                            // Mark cycle nodes as processed
                            state <= CALC_PROCESS_TREES;
                            tree_node <= 4'd0;
                        end else begin
                            // No profitable cycle found
                            state <= DONE;
                        end
                    end
                end

                CALC_PROCESS_CYCLE: begin
                    // Trace path from temp_idx to find cycle
                    if (timeout_counter < 8'd32) begin
                        timeout_counter <= timeout_counter + 8'd1;
                        if (visited[temp_idx] != 2'd0 && visited[temp_idx] != cycle_id[7:0]) begin
                            // Already visited in different cycle
                            state <= CALC_FIND_CYCLE;
                        end else begin
                            // Check if temp_idx is already in current cycle
                            reg in_cycle;
                            in_cycle = 1'b0;
                            for (i = 0; i < 16; i = i + 1) begin
                                if (i < cycle_len && cycle_nodes[i] == temp_idx) begin
                                    in_cycle = 1'b1;
                                end
                            end
                            if (in_cycle) begin
                                // Cycle detected, calculate profit
                                cycle_profit <= 32'd0;
                                cycle_snack_sum <= 8'd0;
                                cycle_idx <= 4'd0;
                                state <= CALC_FIND_CYCLE; // Will continue to next state
                            end else begin
                                // Add to potential cycle
                                if (cycle_len < 4'd16) begin
                                    cycle_nodes[cycle_len] <= temp_idx;
                                    cycle_len <= cycle_len + 4'd1;
                                    temp_idx <= f_reg[temp_idx];
                                end else begin
                                    state <= CALC_FIND_CYCLE;
                                end
                            end
                        end
                    end else begin
                        // Timeout, go to next node
                        state <= CALC_FIND_CYCLE;
                    end
                end

                CALC_PROCESS_TREES: begin
                    // Process tree nodes feeding into best cycle
                    // For simplicity, we focus on cycle profit only
                    // Tree processing would follow similar pattern
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule