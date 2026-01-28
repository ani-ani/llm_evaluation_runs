module HamiltonianCycleChecker(
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
    localparam [3:0] FORWARD_DP = 4'd2;
    localparam [3:0] STORE_COMPLEMENT = 4'd3;
    localparam [3:0] BACKWARD_DP = 4'd4;
    localparam [3:0] CHECK_MATCH = 4'd5;
    localparam [3:0] FINISH = 4'd6;

    // Internal registers
    reg [3:0] state;
    reg [15:0] cycle_count;
    reg [7:0] i, j, k, mask_idx;
    reg [7:0] mask, prev_mask;
    reg [15:0] current_cost, new_cost, temp_cost;
    reg [15:0] cost_forward [0:7][0:255];
    reg [15:0] cost_complement [0:255];
    reg [7:0] complement_mask;
    reg [15:0] target_cost;
    reg match_found;

    // Distance matrix unpacking
    wire [15:0] d [0:7][0:7];
    genvar i_gen, j_gen;
    generate
        for (i_gen = 0; i_gen < 8; i_gen = i_gen + 1) begin : gen_i
            for (j_gen = 0; j_gen < 8; j_gen = j_gen + 1) begin : gen_j
                assign d[i_gen][j_gen] = d_flat[(i_gen * 8 + j_gen) * 16 +: 16];
            end
        end
    endgenerate

    // FSM logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 16'd0;
            
            // Initialize all registers
            i <= 8'd0;
            j <= 8'd0;
            k <= 8'd0;
            mask_idx <= 8'd0;
            mask <= 8'd0;
            prev_mask <= 8'd0;
            current_cost <= 16'd0;
            new_cost <= 16'd0;
            temp_cost <= 16'd0;
            complement_mask <= 8'd0;
            target_cost <= 16'd0;
            match_found <= 1'b0;
            
            // Initialize cost arrays
            for (i = 0; i < 8; i = i + 1) begin
                for (mask_idx = 0; mask_idx < 256; mask_idx = mask_idx + 1) begin
                    cost_forward[i][mask_idx] <= 16'd65535;
                end
            end
            
            for (mask_idx = 0; mask_idx < 256; mask_idx = mask_idx + 1) begin
                cost_complement[mask_idx] <= 16'd65535;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                        cycle_count <= 16'd0;
                    end
                end

                INIT: begin
                    // Initialize base cases for forward DP
                    for (i = 0; i < 8; i = i + 1) begin
                        cost_forward[i][1 << i] <= 16'd0;
                    end
                    state <= FORWARD_DP;
                end

                FORWARD_DP: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    // Iterate through all masks
                    if (mask_idx == 8'd0) begin
                        mask <= 8'd1;
                    end else if (mask_idx < (1 << n) - 1) begin
                        mask <= mask + 8'd1;
                    end
                    
                    // For each mask, process all endpoints
                    if (mask_idx < (1 << n) - 1) begin
                        j <= 8'd0;
                        if (j < n && (mask & (1 << j))) begin
                            // Find minimum cost to reach j with this mask
                            current_cost <= cost_forward[j][mask];
                            k <= 8'd0;
                            if (k < n && k != j && (mask & (1 << k))) begin
                                prev_mask <= mask ^ (1 << j);
                                temp_cost <= cost_forward[k][prev_mask] + d[k][j];
                                
                                if (temp_cost < current_cost) begin
                                    cost_forward[j][mask] <= temp_cost;
                                end
                                
                                k <= k + 8'd1;
                            end else begin
                                j <= j + 8'd1;
                            end
                        end else begin
                            mask_idx <= mask_idx + 8'd1;
                        end
                    end else begin
                        state <= STORE_COMPLEMENT;
                        mask_idx <= 8'd0;
                    end
                    
                    // Safety check for cycle limit
                    if (cycle_count >= 16'd5000) begin
                        state <= FINISH;
                    end
                end

                STORE_COMPLEMENT: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    // Store costs for masks with bit n/2 set
                    if (mask_idx < (1 << n)) begin
                        if (mask_idx & (1 << (n >> 1))) begin
                            cost_complement[mask_idx] <= cost_forward[0][mask_idx];
                        end
                        mask_idx <= mask_idx + 8'd1;
                    end else begin
                        state <= BACKWARD_DP;
                        mask_idx <= 8'd0;
                        match_found <= 1'b0;
                    end
                    
                    if (cycle_count >= 16'd5000) begin
                        state <= FINISH;
                    end
                end

                BACKWARD_DP: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    // Check complement masks
                    if (mask_idx < (1 << n)) begin
                        complement_mask <= ((1 << n) - 1) ^ mask_idx;
                        
                        // Check if complement mask has the required bit set
                        if (complement_mask & (1 << (n >> 1))) begin
                            target_cost <= L - d[j][0];
                            
                            // Check all possible endpoints
                            j <= 8'd0;
                            if (j < n && (mask_idx & (1 << j))) begin
                                if (cost_forward[j][mask_idx] + cost_complement[complement_mask] == target_cost) begin
                                    match_found <= 1'b1;
                                end
                                j <= j + 8'd1;
                            end else begin
                                mask_idx <= mask_idx + 8'd1;
                            end
                        end else begin
                            mask_idx <= mask_idx + 8'd1;
                        end
                    end else begin
                        state <= CHECK_MATCH;
                    end
                    
                    if (cycle_count >= 16'd5000) begin
                        state <= FINISH;
                    end
                end

                CHECK_MATCH: begin
                    result <= match_found;
                    state <= FINISH;
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