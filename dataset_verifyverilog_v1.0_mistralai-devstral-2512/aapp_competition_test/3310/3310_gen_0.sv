module RestaurantDP(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] g,
    input wire [7:0] t,
    input wire [3:0] n,
    input wire [7:0] c [0:15],
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SORT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Scaled parameters
    reg [3:0] n_scaled;
    reg [3:0] t_scaled;
    reg [3:0] g_scaled;
    reg [3:0] c_scaled [0:15];

    // Sorted table capacities
    reg [3:0] sorted_c [0:15];

    // DP state variables
    reg [15:0] current_mask;
    reg [3:0] current_group [0:15];
    reg signed [31:0] current_prob;
    reg signed [31:0] dp [0:65535];
    reg [15:0] state_index;

    // Fixed-point constants
    localparam [31:0] ONE = 32'd65536;
    localparam [31:0] HALF = 32'd32768;

    // Bubble sort implementation
    reg [3:0] sort_i;
    reg [3:0] sort_j;
    reg [3:0] sort_temp;

    // DP computation variables
    reg [3:0] hour;
    reg [15:0] mask;
    reg [3:0] group [0:15];
    reg [3:0] next_group [0:15];
    reg [15:0] next_mask;
    reg signed [31:0] prob;
    reg signed [31:0] new_prob;
    reg [3:0] table_idx;
    reg [3:0] group_size;
    reg [3:0] min_table;
    reg [3:0] min_capacity;
    reg found;

    // Result accumulation
    reg signed [31:0] expected;
    reg [3:0] people;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            n_scaled <= 4'd0;
            t_scaled <= 4'd0;
            g_scaled <= 4'd0;
            for (sort_i = 0; sort_i < 16; sort_i = sort_i + 1) begin
                c_scaled[sort_i] <= 4'd0;
                sorted_c[sort_i] <= 4'd0;
            end
            for (state_index = 0; state_index < 65536; state_index = state_index + 1) begin
                dp[state_index] <= 32'd0;
            end
            current_mask <= 16'd0;
            for (sort_i = 0; sort_i < 16; sort_i = sort_i + 1) begin
                current_group[sort_i] <= 4'd0;
            end
            current_prob <= 32'd0;
            sort_i <= 4'd0;
            sort_j <= 4'd0;
            sort_temp <= 4'd0;
            hour <= 4'd0;
            mask <= 16'd0;
            for (sort_i = 0; sort_i < 16; sort_i = sort_i + 1) begin
                group[sort_i] <= 4'd0;
                next_group[sort_i] <= 4'd0;
            end
            next_mask <= 16'd0;
            prob <= 32'd0;
            new_prob <= 32'd0;
            table_idx <= 4'd0;
            group_size <= 4'd0;
            min_table <= 4'd0;
            min_capacity <= 4'd0;
            found <= 1'b0;
            expected <= 32'd0;
            people <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Scale inputs
                        n_scaled <= n[3:0];
                        t_scaled <= t[3:0];
                        g_scaled <= g[3:0];
                        for (sort_i = 0; sort_i < 16; sort_i = sort_i + 1) begin
                            c_scaled[sort_i] <= c[sort_i][3:0];
                        end
                        state <= SORT;
                    end
                end

                SORT: begin
                    // Bubble sort for table capacities
                    if (sort_i < n_scaled) begin
                        if (sort_j < n_scaled - sort_i - 1) begin
                            if (c_scaled[sort_j] > c_scaled[sort_j + 1]) begin
                                sort_temp <= c_scaled[sort_j];
                                c_scaled[sort_j] <= c_scaled[sort_j + 1];
                                c_scaled[sort_j + 1] <= sort_temp;
                            end
                            sort_j <= sort_j + 1;
                        end else begin
                            sort_j <= 4'd0;
                            sort_i <= sort_i + 1;
                        end
                    end else begin
                        // Copy sorted capacities
                        for (sort_i = 0; sort_i < 16; sort_i = sort_i + 1) begin
                            sorted_c[sort_i] <= c_scaled[sort_i];
                        end
                        // Initialize DP
                        dp[0] <= ONE;
                        for (state_index = 1; state_index < 65536; state_index = state_index + 1) begin
                            dp[state_index] <= 32'd0;
                        end
                        state <= COMPUTE;
                        hour <= 4'd0;
                        mask <= 16'd0;
                        for (sort_i = 0; sort_i < 16; sort_i = sort_i + 1) begin
                            group[sort_i] <= 4'd0;
                        end
                        prob <= 32'd0;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (hour < t_scaled) begin
                        if (mask < (1 << n_scaled)) begin
                            // Decode current state
                            for (table_idx = 0; table_idx < n_scaled; table_idx = table_idx + 1) begin
                                group[table_idx] <= mask[(table_idx*4)+3:(table_idx*4)];
                            end
                            prob <= dp[mask];
                            
                            if (prob > 32'd0) begin
                                // Try all possible group sizes
                                for (group_size = 1; group_size <= g_scaled; group_size = group_size + 1) begin
                                    // Find smallest unoccupied table with capacity >= group_size
                                    found <= 1'b0;
                                    min_table <= 4'd0;
                                    min_capacity <= 4'd255;
                                    for (table_idx = 0; table_idx < n_scaled; table_idx = table_idx + 1) begin
                                        if (!group[table_idx] && sorted_c[table_idx] >= group_size) begin
                                            if (sorted_c[table_idx] < min_capacity) begin
                                                min_capacity <= sorted_c[table_idx];
                                                min_table <= table_idx;
                                                found <= 1'b1;
                                            end
                                        end
                                    end
                                    
                                    if (found) begin
                                        // Create next state
                                        next_mask <= mask;
                                        for (table_idx = 0; table_idx < n_scaled; table_idx = table_idx + 1) begin
                                            next_group[table_idx] <= group[table_idx];
                                        end
                                        next_group[min_table] <= group_size;
                                        
                                        // Encode next state
                                        for (table_idx = 0; table_idx < n_scaled; table_idx = table_idx + 1) begin
                                            next_mask[(table_idx*4)+3:(table_idx*4)] <= next_group[table_idx];
                                        end
                                        
                                        // Update probability (multiply by 1/g_scaled)
                                        new_prob <= prob * (ONE / g_scaled);
                                        dp[next_mask] <= dp[next_mask] + new_prob;
                                    end
                                end
                            end
                            
                            // Move to next state
                            mask <= mask + 1;
                        end else begin
                            // Move to next hour
                            hour <= hour + 1;
                            mask <= 16'd0;
                            for (table_idx = 0; table_idx < 16; table_idx = table_idx + 1) begin
                                group[table_idx] <= 4'd0;
                            end
                        end
                    end else begin
                        // Compute expected value
                        expected <= 32'd0;
                        for (mask = 0; mask < (1 << n_scaled); mask = mask + 1) begin
                            prob <= dp[mask];
                            if (prob > 32'd0) begin
                                people <= 4'd0;
                                for (table_idx = 0; table_idx < n_scaled; table_idx = table_idx + 1) begin
                                    people <= people + mask[(table_idx*4)+3:(table_idx*4)];
                                end
                                expected <= expected + (prob * people);
                            end
                        end
                        result <= expected;
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule