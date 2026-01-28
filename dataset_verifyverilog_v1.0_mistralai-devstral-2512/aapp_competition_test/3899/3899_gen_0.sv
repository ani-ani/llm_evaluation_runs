module TaskOptimizer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] n,
    input wire [7:0] power [0:49],
    input wire [7:0] processors [0:49],
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SORT = 3'd1;
    localparam [2:0] DP_INIT = 3'd2;
    localparam [2:0] DP_COMPUTE = 3'd3;
    localparam [2:0] FINAL_CALC = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1900;

    // Sorted arrays
    reg [7:0] sorted_power [0:49];
    reg [7:0] sorted_processors [0:49];
    reg [5:0] sort_i, sort_j, sort_k;

    // DP state
    reg [22:0] dp_power [0:49][0:5000];
    reg [12:0] dp_processor [0:49][0:5000];
    reg [5:0] dp_i, dp_j, dp_k;
    reg [12:0] current_processor_sum;
    reg [22:0] current_power_sum;
    reg [22:0] min_power;
    reg [12:0] min_processor;

    // Final calculation
    reg [31:0] temp_result;
    reg [31:0] numerator;
    reg [12:0] denominator;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 10'd0;
            done <= 1'b0;
            result <= 32'd0;

            // Initialize sorting variables
            sort_i <= 6'd0;
            sort_j <= 6'd0;
            sort_k <= 6'd0;

            // Initialize DP variables
            dp_i <= 6'd0;
            dp_j <= 6'd0;
            dp_k <= 6'd0;
            current_processor_sum <= 13'd0;
            current_power_sum <= 23'd0;
            min_power <= 23'd0;
            min_processor <= 13'd0;

            // Initialize DP table
            for (dp_i = 0; dp_i < 50; dp_i = dp_i + 1) begin
                for (dp_j = 0; dp_j < 5001; dp_j = dp_j + 1) begin
                    dp_power[dp_i][dp_j] <= 23'd0;
                    dp_processor[dp_i][dp_j] <= 13'd0;
                end
            end

            // Initialize sorted arrays
            for (sort_i = 0; sort_i < 50; sort_i = sort_i + 1) begin
                sorted_power[sort_i] <= 8'd0;
                sorted_processors[sort_i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 10'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= SORT;
                        cycle_count <= 10'd0;
                    end
                end

                SORT: begin
                    // Bubble sort implementation
                    if (sort_i < n - 1) begin
                        if (sort_j < n - sort_i - 1) begin
                            if (sorted_power[sort_j] < sorted_power[sort_j + 1]) begin
                                // Swap power
                                sorted_power[sort_j] <= sorted_power[sort_j + 1];
                                sorted_power[sort_j + 1] <= sorted_power[sort_j];
                                // Swap processors
                                sorted_processors[sort_j] <= sorted_processors[sort_j + 1];
                                sorted_processors[sort_j + 1] <= sorted_processors[sort_j];
                            end
                            sort_j <= sort_j + 1;
                        end else begin
                            sort_j <= 0;
                            sort_i <= sort_i + 1;
                        end
                    end else begin
                        // Copy input to sorted arrays
                        for (sort_k = 0; sort_k < n; sort_k = sort_k + 1) begin
                            sorted_power[sort_k] <= power[sort_k];
                            sorted_processors[sort_k] <= processors[sort_k];
                        end
                        sort_i <= 0;
                        sort_j <= 0;
                        next_state <= DP_INIT;
                    end
                end

                DP_INIT: begin
                    // Initialize DP table
                    if (dp_i < 50) begin
                        if (dp_j < 5001) begin
                            dp_power[dp_i][dp_j] <= 23'd0;
                            dp_processor[dp_i][dp_j] <= 13'd0;
                            dp_j <= dp_j + 1;
                        end else begin
                            dp_j <= 0;
                            dp_i <= dp_i + 1;
                        end
                    end else begin
                        dp_i <= 0;
                        dp_j <= 0;
                        next_state <= DP_COMPUTE;
                    end
                end

                DP_COMPUTE: begin
                    // DP computation
                    if (dp_i < n) begin
                        if (dp_j < 5001) begin
                            // Option 1: Don't take current task as first
                            // Option 2: Take current task as first
                            // Option 3: Take current task as second (if possible)

                            // Initialize current state
                            current_power_sum <= dp_power[dp_i][dp_j];
                            current_processor_sum <= dp_processor[dp_i][dp_j];

                            // Option 1: Don't take current task
                            if (dp_i > 0) begin
                                if (dp_power[dp_i - 1][dp_j] < current_power_sum || 
                                    (dp_power[dp_i - 1][dp_j] == current_power_sum && 
                                     dp_processor[dp_i - 1][dp_j] < current_processor_sum)) begin
                                    current_power_sum <= dp_power[dp_i - 1][dp_j];
                                    current_processor_sum <= dp_processor[dp_i - 1][dp_j];
                                end
                            end

                            // Option 2: Take current task as first
                            if (dp_j >= sorted_processors[dp_i]) begin
                                if (dp_i > 0) begin
                                    if (dp_power[dp_i - 1][dp_j - sorted_processors[dp_i]] + 
                                        (sorted_power[dp_i] * 1000) < current_power_sum ||
                                        (dp_power[dp_i - 1][dp_j - sorted_processors[dp_i]] + 
                                        (sorted_power[dp_i] * 1000) == current_power_sum &&
                                        dp_processor[dp_i - 1][dp_j - sorted_processors[dp_i]] + 
                                        sorted_processors[dp_i] < current_processor_sum)) begin
                                        current_power_sum <= dp_power[dp_i - 1][dp_j - sorted_processors[dp_i]] + 
                                                            (sorted_power[dp_i] * 1000);
                                        current_processor_sum <= dp_processor[dp_i - 1][dp_j - sorted_processors[dp_i]] + 
                                                                sorted_processors[dp_i];
                                    end
                                end else if (dp_j == sorted_processors[dp_i]) begin
                                    if ((sorted_power[dp_i] * 1000) < current_power_sum ||
                                        ((sorted_power[dp_i] * 1000) == current_power_sum &&
                                        sorted_processors[dp_i] < current_processor_sum)) begin
                                        current_power_sum <= sorted_power[dp_i] * 1000;
                                        current_processor_sum <= sorted_processors[dp_i];
                                    end
                                end
                            end

                            // Option 3: Take current task as second (if possible)
                            if (dp_i > 0 && dp_k < dp_i) begin
                                if (sorted_power[dp_k] > sorted_power[dp_i] &&
                                    dp_j >= sorted_processors[dp_k]) begin
                                    if (dp_power[dp_i - 1][dp_j - sorted_processors[dp_k]] < current_power_sum ||
                                        (dp_power[dp_i - 1][dp_j - sorted_processors[dp_k]] == current_power_sum &&
                                        dp_processor[dp_i - 1][dp_j - sorted_processors[dp_k]] < current_processor_sum)) begin
                                        current_power_sum <= dp_power[dp_i - 1][dp_j - sorted_processors[dp_k]];
                                        current_processor_sum <= dp_processor[dp_i - 1][dp_j - sorted_processors[dp_k]];
                                    end
                                end
                                dp_k <= dp_k + 1;
                            end else begin
                                dp_k <= 0;
                            end

                            // Update DP table
                            dp_power[dp_i][dp_j] <= current_power_sum;
                            dp_processor[dp_i][dp_j] <= current_processor_sum;

                            dp_j <= dp_j + 1;
                        end else begin
                            dp_j <= 0;
                            dp_i <= dp_i + 1;
                        end
                    end else begin
                        dp_i <= 0;
                        dp_j <= 0;
                        next_state <= FINAL_CALC;
                    end
                end

                FINAL_CALC: begin
                    // Find minimum average
                    if (dp_j < 5001) begin
                        if (dp_processor[n - 1][dp_j] > 0) begin
                            if (min_processor == 0 ||
                                (dp_power[n - 1][dp_j] * 1000) / dp_processor[n - 1][dp_j] <
                                (min_power * 1000) / min_processor) begin
                                min_power <= dp_power[n - 1][dp_j];
                                min_processor <= dp_processor[n - 1][dp_j];
                            end
                        end
                        dp_j <= dp_j + 1;
                    end else begin
                        // Calculate final result
                        if (min_processor > 0) begin
                            numerator <= min_power * 1000;
                            denominator <= min_processor;
                            temp_result <= (numerator + denominator - 1) / denominator;
                            result <= temp_result;
                        end else begin
                            result <= 32'd0;
                        end
                        next_state <= DONE_STATE;
                        dp_j <= 0;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule