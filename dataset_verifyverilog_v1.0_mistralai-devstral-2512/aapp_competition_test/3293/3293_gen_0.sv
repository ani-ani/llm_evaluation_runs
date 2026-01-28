module VendingProfitCalculator(
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
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] CONFIG  = 2'd1;
    localparam [1:0] CALC    = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // Configuration storage
    reg [3:0] f [0:15];
    reg [15:0] p [0:15];
    reg [15:0] m [0:15];
    reg [7:0] s [0:15];

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] cfg_counter;
    reg [3:0] current_node;
    reg [3:0] visited [0:15];
    reg [3:0] cycle_nodes [0:15];
    reg [3:0] cycle_count;
    reg [3:0] path_nodes [0:15];
    reg [3:0] path_count;
    reg [3:0] max_cycle_node;
    reg [31:0] max_cycle_profit;
    reg [31:0] total_profit;
    reg [3:0] cycle_start;
    reg [3:0] cycle_length;
    reg [3:0] i, j, k;
    reg [3:0] temp_node;
    reg [31:0] temp_profit;
    reg [3:0] cycle_profit_per_snack [0:15];
    reg [3:0] best_cycle;
    reg [3:0] remaining_snacks [0:15];
    reg [3:0] path_profit [0:15];
    reg [3:0] path_length [0:15];
    reg [3:0] cycle_snacks [0:15];
    reg [3:0] cycle_profit [0:15];
    reg [3:0] cycle_idx;
    reg [3:0] path_idx;
    reg [3:0] cycle_counter;
    reg [3:0] path_counter;
    reg [3:0] node_counter;
    reg [3:0] temp_idx;
    reg [3:0] temp_count;
    reg [3:0] temp_snacks;
    reg [3:0] temp_path_length;
    reg [3:0] temp_path_profit;
    reg [3:0] temp_cycle_length;
    reg [3:0] temp_cycle_profit;
    reg [3:0] temp_cycle_snacks;
    reg [3:0] temp_cycle_profit_per_snack;
    reg [3:0] temp_best_cycle;
    reg [3:0] temp_max_cycle_profit;
    reg [3:0] temp_max_cycle_node;
    reg [3:0] temp_current_node;
    reg [3:0] temp_visited;
    reg [3:0] temp_cycle_nodes;
    reg [3:0] temp_cycle_count;
    reg [3:0] temp_path_nodes;
    reg [3:0] temp_path_count;
    reg [3:0] temp_total_profit;
    reg [3:0] temp_result;
    reg [3:0] temp_done;
    reg [3:0] temp_state;
    reg [3:0] temp_next_state;
    reg [3:0] temp_cfg_counter;
    reg [3:0] temp_i;
    reg [3:0] temp_j;
    reg [3:0] temp_k;
    reg [3:0] temp_temp_node;
    reg [3:0] temp_temp_profit;
    reg [3:0] temp_cycle_start;
    reg [3:0] temp_cycle_length;
    reg [3:0] temp_cycle_profit_per_snack;
    reg [3:0] temp_best_cycle;
    reg [3:0] temp_remaining_snacks;
    reg [3:0] temp_path_profit;
    reg [3:0] temp_path_length;
    reg [3:0] temp_cycle_snacks;
    reg [3:0] temp_cycle_profit;
    reg [3:0] temp_cycle_idx;
    reg [3:0] temp_path_idx;
    reg [3:0] temp_cycle_counter;
    reg [3:0] temp_path_counter;
    reg [3:0] temp_node_counter;
    reg [3:0] temp_temp_idx;
    reg [3:0] temp_temp_count;
    reg [3:0] temp_temp_snacks;
    reg [3:0] temp_temp_path_length;
    reg [3:0] temp_temp_path_profit;
    reg [3:0] temp_temp_cycle_length;
    reg [3:0] temp_temp_cycle_profit;
    reg [3:0] temp_temp_cycle_snacks;
    reg [3:0] temp_temp_cycle_profit_per_snack;
    reg [3:0] temp_temp_best_cycle;
    reg [3:0] temp_temp_max_cycle_profit;
    reg [3:0] temp_temp_max_cycle_node;
    reg [3:0] temp_temp_current_node;
    reg [3:0] temp_temp_visited;
    reg [3:0] temp_temp_cycle_nodes;
    reg [3:0] temp_temp_cycle_count;
    reg [3:0] temp_temp_path_nodes;
    reg [3:0] temp_temp_path_count;
    reg [3:0] temp_temp_total_profit;
    reg [3:0] temp_temp_result;
    reg [3:0] temp_temp_done;
    reg [3:0] temp_temp_state;
    reg [3:0] temp_temp_next_state;
    reg [3:0] temp_temp_cfg_counter;
    reg [3:0] temp_temp_i;
    reg [3:0] temp_temp_j;
    reg [3:0] temp_temp_k;
    reg [3:0] temp_temp_temp_node;
    reg [3:0] temp_temp_temp_profit;
    reg [3:0] temp_temp_cycle_start;
    reg [3:0] temp_temp_cycle_length;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cfg_counter <= 4'd0;
            current_node <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                visited[i] <= 4'd0;
                cycle_nodes[i] <= 4'd0;
                path_nodes[i] <= 4'd0;
                cycle_profit_per_snack[i] <= 4'd0;
                remaining_snacks[i] <= 4'd0;
                path_profit[i] <= 4'd0;
                path_length[i] <= 4'd0;
                cycle_snacks[i] <= 4'd0;
                cycle_profit[i] <= 4'd0;
            end
            cycle_count <= 4'd0;
            path_count <= 4'd0;
            max_cycle_profit <= 32'd0;
            max_cycle_node <= 4'd0;
            total_profit <= 32'd0;
            cycle_start <= 4'd0;
            cycle_length <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            temp_node <= 4'd0;
            temp_profit <= 32'd0;
            cycle_idx <= 4'd0;
            path_idx <= 4'd0;
            cycle_counter <= 4'd0;
            path_counter <= 4'd0;
            node_counter <= 4'd0;
            temp_idx <= 4'd0;
            temp_count <= 4'd0;
            temp_snacks <= 4'd0;
            temp_path_length <= 4'd0;
            temp_path_profit <= 4'd0;
            temp_cycle_length <= 4'd0;
            temp_cycle_profit <= 4'd0;
            temp_cycle_snacks <= 4'd0;
            temp_cycle_profit_per_snack <= 4'd0;
            temp_best_cycle <= 4'd0;
            temp_max_cycle_profit <= 32'd0;
            temp_max_cycle_node <= 4'd0;
            temp_current_node <= 4'd0;
            temp_visited <= 4'd0;
            temp_cycle_nodes <= 4'd0;
            temp_cycle_count <= 4'd0;
            temp_path_nodes <= 4'd0;
            temp_path_count <= 4'd0;
            temp_total_profit <= 32'd0;
            temp_result <= 32'd0;
            temp_done <= 1'b0;
            temp_state <= 2'd0;
            temp_next_state <= 2'd0;
            temp_cfg_counter <= 4'd0;
            temp_i <= 4'd0;
            temp_j <= 4'd0;
            temp_k <= 4'd0;
            temp_temp_node <= 4'd0;
            temp_temp_profit <= 32'd0;
            temp_cycle_start <= 4'd0;
            temp_cycle_length <= 4'd0;
            temp_cycle_profit_per_snack <= 4'd0;
            temp_best_cycle <= 4'd0;
            temp_remaining_snacks <= 4'd0;
            temp_path_profit <= 4'd0;
            temp_path_length <= 4'd0;
            temp_cycle_snacks <= 4'd0;
            temp_cycle_profit <= 4'd0;
            temp_cycle_idx <= 4'd0;
            temp_path_idx <= 4'd0;
            temp_cycle_counter <= 4'd0;
            temp_path_counter <= 4'd0;
            temp_node_counter <= 4'd0;
            temp_temp_idx <= 4'd0;
            temp_temp_count <= 4'd0;
            temp_temp_snacks <= 4'd0;
            temp_temp_path_length <= 4'd0;
            temp_temp_path_profit <= 4'd0;
            temp_temp_cycle_length <= 4'd0;
            temp_temp_cycle_profit <= 4'd0;
            temp_temp_cycle_snacks <= 4'd0;
            temp_temp_cycle_profit_per_snack <= 4'd0;
            temp_temp_best_cycle <= 4'd0;
            temp_temp_max_cycle_profit <= 32'd0;
            temp_temp_max_cycle_node <= 4'd0;
            temp_temp_current_node <= 4'd0;
            temp_temp_visited <= 4'd0;
            temp_temp_cycle_nodes <= 4'd0;
            temp_temp_cycle_count <= 4'd0;
            temp_temp_path_nodes <= 4'd0;
            temp_temp_path_count <= 4'd0;
            temp_temp_total_profit <= 32'd0;
            temp_temp_result <= 32'd0;
            temp_temp_done <= 1'b0;
            temp_temp_state <= 2'd0;
            temp_temp_next_state <= 2'd0;
            temp_temp_cfg_counter <= 4'd0;
            temp_temp_i <= 4'd0;
            temp_temp_j <= 4'd0;
            temp_temp_k <= 4'd0;
            temp_temp_temp_node <= 4'd0;
            temp_temp_temp_profit <= 32'd0;
            temp_temp_cycle_start <= 4'd0;
            temp_temp_cycle_length <= 4'd0;
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
                    next_state = CONFIG;
                end
            end
            CONFIG: begin
                if (cfg_counter == 4'd15) begin
                    next_state = CALC;
                end
            end
            CALC: begin
                if (done) begin
                    next_state = DONE_STATE;
                end
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Configuration logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cfg_counter <= 4'd0;
        end else if (state == CONFIG && cfg_en) begin
            if (cfg_counter < 4'd16) begin
                f[cfg_idx] <= cfg_f;
                p[cfg_idx] <= cfg_p;
                m[cfg_idx] <= cfg_m;
                s[cfg_idx] <= cfg_s;
                cfg_counter <= cfg_counter + 4'd1;
            end
        end
    end

    // Calculation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialization already done in main reset
        end else if (state == CALC) begin
            // Find all cycles
            for (i = 0; i < 16; i = i + 1) begin
                if (visited[i] == 4'd0) begin
                    current_node <= i;
                    // Find cycle
                    temp_node <= current_node;
                    for (j = 0; j < 16; j = j + 1) begin
                        if (visited[temp_node] == 4'd0) begin
                            visited[temp_node] <= 4'd1;
                            temp_node <= f[temp_node];
                        end
                    end
                    // Check if we found a cycle
                    if (temp_node == current_node) begin
                        // Found a cycle
                        cycle_start <= current_node;
                        cycle_length <= 4'd0;
                        temp_node <= current_node;
                        temp_profit <= 32'd0;
                        temp_snacks <= 4'd0;
                        for (k = 0; k < 16; k = k + 1) begin
                            if (temp_node == cycle_start) begin
                                break;
                            end
                            cycle_nodes[cycle_length] <= temp_node;
                            temp_profit <= temp_profit + (m[f[temp_node]] - p[temp_node]) * s[f[temp_node]];
                            temp_snacks <= temp_snacks + s[temp_node];
                            cycle_length <= cycle_length + 4'd1;
                            temp_node <= f[temp_node];
                        end
                        cycle_profit[cycle_idx] <= temp_profit;
                        cycle_snacks[cycle_idx] <= temp_snacks;
                        if (temp_snacks > 4'd0) begin
                            cycle_profit_per_snack[cycle_idx] <= temp_profit / temp_snacks;
                        end else begin
                            cycle_profit_per_snack[cycle_idx] <= 4'd0;
                        end
                        cycle_idx <= cycle_idx + 4'd1;
                    end
                end
            end
            // Find best cycle
            max_cycle_profit <= 32'd0;
            max_cycle_node <= 4'd0;
            for (i = 0; i < cycle_idx; i = i + 1) begin
                if (cycle_profit_per_snack[i] > max_cycle_profit) begin
                    max_cycle_profit <= cycle_profit_per_snack[i];
                    max_cycle_node <= i;
                end
            end
            // Calculate total profit
            total_profit <= cycle_profit[max_cycle_node];
            // Process tree nodes
            for (i = 0; i < 16; i = i + 1) begin
                if (visited[i] == 4'd0) begin
                    // Find path to cycle
                    temp_node <= i;
                    temp_path_length <= 4'd0;
                    temp_path_profit <= 32'd0;
                    for (j = 0; j < 16; j = j + 1) begin
                        if (visited[temp_node] == 4'd1) begin
                            break;
                        end
                        path_nodes[temp_path_length] <= temp_node;
                        temp_path_profit <= temp_path_profit + (m[f[temp_node]] - p[temp_node]) * s[f[temp_node]];
                        temp_path_length <= temp_path_length + 4'd1;
                        temp_node <= f[temp_node];
                    end
                    // Add to total if profitable
                    if (temp_path_profit > 32'd0) begin
                        total_profit <= total_profit + temp_path_profit;
                    end
                end
            end
            result <= total_profit;
            done <= 1'b1;
        end
    end

endmodule