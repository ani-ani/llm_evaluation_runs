module garland_minimizer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] n,
    input wire [7:0] p_0, p_1, p_2, p_3, p_4, p_5, p_6, p_7,
    input wire [7:0] p_8, p_9, p_10, p_11, p_12, p_13, p_14, p_15,
    output reg [4:0] result,
    output reg done
);

    // State machine states
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PRECOMPUTE = 2'd1;
    localparam [1:0] INIT_DP = 2'd2;
    localparam [1:0] DP_ITER = 2'd3;
    localparam [1:0] FINALIZE = 2'd4;
    
    reg [1:0] state;
    
    // Input storage
    reg [7:0] p_arr [0:15];
    
    // Precomputation registers
    reg [4:0] fixed_count [0:16];
    reg [3:0] total_odd, total_even;
    reg [3:0] missing_odd, missing_even;
    reg [3:0] odd_count, even_count;
    
    // DP registers
    reg [4:0] dp_cur [0:8] [0:1];
    reg [4:0] dp_next [0:8] [0:1];
    
    // Iteration counters
    reg [4:0] i_counter;
    reg [3:0] e_counter;
    reg p_counter;
    
    // Helper wires
    wire [7:0] current_p;
    assign current_p = p_arr[i_counter];
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 5'd0;
            
            // Reset DP arrays
            integer e, p;
            for (e = 0; e <= 8; e = e + 1) begin
                for (p = 0; p <= 1; p = p + 1) begin
                    dp_cur[e][p] <= 5'd31;
                    dp_next[e][p] <= 5'd31;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PRECOMPUTE;
                        // Store input array
                        p_arr[0] <= p_0;  p_arr[1] <= p_1;  p_arr[2] <= p_2;  p_arr[3] <= p_3;
                        p_arr[4] <= p_4;  p_arr[5] <= p_5;  p_arr[6] <= p_6;  p_arr[7] <= p_7;
                        p_arr[8] <= p_8;  p_arr[9] <= p_9;  p_arr[10] <= p_10; p_arr[11] <= p_11;
                        p_arr[12] <= p_12; p_arr[13] <= p_13; p_arr[14] <= p_14; p_arr[15] <= p_15;
                    end
                end
                
                PRECOMPUTE: begin
                    // Initialize counters
                    odd_count <= 4'd0;
                    even_count <= 4'd0;
                    fixed_count[0] <= 5'd0;
                    
                    // Compute fixed_count and count existing odds/evens
                    integer idx;
                    for (idx = 0; idx < 16; idx = idx + 1) begin
                        if (idx < n) begin
                            if (p_arr[idx] != 8'd0) begin
                                if (p_arr[idx][0]) begin  // Odd
                                    odd_count <= odd_count + 4'd1;
                                end else begin            // Even
                                    even_count <= even_count + 4'd1;
                                end
                                fixed_count[idx+1] <= fixed_count[idx] + 5'd1;
                            end else begin
                                fixed_count[idx+1] <= fixed_count[idx];
                            end
                        end else begin
                            fixed_count[idx+1] <= fixed_count[idx];
                        end
                    end
                    
                    // Compute totals
                    total_odd <= (n + 1'b1) >> 1;
                    total_even <= n >> 1;
                    
                    state <= INIT_DP;
                end
                
                INIT_DP: begin
                    // Compute missing counts
                    missing_odd <= total_odd - odd_count;
                    missing_even <= total_even - even_count;
                    
                    // Initialize DP arrays
                    integer e, p;
                    for (e = 0; e <= 8; e = e + 1) begin
                        for (p = 0; p <= 1; p = p + 1) begin
                            dp_cur[e][p] <= 5'd31;
                            dp_next[e][p] <= 5'd31;
                        end
                    end
                    
                    // Base case: i=0
                    dp_cur[0][0] <= 5'd0;
                    dp_cur[0][1] <= 5'd0;
                    
                    // Initialize iteration counters
                    i_counter <= 5'd0;
                    e_counter <= 4'd0;
                    p_counter <= 1'b0;
                    
                    state <= DP_ITER;
                end
                
                DP_ITER: begin
                    if (i_counter < n) begin
                        // Check if we've processed all (e, p) for current i
                        if (e_counter > missing_even && p_counter == 1'b1) begin
                            // Move to next i
                            i_counter <= i_counter + 5'd1;
                            e_counter <= 4'd0;
                            p_counter <= 1'b0;
                            
                            // Copy dp_next to dp_cur for next iteration
                            integer e, p;
                            for (e = 0; e <= 8; e = e + 1) begin
                                for (p = 0; p <= 1; p = p + 1) begin
                                    dp_cur[e][p] <= dp_next[e][p];
                                    dp_next[e][p] <= 5'd31;
                                end
                            end
                        end else begin
                            // Process current (e_counter, p_counter) state
                            if (dp_cur[e_counter][p_counter] != 5'd31) begin
                                if (current_p != 8'd0) begin
                                    // Fixed element
                                    reg q;
                                    reg [4:0] cost;
                                    q = current_p[0];  // Parity (0=even, 1=odd)
                                    cost = (p_counter != q) ? 5'd1 : 5'd0;
                                    
                                    if (dp_cur[e_counter][p_counter] + cost < dp_next[e_counter][q]) begin
                                        dp_next[e_counter][q] <= dp_cur[e_counter][p_counter] + cost;
                                    end
                                end else begin
                                    // Missing element
                                    reg [3:0] missing_count_i;
                                    reg [3:0] placed_odds;
                                    reg [4:0] cost_even, cost_odd;
                                    
                                    missing_count_i = i_counter - fixed_count[i_counter];
                                    placed_odds = missing_count_i - e_counter;
                                    
                                    // Option 1: Place even
                                    if (e_counter < missing_even) begin
                                        cost_even = (p_counter != 1'b0) ? 5'd1 : 5'd0;
                                        if (dp_cur[e_counter][p_counter] + cost_even < dp_next[e_counter+1][0]) begin
                                            dp_next[e_counter+1][0] <= dp_cur[e_counter][p_counter] + cost_even;
                                        end
                                    end
                                    
                                    // Option 2: Place odd
                                    if (placed_odds < missing_odd) begin
                                        cost_odd = (p_counter != 1'b1) ? 5'd1 : 5'd0;
                                        if (dp_cur[e_counter][p_counter] + cost_odd < dp_next[e_counter][1]) begin
                                            dp_next[e_counter][1] <= dp_cur[e_counter][p_counter] + cost_odd;
                                        end
                                    end
                                end
                            end
                            
                            // Increment counters
                            if (p_counter == 1'b1) begin
                                p_counter <= 1'b0;
                                e_counter <= e_counter + 4'd1;
                            end else begin
                                p_counter <= 1'b1;
                            end
                        end
                    end else begin
                        // i_counter >= n, done with DP
                        state <= FINALIZE;
                    end
                end
                
                FINALIZE: begin
                    // Take minimum of dp_cur[missing_even][0] and dp_cur[missing_even][1]
                    if (dp_cur[missing_even][0] < dp_cur[missing_even][1]) begin
                        result <= dp_cur[missing_even][0];
                    end else begin
                        result <= dp_cur[missing_even][1];
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule