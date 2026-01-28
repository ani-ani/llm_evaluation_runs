module HamiltonianCycleDP (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] n,
    input wire [15:0] L,
    input wire [511:0] d_flat,
    output reg result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT = 4'd1;
    localparam [3:0] FORWARD_COMPUTE = 4'd2;
    localparam [3:0] FORWARD_NEXT = 4'd3;
    localparam [3:0] BACKWARD_COMPUTE = 4'd4;
    localparam [3:0] BACKWARD_NEXT = 4'd5;
    localparam [3:0] CHECK_MATCH = 4'd6;
    localparam [3:0] FINISH = 4'd7;

    reg [3:0] state;
    reg [3:0] next_state;

    // Control registers
    reg [7:0] mask;           // 8-bit mask for n≤8
    reg [7:0] next_mask;
    reg [2:0] j;              // Current endpoint
    reg [2:0] k;              // Previous endpoint
    reg [2:0] next_j;
    reg [2:0] next_k;
    reg [2:0] half_n;
    reg [2:0] half_n_plus_1;

    // Storage: cost_forward[endpoint][mask] (8 x 256 x 16-bit)
    reg [15:0] cost_forward [0:7][0:255];
    reg [15:0] cost_complement [0:255];
    reg [15:0] best_complement;
    
    // Match tracking
    reg match_found;
    reg [15:0] current_cost;
    reg [15:0] prev_cost;
    reg [15:0] d_kj;
    reg [15:0] d_j0;
    reg [15:0] d_0j;
    
    // Timing control
    reg [12:0] cycle_count;
    localparam [12:0] MAX_CYCLES = 13'd5000;
    
    // Distance extraction helper
    wire [15:0] dist_ij;
    // Index = i*8 + j
    assign dist_ij = d_flat[(j*8+k)*16 +: 16];  // d[k][j]
    wire [15:0] dist_j0;
    assign dist_j0 = d_flat[(j*8+0)*16 +: 16];  // d[j][0]
    wire [15:0] dist_0j;
    assign dist_0j = d_flat[(0*8+j)*16 +: 16];  // d[0][j]

    // Complement extraction
    reg [7:0] complement_mask;
    always @(*) begin
        // Find mask complement within n bits
        complement_mask = ~mask;
        // Clear bits beyond n
        case (n)
            3'd2: complement_mask[7:2] = 6'd0;
            3'd3: complement_mask[7:3] = 5'd0;
            3'd4: complement_mask[7:4] = 4'd0;
            3'd5: complement_mask[7:5] = 3'd0;
            3'd6: complement_mask[7:6] = 2'd0;
            3'd7: complement_mask[7:7] = 1'd0;
            default: complement_mask = ~mask;
        endcase
    end

    // Cycle counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 13'd0;
        end else if (state == IDLE) begin
            cycle_count <= 13'd0;
        end else if (state != IDLE && state != FINISH) begin
            cycle_count <= cycle_count + 13'd1;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        next_mask = mask;
        next_j = j;
        next_k = k;
        
        case (state)
            IDLE: begin
                if (start) begin
                    if (n <= 3'd2) begin
                        next_state = FINISH;
                    end else begin
                        next_state = INIT;
                    end
                end
            end
            
            INIT: begin
                next_mask = 8'd1;  // Start with mask having only bit 0
                next_j = 3'd1;     // Start from endpoint 1
                next_k = 3'd0;     // Start checking previous 0
                next_state = FORWARD_COMPUTE;
            end
            
            FORWARD_COMPUTE: begin
                // Wait for computation
                next_state = FORWARD_NEXT;
            end
            
            FORWARD_NEXT: begin
                // Update k
                if (next_k < n - 3'd1) begin
                    next_k = next_k + 3'd1;
                    next_state = FORWARD_COMPUTE;
                end else begin
                    // Move to next j
                    next_k = 3'd0;
                    if (next_j < n - 3'd1) begin
                        next_j = next_j + 3'd1;
                        next_state = FORWARD_COMPUTE;
                    end else begin
                        // Check if all masks done
                        if (mask < ((1 << (n - 3'd1)) - 8'd1)) begin
                            next_mask = mask + 8'd1;
                            next_j = 3'd1;
                            next_k = 3'd0;
                            next_state = FORWARD_COMPUTE;
                        end else begin
                            // Done with forward DP
                            next_state = BACKWARD_INIT;
                        end
                    end
                end
            end
            
            BACKWARD_INIT: begin
                next_mask = 8'd1;
                next_j = 3'd1;
                next_state = BACKWARD_COMPUTE;
            end
            
            BACKWARD_COMPUTE: begin
                next_state = BACKWARD_NEXT;
            end
            
            BACKWARD_NEXT: begin
                if (next_j < n - 3'd1) begin
                    next_j = next_j + 3'd1;
                    next_state = BACKWARD_COMPUTE;
                end else begin
                    next_j = 3'd1;
                    if (mask < ((1 << (n - 3'd1)) - 8'd1)) begin
                        next_mask = mask + 8'd1;
                        next_state = BACKWARD_COMPUTE;
                    end else begin
                        next_state = CHECK_MATCH;
                    end
                end
            end
            
            CHECK_MATCH: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            match_found <= 1'b0;
            // Initialize all cost arrays
            begin : reset_arrays
                integer i, m;
                for (i = 0; i < 8; i = i + 1) begin
                    for (m = 0; m < 256; m = m + 1) begin
                        cost_forward[i][m] <= 16'hFFFF;  // Initialize to max
                    end
                end
                for (m = 0; m < 256; m = m + 1) begin
                    cost_complement[m] <= 16'hFFFF;
                end
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    match_found <= 1'b0;
                    if (start && n <= 3'd2) begin
                        // Edge case: n=2
                        // Check if d[0][1] + d[1][0] == L
                        if (d_flat[(0*8+1)*16 +: 16] + d_flat[(1*8+0)*16 +: 16] == L) begin
                            result <= 1'b1;
                        end
                        done <= 1'b1;
                    end
                end
                
                INIT: begin
                    // Initialize base case: cost[0][1<<0] = 0
                    cost_forward[0][8'd1] <= 16'd0;
                end
                
                FORWARD_COMPUTE: begin
                    // DP Forward: cost[j][mask] = min(cost[k][mask^(1<<j)] + d[k][j])
                    d_kj <= dist_ij;
                    prev_cost <= cost_forward[k][mask ^ (8'd1 << j)];
                    
                    if (k != j && (mask & (8'd1 << k)) != 8'd0) begin
                        current_cost <= cost_forward[k][mask ^ (8'd1 << j)] + dist_ij;
                    end else begin
                        current_cost <= 16'hFFFF;
                    end
                end
                
                FORWARD_NEXT: begin
                    // Store minimum cost
                    if (k != j && (mask & (8'd1 << k)) != 8'd0) begin
                        if (current_cost < cost_forward[j][mask]) begin
                            cost_forward[j][mask] <= current_cost;
                        end
                    end
                    
                    // Store half results (mask with n/2 bits set)
                    // Store when mask has exactly n/2 bits
                    if (popcount(mask) == half_n) begin
                        cost_complement[mask] <= cost_forward[j][mask];
                    end
                end
                
                BACKWARD_COMPUTE: begin
                    // Backward DP: Check if cost_forward[j][mask] + cost_forward[0][complement] + d[j][0] == L
                    d_j0 <= dist_j0;
                    if (popcount(complement_mask) == half_n) begin
                        // Check match
                        if (cost_forward[j][mask] != 16'hFFFF && 
                            cost_complement[complement_mask] != 16'hFFFF) begin
                            if (cost_forward[j][mask] + cost_complement[complement_mask] + dist_j0 == L) begin
                                match_found <= 1'b1;
                            end
                        end
                    end
                end
                
                CHECK_MATCH: begin
                    if (match_found) begin
                        result <= 1'b1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    // Reset for next operation
                    match_found <= 1'b0;
                end
            endcase
        end
    end

    // Helper function for popcount (number of set bits)
    function automatic [2:0] popcount;
        input [7:0] val;
        reg [2:0] count;
        begin
            count = 3'd0;
            if (val[0]) count = count + 3'd1;
            if (val[1]) count = count + 3'd1;
            if (val[2]) count = count + 3'd1;
            if (val[3]) count = count + 3'd1;
            if (val[4]) count = count + 3'd1;
            if (val[5]) count = count + 3'd1;
            if (val[6]) count = count + 3'd1;
            if (val[7]) count = count + 3'd1;
            popcount = count;
        end
    endfunction

    // Calculate half_n on start
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            half_n <= 3'd0;
            half_n_plus_1 <= 3'd0;
        end else if (start) begin
            half_n <= n >> 1;  // n/2
            half_n_plus_1 <= (n >> 1) + 3'd1;
        end
    end

endmodule