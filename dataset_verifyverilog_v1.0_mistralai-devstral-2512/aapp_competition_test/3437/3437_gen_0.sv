module vacuum_tube_maximizer(
    input clk,
    input rst_n,
    input start,
    input [15:0] L1,
    input [15:0] L2,
    input [10:0] N,
    input [15:0] tube_len,
    input tube_wr_en,
    output reg [15:0] result,
    output reg done,
    output reg impossible
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] INPUT = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] OUTPUT = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [10:0] tube_count;
    reg [15:0] tube_ram [0:1999];
    reg [15:0] max_total;
    reg [15:0] best_L1_sum, best_L2_sum;
    reg [15:0] current_L1_sum, current_L2_sum;
    reg [10:0] i_reg, j_reg, k_reg, l_reg;
    reg [10:0] best_i, best_j, best_k, best_l;
    reg found_valid;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd5000;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            tube_count <= 11'd0;
            max_total <= 16'd0;
            best_L1_sum <= 16'd0;
            best_L2_sum <= 16'd0;
            current_L1_sum <= 16'd0;
            current_L2_sum <= 16'd0;
            i_reg <= 11'd0;
            j_reg <= 11'd0;
            k_reg <= 11'd0;
            l_reg <= 11'd0;
            best_i <= 11'd0;
            best_j <= 11'd0;
            best_k <= 11'd0;
            best_l <= 11'd0;
            found_valid <= 1'b0;
            cycle_count <= 16'd0;
            done <= 1'b0;
            impossible <= 1'b0;
            result <= 16'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    impossible <= 1'b0;
                    if (start) begin
                        tube_count <= 11'd0;
                        next_state <= INPUT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INPUT: begin
                    if (tube_wr_en) begin
                        tube_ram[tube_count] <= tube_len;
                        tube_count <= tube_count + 11'd1;
                        if (tube_count == N) begin
                            next_state <= COMPUTE;
                            i_reg <= 11'd0;
                            j_reg <= 11'd1;
                            k_reg <= 11'd2;
                            l_reg <= 11'd3;
                            max_total <= 16'd0;
                            best_L1_sum <= 16'd0;
                            best_L2_sum <= 16'd0;
                            found_valid <= 1'b0;
                            cycle_count <= 16'd0;
                        end
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    // Check if we've exceeded max cycles
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= OUTPUT;
                    end else begin
                        // Calculate current pair sums
                        current_L1_sum <= tube_ram[i_reg] + tube_ram[j_reg];
                        current_L2_sum <= tube_ram[k_reg] + tube_ram[l_reg];
                        
                        // Check if pairs are valid and disjoint
                        if ((current_L1_sum <= L1) && (current_L2_sum <= L2) &&
                            (i_reg != k_reg) && (i_reg != l_reg) &&
                            (j_reg != k_reg) && (j_reg != l_reg)) begin
                            
                            // Update best solution if this is better
                            if ((current_L1_sum + current_L2_sum) > max_total) begin
                                max_total <= current_L1_sum + current_L2_sum;
                                best_L1_sum <= current_L1_sum;
                                best_L2_sum <= current_L2_sum;
                                best_i <= i_reg;
                                best_j <= j_reg;
                                best_k <= k_reg;
                                best_l <= l_reg;
                                found_valid <= 1'b1;
                            end
                        end
                        
                        // Update indices for next iteration
                        l_reg <= l_reg + 11'd1;
                        if (l_reg >= N) begin
                            l_reg <= k_reg + 11'd1;
                            k_reg <= k_reg + 11'd1;
                            if (k_reg >= N - 11'd1) begin
                                k_reg <= j_reg + 11'd1;
                                l_reg <= k_reg + 11'd1;
                                j_reg <= j_reg + 11'd1;
                                if (j_reg >= N - 11'd1) begin
                                    j_reg <= i_reg + 11'd1;
                                    i_reg <= i_reg + 11'd1;
                                    if (i_reg >= N - 11'd2) begin
                                        next_state <= OUTPUT;
                                    end
                                end
                            end
                        end
                    end
                end

                OUTPUT: begin
                    if (found_valid) begin
                        result <= max_total;
                        impossible <= 1'b0;
                    end else begin
                        impossible <= 1'b1;
                    end
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule