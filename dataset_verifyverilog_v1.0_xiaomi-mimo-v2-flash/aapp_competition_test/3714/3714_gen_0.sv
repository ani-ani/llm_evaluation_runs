module crush_distance(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] crush [0:99],
    input wire [6:0] n,
    output reg [31:0] result,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] VALIDATE    = 3'd1;
    localparam [2:0] FIND_CYCLES = 3'd2;
    localparam [2:0] COMPUTE_LCM = 3'd3;
    localparam [2:0] FINISH      = 3'd4;

    reg [2:0] state, next_state;
    
    // Registers for cycle detection
    reg visited [0:99];
    reg [7:0] visited_idx;
    reg [7:0] current_node;
    reg [7:0] cycle_len;
    reg [15:0] cycle_count;
    reg [7:0] temp_cycle_len;
    
    // LCM computation registers
    reg [31:0] current_lcm;
    reg [31:0] next_val;
    reg [15:0] lcm_idx;
    reg [31:0] temp_lcm;
    reg [31:0] gcd_a;
    reg [31:0] gcd_b;
    reg [31:0] gcd_temp;
    
    // Control registers
    reg [15:0] timeout_counter;
    reg validation_failed;
    reg [7:0] node_idx;
    reg [7:0] cycle_start;
    reg search_active;
    
    // GCD computation state
    localparam [1:0] GCD_IDLE    = 2'd0;
    localparam [1:0] GCD_COMPUTE = 2'd1;
    localparam [1:0] GCD_DONE    = 2'd2;
    reg [1:0] gcd_state;
    reg [31:0] gcd_result;
    
    integer i;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            result <= 32'd0;
            timeout_counter <= 16'd0;
            validation_failed <= 1'b0;
            current_lcm <= 32'd0;
            next_val <= 32'd0;
            lcm_idx <= 16'd0;
            temp_lcm <= 32'd0;
            gcd_a <= 32'd0;
            gcd_b <= 32'd0;
            gcd_temp <= 32'd0;
            gcd_state <= GCD_IDLE;
            gcd_result <= 32'd0;
            visited_idx <= 8'd0;
            current_node <= 8'd0;
            cycle_len <= 8'd0;
            cycle_count <= 16'd0;
            temp_cycle_len <= 8'd0;
            node_idx <= 8'd0;
            cycle_start <= 8'd0;
            search_active <= 1'b0;
            for (i = 0; i < 100; i = i + 1) begin
                visited[i] <= 1'b0;
            end
        end else begin
            state <= next_state;
            
            // Clear done at start of new operation
            if (start && state == IDLE) begin
                done <= 1'b0;
                valid <= 1'b0;
                result <= 32'd0;
                timeout_counter <= 16'd0;
                validation_failed <= 1'b0;
                current_lcm <= 32'd0;
                lcm_idx <= 16'd0;
                visited_idx <= 8'd0;
                current_node <= 8'd0;
                cycle_len <= 8'd0;
                cycle_count <= 16'd0;
                node_idx <= 8'd0;
                cycle_start <= 8'd0;
                search_active <= 1'b0;
                gcd_state <= GCD_IDLE;
                for (i = 0; i < 100; i = i + 1) begin
                    visited[i] <= 1'b0;
                end
            end
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize
                    end
                end
                
                VALIDATE: begin
                    // Check if all numbers 1..n appear exactly once
                    // Use brute force: for each i, count occurrences
                    if (visited_idx < n) begin
                        reg [7:0] count;
                        reg [7:0] j;
                        count = 8'd0;
                        for (j = 8'd0; j < n; j = j + 1) begin
                            if (crush[j] == visited_idx + 8'd1) begin
                                count = count + 8'd1;
                            end
                        end
                        if (count != 8'd1) begin
                            validation_failed <= 1'b1;
                        end
                        visited_idx <= visited_idx + 8'd1;
                    end
                end
                
                FIND_CYCLES: begin
                    if (search_active) begin
                        // Continue DFS from current_node
                        reg [7:0] next_node;
                        next_node = crush[current_node - 8'd1];
                        
                        if (next_node == cycle_start) begin
                            // Found cycle back to start
                            search_active <= 1'b0;
                            cycle_count <= cycle_count + 16'd1;
                            
                            // Process cycle length
                            if (cycle_len[0]) begin
                                // Odd cycle
                                temp_cycle_len <= cycle_len;
                            end else begin
                                // Even cycle
                                temp_cycle_len <= cycle_len >> 1;
                            end
                        end else if (!visited[next_node - 8'd1]) begin
                            visited[next_node - 8'd1] <= 1'b1;
                            current_node <= next_node;
                            cycle_len <= cycle_len + 8'd1;
                            timeout_counter <= timeout_counter + 16'd1;
                        end else begin
                            // Invalid cycle or collision
                            search_active <= 1'b0;
                            validation_failed <= 1'b1;
                        end
                    end else begin
                        // Find new cycle start
                        if (node_idx < n) begin
                            node_idx <= node_idx + 8'd1;
                            if (!visited[node_idx]) begin
                                // Start new cycle
                                search_active <= 1'b1;
                                cycle_start <= node_idx + 8'd1;
                                current_node <= node_idx + 8'd1;
                                visited[node_idx] <= 1'b1;
                                cycle_len <= 8'd1;
                            end
                        end
                    end
                    
                    // Store cycle length for LCM
                    if (cycle_count > 16'd0 && cycle_count > lcm_idx) begin
                        // This is handled in COMPUTE_LCM state
                    end
                end
                
                COMPUTE_LCM: begin
                    if (lcm_idx == 16'd0) begin
                        // First cycle length
                        current_lcm <= {24'd0, temp_cycle_len};
                        lcm_idx <= 16'd1;
                    end else if (lcm_idx <= cycle_count) begin
                        // GCD computation
                        case (gcd_state)
                            GCD_IDLE: begin
                                gcd_a <= current_lcm;
                                gcd_b <= {24'd0, temp_cycle_len};
                                gcd_state <= GCD_COMPUTE;
                            end
                            GCD_COMPUTE: begin
                                if (gcd_b != 32'd0) begin
                                    gcd_temp <= gcd_b;
                                    gcd_b <= gcd_a % gcd_b;
                                    gcd_a <= gcd_temp;
                                end else begin
                                    gcd_state <= GCD_DONE;
                                end
                            end
                            GCD_DONE: begin
                                // LCM = (a * b) / GCD
                                temp_lcm <= (current_lcm * temp_cycle_len) / gcd_a;
                                gcd_state <= GCD_IDLE;
                                lcm_idx <= lcm_idx + 16'd1;
                            end
                        endcase
                    end else begin
                        // Done
                        result <= current_lcm;
                    end
                end
                
                FINISH: begin
                    if (validation_failed) begin
                        valid <= 1'b0;
                        result <= 32'd0;
                    end else if (cycle_count == 16'd0) begin
                        // No cycles found - invalid
                        valid <= 1'b0;
                        result <= 32'd0;
                    end else begin
                        valid <= 1'b1;
                    end
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = VALIDATE;
                end
            end
            
            VALIDATE: begin
                if (visited_idx >= n) begin
                    if (validation_failed) begin
                        next_state = FINISH;
                    end else begin
                        next_state = FIND_CYCLES;
                    end
                end
            end
            
            FIND_CYCLES: begin
                if (validation_failed) begin
                    next_state = FINISH;
                end else if (node_idx >= n && !search_active) begin
                    // All nodes processed
                    if (cycle_count == 16'd0) begin
                        next_state = FINISH;
                    end else begin
                        next_state = COMPUTE_LCM;
                    end
                end else if (timeout_counter >= 16'd1000) begin
                    // Timeout - invalid
                    next_state = FINISH;
                end
            end
            
            COMPUTE_LCM: begin
                // Wait for all cycles to be processed
                if (lcm_idx > cycle_count) begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                if (start) begin
                    next_state = IDLE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule