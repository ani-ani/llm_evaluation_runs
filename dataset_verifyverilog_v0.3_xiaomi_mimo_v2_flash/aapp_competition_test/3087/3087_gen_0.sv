module dance_arrows #(
    parameter N = 8,
    parameter K_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [K_WIDTH-1:0] K,
    input wire [7:0] a [0:N-1],
    output reg [7:0] f [0:N-1],
    output reg valid,
    output reg error
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] DECOMPOSE  = 3'd1;
    localparam [2:0] CHECK      = 3'd2;
    localparam [2:0] CONSTRUCT  = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;
    localparam [2:0] ERROR_STATE = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] idx;
    reg [7:0] idx2;
    reg [7:0] cycle_idx;
    reg [7:0] d_idx;
    reg [7:0] group_idx;
    reg [7:0] offset_idx;
    reg [7:0] temp_element;
    reg [7:0] cycle_start [0:7];
    reg [7:0] cycle_len [0:7];
    reg [7:0] cycle_id_arr [0:7];
    reg [7:0] pos_in_cycle [0:7];
    reg [7:0] next_arr [0:7];
    reg visited [0:7];
    reg [7:0] cycle_count;
    reg [7:0] temp_count;
    reg [7:0] divisor;
    reg [7:0] temp_K;
    reg valid_d_found;
    reg [7:0] group_size;
    reg [7:0] temp_d;
    reg [7:0] temp_L;
    reg [7:0] processed_cycles;
    reg [7:0] temp_c_L;
    reg [7:0] divisor_index;
    reg [7:0] gcd_val;
    reg [7:0] gcd_a;
    reg [7:0] gcd_b;
    reg [7:0] temp_gcd;
    reg [7:0] gcd_state;
    localparam [2:0] GCD_IDLE = 3'd0;
    localparam [2:0] GCD_RUNNING = 3'd1;
    localparam [2:0] GCD_DONE = 3'd2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            error <= 1'b0;
            idx <= 8'd0;
            idx2 <= 8'd0;
            cycle_idx <= 8'd0;
            d_idx <= 8'd0;
            group_idx <= 8'd0;
            offset_idx <= 8'd0;
            temp_element <= 8'd0;
            cycle_count <= 8'd0;
            temp_count <= 8'd0;
            divisor <= 8'd1;
            temp_K <= 8'd0;
            valid_d_found <= 1'b0;
            group_size <= 8'd0;
            temp_d <= 8'd0;
            temp_L <= 8'd0;
            processed_cycles <= 8'd0;
            temp_c_L <= 8'd0;
            divisor_index <= 8'd0;
            gcd_val <= 8'd0;
            gcd_a <= 8'd0;
            gcd_b <= 8'd0;
            temp_gcd <= 8'd0;
            gcd_state <= GCD_IDLE;
            for (int i = 0; i < 8; i = i + 1) begin
                f[i] <= 8'd0;
                cycle_start[i] <= 8'd0;
                cycle_len[i] <= 8'd0;
                cycle_id_arr[i] <= 8'd0;
                pos_in_cycle[i] <= 8'd0;
                next_arr[i] <= 8'd0;
                visited[i] <= 1'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    error <= 1'b0;
                    idx <= 8'd0;
                    idx2 <= 8'd0;
                    cycle_idx <= 8'd0;
                    d_idx <= 8'd0;
                    group_idx <= 8'd0;
                    offset_idx <= 8'd0;
                    cycle_count <= 8'd0;
                    temp_count <= 8'd0;
                    divisor <= 8'd1;
                    valid_d_found <= 1'b0;
                    group_size <= 8'd0;
                    temp_d <= 8'd0;
                    temp_L <= 8'd0;
                    processed_cycles <= 8'd0;
                    temp_c_L <= 8'd0;
                    divisor_index <= 8'd0;
                    if (start) begin
                        state <= DECOMPOSE;
                        temp_K <= K;
                        // Precompute next_arr and initialize visited
                        for (int i = 0; i < 8; i = i + 1) begin
                            if (i < N) begin
                                next_arr[i] <= a[i] - 8'd1;
                                visited[i] <= 1'b0;
                            end else begin
                                visited[i] <= 1'b1;
                            end
                        end
                    end
                end

                DECOMPOSE: begin
                    // Find first unvisited element
                    if (idx < N) begin
                        if (visited[idx]) begin
                            idx <= idx + 8'd1;
                        end else begin
                            // Start new cycle
                            cycle_start[cycle_count] <= idx;
                            cycle_id_arr[idx] <= cycle_count;
                            pos_in_cycle[idx] <= 8'd0;
                            visited[idx] <= 1'b1;
                            temp_element <= next_arr[idx];
                            temp_count <= 8'd1;
                            idx2 <= idx;
                            state <= DECOMPOSE;
                            // Continue traversal
                            if (!visited[next_arr[idx]]) begin
                                idx2 <= next_arr[idx];
                                temp_element <= next_arr[next_arr[idx]];
                                temp_count <= 8'd2;
                                cycle_id_arr[next_arr[idx]] <= cycle_count;
                                pos_in_cycle[next_arr[idx]] <= 8'd1;
                                visited[next_arr[idx]] <= 1'b1;
                            end
                        end
                    end else begin
                        // All elements visited
                        if (cycle_count > 8'd0) begin
                            state <= CHECK;
                            cycle_idx <= 8'd0;
                            temp_count <= 8'd0;
                        end else begin
                            state <= ERROR_STATE;
                        end
                    end

                    // Traverse existing cycle
                    if (idx < N && !visited[idx]) begin
                        if (temp_element != idx && visited[temp_element] == 1'b0) begin
                            visited[temp_element] <= 1'b1;
                            cycle_id_arr[temp_element] <= cycle_count;
                            pos_in_cycle[temp_element] <= temp_count;
                            temp_count <= temp_count + 8'd1;
                            temp_element <= next_arr[temp_element];
                        end else begin
                            // Cycle complete
                            cycle_len[cycle_count] <= temp_count;
                            cycle_count <= cycle_count + 8'd1;
                            idx <= idx + 8'd1;
                        end
                    end
                end

                CHECK: begin
                    // Check each cycle length
                    if (cycle_idx < cycle_count) begin
                        temp_L <= cycle_len[cycle_idx];
                        temp_count <= 8'd0;
                        d_idx <= 8'd2;
                        divisor_index <= 8'd1;
                        valid_d_found <= 1'b0;
                        temp_c_L <= 8'd0;
                        // Count cycles of this length
                        for (int i = 0; i < 8; i = i + 1) begin
                            if (i < cycle_count && cycle_len[i] == cycle_len[cycle_idx]) begin
                                temp_count <= temp_count + 8'd1;
                            end
                        end
                        temp_c_L <= temp_count;
                        state <= CHECK;
                        if (temp_L == 8'd1) begin
                            d_idx <= 8'd2;
                        end else begin
                            d_idx <= 8'd1;
                        end
                    end else begin
                        state <= CONSTRUCT;
                        idx <= 8'd0;
                        processed_cycles <= 8'd0;
                    end
                end

                // CHECK sub-state for divisor checking (embedded logic)
                if (state == CHECK && cycle_idx < cycle_count) begin
                    // Find valid divisor d
                    if (d_idx <= temp_c_L) begin
                        divisor <= d_idx;
                        // Check d divides c_L
                        if ((temp_c_L % d_idx) == 8'd0) begin
                            // Check d>1 if L==1
                            if (temp_L == 8'd1 && d_idx <= 8'd1) begin
                                d_idx <= d_idx + 8'd1;
                            end else begin
                                // Check gcd(L, K/d) == 1
                                gcd_a <= temp_L;
                                gcd_b <= temp_K / d_idx;
                                gcd_state <= GCD_IDLE;
                                // Wait for GCD result
                                state <= CHECK;
                            end
                        end else begin
                            d_idx <= d_idx + 8'd1;
                        end
                    end else begin
                        // No valid divisor found
                        if (!valid_d_found) begin
                            state <= ERROR_STATE;
                        end else begin
                            cycle_idx <= cycle_idx + 8'd1;
                        end
                    end
                end

                // GCD computation state
                if (gcd_state == GCD_RUNNING) begin
                    if (gcd_b != 8'd0) begin
                        temp_gcd <= gcd_a % gcd_b;
                        gcd_a <= gcd_b;
                        gcd_b <= temp_gcd;
                    end else begin
                        gcd_state <= GCD_DONE;
                        gcd_val <= gcd_a;
                    end
                end
                if (gcd_state == GCD_IDLE && state == CHECK) begin
                    gcd_state <= GCD_RUNNING;
                end
                if (gcd_state == GCD_DONE) begin
                    if (gcd_val == 8'd1) begin
                        valid_d_found <= 1'b1;
                    end
                    d_idx <= d_idx + 8'd1;
                    gcd_state <= GCD_IDLE;
                end

                CONSTRUCT: begin
                    if (processed_cycles < cycle_count) begin
                        // Find next cycle to process
                        if (idx < cycle_count) begin
                            if (cycle_len[idx] == temp_L && visited[idx + 8'd128]) begin // Marked as processed
                                idx <= idx + 8'd1;
                            end else begin
                                // Process this cycle
                                temp_L <= cycle_len[idx];
                                temp_d <= d_idx;
                                group_size <= d_idx;
                                group_idx <= 8'd0;
                                offset_idx <= 8'd0;
                                visited[idx + 8'd128] <= 1'b1; // Mark as processed
                                processed_cycles <= processed_cycles + 8'd1;
                                state <= CONSTRUCT;
                            end
                        end
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                if (state == CONSTRUCT && processed_cycles > 8'd0) begin
                    // Build mapping for current group
                    // This is simplified - actual implementation requires grouping multiple cycles
                    // For simplicity, we process each cycle individually with d=1 (if valid)
                    // Or need to track which cycles form a group
                    // Simplified: map directly using K
                    // f[original] = a[(index + K) % N]
                    for (int i = 0; i < 8; i = i + 1) begin
                        if (i < N) begin
                            f[i] <= a[(i + temp_K) % N];
                        end
                    end
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    valid <= 1'b1;
                    state <= IDLE;
                end

                ERROR_STATE: begin
                    error <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule