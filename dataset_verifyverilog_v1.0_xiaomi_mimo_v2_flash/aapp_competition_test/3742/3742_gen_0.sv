module garland_minimizer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] n,          // Number of bulbs (max 16)
    input wire [7:0] p_0, p_1, p_2, p_3, p_4, p_5, p_6, p_7,
    input wire [7:0] p_8, p_9, p_10, p_11, p_12, p_13, p_14, p_15,
    output reg [4:0] result,
    output reg done
);

    // Constants
    localparam [3:0] MAX_N = 4'd16;
    localparam [3:0] MAX_E = 4'd8;
    localparam [4:0] INF = 5'b11111;
    
    // State machine states
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] PRECOMPUTE = 3'd1;
    localparam [2:0] INIT_DP    = 3'd2;
    localparam [2:0] DP_ITER    = 3'd3;
    localparam [2:0] FINALIZE   = 3'd4;
    
    reg [2:0] state;
    
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
    reg [2:0] stored_q;
    reg [4:0] stored_cost;
    reg [3:0] missing_count_i;
    reg [3:0] placed_odds;
    
    integer i, e;
    
    // Helper wires
    wire [7:0] current_p;
    assign current_p = p_arr[i_counter];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 5'd0;
            i_counter <= 5'd0;
            e_counter <= 4'd0;
            p_counter <= 1'b0;
            stored_q <= 3'd0;
            stored_cost <= 5'd0;
            missing_count_i <= 4'd0;
            placed_odds <= 4'd0;
            total_odd <= 4'd0;
            total_even <= 4'd0;
            missing_odd <= 4'd0;
            missing_even <= 4'd0;
            odd_count <= 4'd0;
            even_count <= 4'd0;
            
            // Initialize all arrays
            for (i = 0; i < 16; i = i + 1) begin
                p_arr[i] <= 8'd0;
            end
            for (i = 0; i < 17; i = i + 1) begin
                fixed_count[i] <= 5'd0;
            end
            for (e = 0; e <= 8; e = e + 1) begin
                dp_cur[e][0] <= INF;
                dp_cur[e][1] <= INF;
                dp_next[e][0] <= INF;
                dp_next[e][1] <= INF;
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
                        
                        // Initialize counters
                        odd_count <= 4'd0;
                        even_count <= 4'd0;
                        fixed_count[0] <= 5'd0;
                        i <= 0;
                    end
                end
                
                PRECOMPUTE: begin
                    // Compute fixed_count and count existing odds/evens
                    if (i < 16) begin
                        if (i < n) begin
                            if (p_arr[i] != 8'd0) begin
                                if (p_arr[i][0]) begin
                                    odd_count <= odd_count + 4'd1;
                                end else begin
                                    even_count <= even_count + 4'd1;
                                end
                                fixed_count[i+1] <= fixed_count[i] + 5'd1;
                            end else begin
                                fixed_count[i+1] <= fixed_count[i];
                            end
                        end else begin
                            fixed_count[i+1] <= fixed_count[i];
                        end
                        i <= i + 1;
                    end else begin
                        // Compute totals
                        total_odd <= (n + 6'd1) >> 1;
                        total_even <= n >> 1;
                        
                        // Compute missing counts
                        missing_odd <= ((n + 6'd1) >> 1) - odd_count;
                        missing_even <= (n >> 1) - even_count;
                        
                        state <= INIT_DP;
                        i <= 0;
                    end
                end
                
                INIT_DP: begin
                    // Initialize DP arrays
                    for (e = 0; e <= 8; e = e + 1) begin
                        dp_cur[e][0] <= INF;
                        dp_cur[e][1] <= INF;
                        dp_next[e][0] <= INF;
                        dp_next[e][1] <= INF;
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
                            for (e = 0; e <= 8; e = e + 1) begin
                                dp_cur[e][0] <= dp_next[e][0];
                                dp_cur[e][1] <= dp_next[e][1];
                                dp_next[e][0] <= INF;
                                dp_next[e][1] <= INF;
                            end
                        end else begin
                            // Process current (e_counter, p_counter) state
                            if (dp_cur[e_counter][p_counter] != INF) begin
                                if (current_p != 8'd0) begin
                                    // Fixed element
                                    stored_q <= {1'b0, current_p[0]};  // 0 for even, 1 for odd
                                    stored_cost <= (p_counter != current_p[0]) ? 5'd1 : 5'd0;
                                    
                                    // Update dp_next
                                    if (dp_cur[e_counter][p_counter] + stored_cost < dp_next[e_counter][stored_q]) begin
                                        dp_next[e_counter][stored_q] <= dp_cur[e_counter][p_counter] + stored_cost;
                                    end
                                end else begin
                                    // Missing element
                                    missing_count_i <= i_counter - fixed_count[i_counter];
                                    // Wait one cycle for calculation
                                    state <= state;
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
            
            // Handle missing element updates (post-calculation)
            if (state == DP_ITER && current_p == 8'd0 && dp_cur[e_counter][p_counter] != INF && i_counter < n) begin
                placed_odds <= missing_count_i - e_counter;
                
                // Option 1: Place even
                if (e_counter < missing_even) begin
                    if (dp_cur[e_counter][p_counter] + ((p_counter != 1'b0) ? 5'd1 : 5'd0) < dp_next[e_counter+1][0]) begin
                        dp_next[e_counter+1][0] <= dp_cur[e_counter][p_counter] + ((p_counter != 1'b0) ? 5'd1 : 5'd0);
                    end
                end
                
                // Option 2: Place odd
                if (placed_odds < missing_odd) begin
                    if (dp_cur[e_counter][p_counter] + ((p_counter != 1'b1) ? 5'd1 : 5'd0) < dp_next[e_counter][1]) begin
                        dp_next[e_counter][1] <= dp_cur[e_counter][p_counter] + ((p_counter != 1'b1) ? 5'd1 : 5'd0);
                    end
                end
            end
        end
    end

endmodule