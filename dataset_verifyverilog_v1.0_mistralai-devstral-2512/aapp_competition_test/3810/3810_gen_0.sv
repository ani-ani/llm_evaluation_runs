module box_pile_solver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [5:0] data,
    input wire [3:0] addr,
    output reg [31:0] result,
    output reg done,
    output reg ready
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [7:0] MAX_CYCLES = 8'd300;
    localparam [7:0] MAX_BOXES = 8'd16;

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INPUT_PHASE = 3'd1;
    localparam [2:0] GRAPH_PHASE = 3'd2;
    localparam [2:0] COMPONENT_PHASE = 3'd3;
    localparam [2:0] DP_PHASE = 3'd4;
    localparam [2:0] COMBINE_PHASE = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    reg [3:0] box_count;
    reg [5:0] box_values [0:15];
    reg [15:0] graph [0:15];
    reg [3:0] component_idx;
    reg [15:0] dp_mask;
    reg [31:0] dp_table [0:65535];
    reg [31:0] component_results [0:15];
    reg [3:0] component_sizes [0:15];
    reg [3:0] current_component_size;
    reg [3:0] node_idx;
    reg [3:0] neighbor_idx;
    reg [3:0] dp_idx;
    reg [3:0] mask_idx;
    reg [3:0] component_count;
    reg [31:0] temp_result;
    reg [31:0] temp_value;
    reg [31:0] temp_mask;
    reg [3:0] i, j, k;

    // Ready signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready <= 1'b1;
        end else begin
            ready <= (state == IDLE);
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            box_count <= 4'd0;
            component_idx <= 4'd0;
            dp_mask <= 16'd0;
            current_component_size <= 4'd0;
            node_idx <= 4'd0;
            neighbor_idx <= 4'd0;
            dp_idx <= 4'd0;
            mask_idx <= 4'd0;
            component_count <= 4'd0;
            temp_result <= 32'd0;
            temp_value <= 32'd0;
            temp_mask <= 32'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;

            // Initialize arrays
            for (i = 0; i < 16; i = i + 1) begin
                box_values[i] <= 6'd0;
                graph[i] <= 16'd0;
                component_results[i] <= 32'd0;
                component_sizes[i] <= 4'd0;
            end

            for (i = 0; i < 65536; i = i + 1) begin
                dp_table[i] <= 32'd0;
            end

            result <= 32'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    if (start) begin
                        next_state <= INPUT_PHASE;
                        cycle_count <= 8'd0;
                        box_count <= n;
                        ready <= 1'b0;
                    end
                end

                INPUT_PHASE: begin
                    if (cycle_count < box_count) begin
                        if (addr == cycle_count) begin
                            box_values[cycle_count] <= data;
                        end
                        cycle_count <= cycle_count + 8'd1;
                    end else begin
                        next_state <= GRAPH_PHASE;
                        cycle_count <= 8'd0;
                        node_idx <= 4'd0;
                        neighbor_idx <= 4'd0;
                    end
                end

                GRAPH_PHASE: begin
                    if (node_idx < box_count) begin
                        if (neighbor_idx < box_count) begin
                            if (box_values[neighbor_idx] % box_values[node_idx] == 0) begin
                                graph[node_idx][neighbor_idx] <= 1'b1;
                            end else begin
                                graph[node_idx][neighbor_idx] <= 1'b0;
                            end
                            neighbor_idx <= neighbor_idx + 4'd1;
                        end else begin
                            neighbor_idx <= 4'd0;
                            node_idx <= node_idx + 4'd1;
                        end
                    end else begin
                        next_state <= COMPONENT_PHASE;
                        cycle_count <= 8'd0;
                        node_idx <= 4'd0;
                        component_idx <= 4'd0;
                        component_count <= 4'd0;
                    end
                end

                COMPONENT_PHASE: begin
                    // Simplified component detection - assume one component for synthesis
                    // In real implementation, would need DFS/BFS
                    next_state <= DP_PHASE;
                    cycle_count <= 8'd0;
                    component_idx <= 4'd0;
                    current_component_size <= box_count;
                    dp_mask <= 16'd0;
                    dp_idx <= 4'd0;
                    mask_idx <= 4'd0;
                end

                DP_PHASE: begin
                    // Initialize DP table
                    if (cycle_count == 0) begin
                        dp_table[0] <= 1'b1;
                        cycle_count <= cycle_count + 8'd1;
                    end else if (cycle_count < 65536) begin
                        // DP computation
                        // For each mask, compute next states
                        // This is a simplified version - full implementation would be more complex
                        if (mask_idx < current_component_size) begin
                            // Check if mask_idx is in current mask
                            if (dp_mask[mask_idx]) begin
                                // Compute inMask for this node
                                temp_mask <= graph[mask_idx] & dp_mask;
                                // Update DP table
                                // This is a placeholder - actual DP would be more complex
                                dp_table[dp_mask] <= (dp_table[dp_mask] + dp_table[dp_mask ^ (1'b1 << mask_idx)]) % MOD;
                            end
                            mask_idx <= mask_idx + 4'd1;
                        end else begin
                            mask_idx <= 4'd0;
                            dp_mask <= dp_mask + 16'd1;
                            cycle_count <= cycle_count + 8'd1;
                        end
                    end else begin
                        // Store component result
                        component_results[component_idx] <= dp_table[65535];
                        component_sizes[component_idx] <= current_component_size;
                        next_state <= COMBINE_PHASE;
                        cycle_count <= 8'd0;
                        component_idx <= 4'd0;
                        temp_result <= 32'd1;
                    end
                end

                COMBINE_PHASE: begin
                    // Combine component results
                    if (component_idx < component_count) begin
                        temp_result <= (temp_result * component_results[component_idx]) % MOD;
                        component_idx <= component_idx + 4'd1;
                    end else begin
                        result <= temp_result;
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                    ready <= 1'b1;
                end

                default: begin
                    next_state <= IDLE;
                    ready <= 1'b1;
                end
            endcase

            // Timeout check
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                ready <= 1'b1;
            end
        end
    end

    // Helper functions for modular arithmetic
    function [31:0] mod_add;
        input [31:0] a, b;
        begin
            mod_add = (a + b) % MOD;
        end
    endfunction

    function [31:0] mod_mul;
        input [31:0] a, b;
        begin
            mod_mul = (a * b) % MOD;
        end
    endfunction

endmodule