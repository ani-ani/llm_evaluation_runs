module color_count(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [5:0] K,
    input wire [3:0] f_arr [0:15],
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [31:0] MAX_CYCLES = 32'd5000;

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] COMPUTE = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state;
    reg [31:0] cycle_count;

    // Internal registers
    reg [3:0] current_node;
    reg [3:0] next_node;
    reg [3:0] component_start;
    reg [3:0] cycle_length;
    reg [3:0] tree_count;
    reg [3:0] i, j;
    reg [31:0] temp_result;
    reg [31:0] power_result;
    reg [31:0] exponent;
    reg [31:0] base;

    // Visited and in_stack arrays
    reg visited [0:15];
    reg in_stack [0:15];
    reg is_cycle [0:15];

    // Component processing
    reg [3:0] component_id;
    reg [31:0] component_result;

    // FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 32'd0;

            // Initialize arrays
            for (i = 0; i < 16; i = i + 1) begin
                visited[i] <= 1'b0;
                in_stack[i] <= 1'b0;
                is_cycle[i] <= 1'b0;
            end

            current_node <= 4'd0;
            next_node <= 4'd0;
            component_start <= 4'd0;
            cycle_length <= 4'd0;
            tree_count <= 4'd0;
            component_id <= 4'd0;
            component_result <= 32'd0;
            temp_result <= 32'd1;
            power_result <= 32'd0;
            exponent <= 32'd0;
            base <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                        cycle_count <= 32'd0;
                        temp_result <= 32'd1;
                        component_id <= 4'd0;
                    end
                end

                INIT: begin
                    // Reset internal state for new computation
                    for (i = 0; i < 16; i = i + 1) begin
                        visited[i] <= 1'b0;
                        in_stack[i] <= 1'b0;
                        is_cycle[i] <= 1'b0;
                    end
                    current_node <= 4'd0;
                    component_start <= 4'd0;
                    state <= PROCESS;
                end

                PROCESS: begin
                    // Find next unvisited node
                    if (current_node < N) begin
                        if (!visited[current_node]) begin
                            // Start processing component
                            component_start <= current_node;
                            state <= COMPUTE;
                        end else begin
                            current_node <= current_node + 4'd1;
                        end
                    end else begin
                        // All components processed
                        result <= temp_result;
                        state <= FINISH;
                    end
                end

                COMPUTE: begin
                    // Process current component
                    // Reset component state
                    cycle_length <= 4'd0;
                    tree_count <= 4'd0;
                    component_result <= 32'd1;

                    // Find cycle in component
                    // Use iterative DFS to find cycle
                    j <= component_start;
                    while (!visited[j] && !in_stack[j]) begin
                        visited[j] <= 1'b1;
                        in_stack[j] <= 1'b1;
                        next_node <= f_arr[j] - 4'd1; // Convert to 0-based
                        
                        if (next_node == j) begin
                            // Self-loop, no constraint
                            is_cycle[j] <= 1'b0;
                            tree_count <= tree_count + 4'd1;
                        end else if (in_stack[next_node]) begin
                            // Found cycle
                            cycle_length <= cycle_length + 4'd1;
                            is_cycle[j] <= 1'b1;
                            is_cycle[next_node] <= 1'b1;
                        end else begin
                            j <= next_node;
                        end
                    end

                    // Calculate component result
                    if (cycle_length > 4'd0) begin
                        // Calculate K * (K-1)^(cycle_length-1)
                        base <= K - 6'd1;
                        exponent <= {28'd0, cycle_length} - 32'd1;
                        
                        // Compute power_result = base^exponent mod MOD
                        power_result <= 32'd1;
                        for (i = 0; i < exponent; i = i + 1) begin
                            power_result <= (power_result * base) % MOD;
                        end
                        
                        component_result <= (K * power_result) % MOD;
                        
                        // Multiply by K for each tree node
                        for (i = 0; i < tree_count; i = i + 1) begin
                            component_result <= (component_result * K) % MOD;
                        end
                    end else begin
                        // All self-loops
                        component_result <= 32'd1;
                        for (i = 0; i < tree_count; i = i + 1) begin
                            component_result <= (component_result * K) % MOD;
                        end
                    end

                    // Update global result
                    temp_result <= (temp_result * component_result) % MOD;

                    // Mark all nodes in component as visited
                    for (i = 0; i < 16; i = i + 1) begin
                        if (is_cycle[i] || (i >= component_start && i < current_node)) begin
                            visited[i] <= 1'b1;
                        end
                    end

                    // Move to next node
                    current_node <= current_node + 4'd1;
                    state <= PROCESS;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Modular multiplication function
    function [31:0] mod_mult;
        input [31:0] a, b;
        begin
            mod_mult = (a * b) % MOD;
        end
    endfunction

    // Modular exponentiation function
    function [31:0] mod_pow;
        input [31:0] base, exp;
        reg [31:0] result;
        integer i;
        begin
            result = 32'd1;
            for (i = 0; i < exp; i = i + 1) begin
                result = (result * base) % MOD;
            end
            mod_pow = result;
        end
    endfunction

endmodule