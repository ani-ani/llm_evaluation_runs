module min_worst_case_time (
    input clk,
    input rst_n,
    input start,
    input [9:0] n,
    input [7:0] r,
    input [7:0] p,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] UPDATE = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state;
    reg [9:0] dp_table [0:1024];  // DP table for T(n)
    reg [9:0] i;  // Current n being computed
    reg [9:0] k;  // Split position
    reg [15:0] temp_max;
    reg [15:0] temp_time;
    reg [15:0] best_time;
    reg [9:0] max_n;  // Target n value
    reg [12:0] cycle_count;  // Cycle counter (up to 5000)
    localparam [12:0] MAX_CYCLES = 13'd5000;

    integer idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            i <= 10'd0;
            k <= 10'd0;
            temp_max <= 16'd0;
            temp_time <= 16'd0;
            best_time <= 16'd0;
            max_n <= 10'd0;
            cycle_count <= 13'd0;
            // Initialize DP table
            for (idx = 0; idx < 1025; idx = idx + 1) begin
                dp_table[idx] <= 10'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 13'd0;
                    if (start && n >= 10'd1 && n <= 10'd1024) begin
                        max_n <= n;
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Initialize DP table for n=1 (base case)
                    dp_table[10'd1] <= 10'd0;
                    i <= 10'd2;  // Start computing from n=2
                    k <= 10'd1;  // Initialize split position
                    best_time <= 16'hFFFF;  // Initialize best time to max
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    // Compute time for split k: p + r + max(T(k), T(n-k))
                    // First, compute max(T(k), T(n-k))
                    if (dp_table[k] > dp_table[i - k]) begin
                        temp_max <= {6'd0, dp_table[k]};  // Extend to 16 bits
                    end else begin
                        temp_max <= {6'd0, dp_table[i - k]};
                    end
                    state <= UPDATE;
                end

                UPDATE: begin
                    // Add p + r to temp_max
                    temp_time <= temp_max + {8'd0, p} + {8'd0, r};
                    
                    // Update best_time if this split is better
                    if (temp_time < best_time) begin
                        best_time <= temp_time;
                    end
                    
                    // Move to next split
                    k <= k + 10'd1;
                    
                    // Check if we've tried all splits (1 to i-1)
                    if (k >= i - 10'd1) begin
                        // Done with this i, store result
                        dp_table[i] <= best_time[9:0];  // Store in table
                        
                        // Move to next n
                        i <= i + 10'd1;
                        
                        // Check if we're done
                        if (i >= max_n) begin
                            result <= best_time;
                            state <= FINISH;
                        end else begin
                            // Reset for next n
                            k <= 10'd1;
                            best_time <= 16'hFFFF;
                            cycle_count <= cycle_count + 13'd1;
                            // Check cycle limit
                            if (cycle_count >= MAX_CYCLES) begin
                                result <= 16'd0;
                                state <= FINISH;
                            end else begin
                                state <= COMPUTE;
                            end
                        end
                    end else begin
                        cycle_count <= cycle_count + 13'd1;
                        // Check cycle limit
                        if (cycle_count >= MAX_CYCLES) begin
                            result <= 16'd0;
                            state <= FINISH;
                        end else begin
                            state <= COMPUTE;
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    result <= 16'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule