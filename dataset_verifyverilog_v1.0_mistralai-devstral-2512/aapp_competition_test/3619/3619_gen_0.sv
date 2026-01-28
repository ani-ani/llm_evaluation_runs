module employee_team_selector(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] k,
    input wire [3:0] n,
    input wire [15:0] employee_salary [0:15],
    input wire [15:0] employee_productivity [0:15],
    input wire [3:0] employee_recommender [0:15],
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] BINARY_SEARCH = 3'd1;
    localparam [2:0] TREE_DP = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    reg [2:0] state, next_state;
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // Binary search variables
    reg [31:0] low_ratio;
    reg [31:0] high_ratio;
    reg [31:0] mid_ratio;
    reg [4:0] search_iter;
    localparam [4:0] MAX_ITER = 5'd12;

    // Tree DP variables
    reg [31:0] dp [0:15][0:8];
    reg [3:0] current_node;
    reg [3:0] current_count;
    reg [31:0] current_value;
    reg [31:0] max_value;
    reg [31:0] temp_value;

    // Helper variables
    reg [31:0] productivity_sum;
    reg [31:0] salary_sum;
    reg [31:0] weighted_value;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 10'd0;
            low_ratio <= 32'd0;
            high_ratio <= 32'd65536;
            mid_ratio <= 32'd0;
            search_iter <= 5'd0;
            current_node <= 4'd0;
            current_count <= 4'd0;
            current_value <= 32'd0;
            max_value <= 32'd0;
            temp_value <= 32'd0;
            productivity_sum <= 32'd0;
            salary_sum <= 32'd0;
            weighted_value <= 32'd0;
            done <= 1'b0;
            result <= 32'd0;

            // Initialize DP table
            integer i, j;
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 9; j = j + 1) begin
                    dp[i][j] <= 32'd0;
                end
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 10'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    if (start) begin
                        next_state <= BINARY_SEARCH;
                        low_ratio <= 32'd0;
                        high_ratio <= 32'd65536;
                        search_iter <= 5'd0;
                        max_value <= 32'd0;
                    end
                end

                BINARY_SEARCH: begin
                    if (search_iter < MAX_ITER) begin
                        mid_ratio <= (low_ratio + high_ratio) >>> 1;
                        next_state <= TREE_DP;
                        current_node <= 4'd0;
                        current_count <= 4'd0;
                        current_value <= 32'd0;

                        // Initialize DP table
                        integer i, j;
                        for (i = 0; i < 16; i = i + 1) begin
                            for (j = 0; j < 9; j = j + 1) begin
                                dp[i][j] <= 32'd0;
                            end
                        end
                    end else begin
                        next_state <= FINISH;
                        result <= max_value;
                    end
                end

                TREE_DP: begin
                    // Tree DP computation
                    if (current_node < n) begin
                        if (current_count < k) begin
                            // Calculate weighted value
                            productivity_sum <= {16'd0, employee_productivity[current_node]};
                            salary_sum <= {16'd0, employee_salary[current_node]};
                            weighted_value <= productivity_sum - (mid_ratio * salary_sum) >>> 16;

                            // Update DP table
                            if (current_node == 1'b0) begin
                                dp[current_node][current_count + 1] <= weighted_value;
                            end else begin
                                temp_value <= dp[employee_recommender[current_node]][current_count] + weighted_value;
                                if (temp_value > dp[current_node][current_count + 1]) begin
                                    dp[current_node][current_count + 1] <= temp_value;
                                end
                            end

                            // Move to next count
                            current_count <= current_count + 1;
                        end else begin
                            current_count <= 4'd0;
                            current_node <= current_node + 1;
                        end
                    end else begin
                        // Check if feasible
                        if (dp[0][k] >= 32'd0) begin
                            max_value <= mid_ratio;
                            low_ratio <= mid_ratio + 32'd1;
                        end else begin
                            high_ratio <= mid_ratio - 32'd1;
                        end
                        search_iter <= search_iter + 5'd1;
                        next_state <= BINARY_SEARCH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule