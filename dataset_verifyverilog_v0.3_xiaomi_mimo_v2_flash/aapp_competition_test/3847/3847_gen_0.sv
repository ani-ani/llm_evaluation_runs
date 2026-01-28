module find_max_area(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] m,
    input [7:0] a [0:7],
    input [7:0] b [0:7],
    input [31:0] x,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] INIT      = 4'd1;
    localparam [3:0] PREFIX_A  = 4'd2;
    localparam [3:0] MIN_ROW   = 4'd3;
    localparam [3:0] PREFIX_B  = 4'd4;
    localparam [3:0] MIN_COL   = 4'd5;
    localparam [3:0] MAX_AREA  = 4'd6;
    localparam [3:0] DONE      = 4'd7;
    localparam [3:0] WAIT      = 4'd8;

    reg [3:0] state;
    reg [3:0] next_state;
    
    // Internal registers
    reg [7:0] i, j;           // Loop counters
    reg [7:0] len;            // Length counter
    reg [15:0] area;          // Current area
    reg [15:0] max_area_reg;  // Maximum area found
    reg [31:0] min_sum_a [0:7]; // Minimum sum for each length L (1-8)
    reg [31:0] min_sum_b [0:7]; // Minimum sum for each length L (1-8)
    reg [31:0] pref_a [0:8];    // Prefix sums for a (size n+1)
    reg [31:0] pref_b [0:8];    // Prefix sums for b (size m+1)
    reg [31:0] curr_sum;        // Current segment sum
    reg [31:0] product;         // Product of sums
    reg [7:0] cycle_count;      // Cycle counter for timeout
    localparam [7:0] MAX_CYCLES = 8'd150;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE:      next_state = start ? INIT : IDLE;
            INIT:      next_state = PREFIX_A;
            PREFIX_A:  next_state = (i >= n) ? MIN_ROW : PREFIX_A;
            MIN_ROW:   next_state = (i > n) ? PREFIX_B : MIN_ROW;
            PREFIX_B:  next_state = (j >= m) ? MIN_COL : PREFIX_B;
            MIN_COL:   next_state = (j > m) ? MAX_AREA : MIN_COL;
            MAX_AREA:  next_state = (i > n) ? WAIT : MAX_AREA;
            WAIT:      next_state = (cycle_count >= 8'd5) ? DONE : WAIT;
            DONE:      next_state = IDLE;
            default:   next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            i <= 8'd0;
            j <= 8'd0;
            len <= 8'd0;
            area <= 16'd0;
            max_area_reg <= 16'd0;
            curr_sum <= 32'd0;
            product <= 32'd0;
            cycle_count <= 8'd0;
            // Initialize arrays
            for (i = 0; i < 8; i = i + 1) begin
                min_sum_a[i] <= 32'd0;
                min_sum_b[i] <= 32'd0;
                pref_a[i] <= 32'd0;
                pref_b[i] <= 32'd0;
            end
            pref_a[8] <= 32'd0;
            pref_b[8] <= 32'd0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    i <= 8'd0;
                    j <= 8'd0;
                    len <= 8'd0;
                    max_area_reg <= 16'd0;
                    cycle_count <= 8'd0;
                end
                
                INIT: begin
                    i <= 8'd0;
                    // Initialize min sums to max value
                    for (i = 0; i < 8; i = i + 1) begin
                        min_sum_a[i] <= 32'hFFFFFFFF;
                        min_sum_b[i] <= 32'hFFFFFFFF;
                    end
                    i <= 8'd0;
                end
                
                PREFIX_A: begin
                    pref_a[i] <= (i == 0) ? 32'd0 : (pref_a[i-1] + {24'd0, a[i-1]});
                    i <= i + 8'd1;
                end
                
                MIN_ROW: begin
                    // Compute minimum sum for each length L
                    for (len = 1; len <= 8; len = len + 1) begin
                        if (len <= n && i >= len) begin
                            curr_sum <= pref_a[i] - pref_a[i - len];
                        end
                    end
                    // Update min_sum for each length
                    for (len = 1; len <= 8; len = len + 1) begin
                        if (len <= n && i >= len) begin
                            if (curr_sum < min_sum_a[len-1]) begin
                                min_sum_a[len-1] <= curr_sum;
                            end
                        end
                    end
                    i <= i + 8'd1;
                end
                
                PREFIX_B: begin
                    pref_b[j] <= (j == 0) ? 32'd0 : (pref_b[j-1] + {24'd0, b[j-1]});
                    j <= j + 8'd1;
                end
                
                MIN_COL: begin
                    // Compute minimum sum for each length L
                    for (len = 1; len <= 8; len = len + 1) begin
                        if (len <= m && j >= len) begin
                            curr_sum <= pref_b[j] - pref_b[j - len];
                        end
                    end
                    // Update min_sum for each length
                    for (len = 1; len <= 8; len = len + 1) begin
                        if (len <= m && j >= len) begin
                            if (curr_sum < min_sum_b[len-1]) begin
                                min_sum_b[len-1] <= curr_sum;
                            end
                        end
                    end
                    j <= j + 8'd1;
                end
                
                MAX_AREA: begin
                    // Check all pairs (L1, L2)
                    for (len = 1; len <= 8; len = len + 1) begin
                        // len represents L1, loop through L2 inside
                    end
                    // Single iteration per cycle
                    if (i > 0 && i <= n && j > 0 && j <= m) begin
                        product <= min_sum_a[i-1] * min_sum_b[j-1];
                    end
                    if (product <= x) begin
                        area <= i * j;
                        if (area > max_area_reg) begin
                            max_area_reg <= area;
                        end
                    end
                    // Increment j, then i
                    if (j < m) begin
                        j <= j + 8'd1;
                    end else begin
                        j <= 8'd1;
                        i <= i + 8'd1;
                    end
                end
                
                WAIT: begin
                    cycle_count <= cycle_count + 8'd1;
                end
                
                DONE: begin
                    result <= max_area_reg;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule