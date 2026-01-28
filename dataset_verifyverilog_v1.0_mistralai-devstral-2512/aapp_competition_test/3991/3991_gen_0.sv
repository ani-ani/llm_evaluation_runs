module sum_max_distances(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] coords [0:19],
    input wire [4:0] n,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [4:0] MAX_N = 5'd20;

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SORT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    // Internal registers
    reg [2:0] state;
    reg [7:0] cycle_count;
    reg [31:0] sorted_coords [0:19];
    reg [31:0] pow2 [0:18];
    reg [31:0] accum;
    reg [4:0] i_reg;
    reg [4:0] j_reg;
    reg [31:0] diff;
    reg [31:0] term1;
    reg [31:0] term2;
    reg [31:0] contribution;

    // Sort network for 20 elements
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i_reg <= 5'd0;
            j_reg <= 5'd0;
            accum <= 32'd0;
            diff <= 32'd0;
            term1 <= 32'd0;
            term2 <= 32'd0;
            contribution <= 32'd0;
            for (integer k = 0; k < 20; k = k + 1) begin
                sorted_coords[k] <= 32'd0;
            end
            for (integer k = 0; k < 19; k = k + 1) begin
                pow2[k] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= SORT;
                        // Initialize sorted_coords
                        for (integer k = 0; k < 20; k = k + 1) begin
                            sorted_coords[k] <= coords[k];
                        end
                    end
                end

                SORT: begin
                    // Sort network implementation
                    // Stage 1
                    if (cycle_count == 8'd0) begin
                        for (integer k = 0; k < 19; k = k + 2) begin
                            if (sorted_coords[k] > sorted_coords[k+1]) begin
                                sorted_coords[k] <= sorted_coords[k+1];
                                sorted_coords[k+1] <= sorted_coords[k];
                            end
                        end
                    end
                    // Stage 2
                    else if (cycle_count == 8'd1) begin
                        for (integer k = 0; k < 18; k = k + 2) begin
                            if (sorted_coords[k] > sorted_coords[k+1]) begin
                                sorted_coords[k] <= sorted_coords[k+1];
                                sorted_coords[k+1] <= sorted_coords[k];
                            end
                        end
                    end
                    // Stage 3
                    else if (cycle_count == 8'd2) begin
                        for (integer k = 0; k < 17; k = k + 2) begin
                            if (sorted_coords[k] > sorted_coords[k+1]) begin
                                sorted_coords[k] <= sorted_coords[k+1];
                                sorted_coords[k+1] <= sorted_coords[k];
                            end
                        end
                    end
                    // Stage 4
                    else if (cycle_count == 8'd3) begin
                        for (integer k = 0; k < 16; k = k + 2) begin
                            if (sorted_coords[k] > sorted_coords[k+1]) begin
                                sorted_coords[k] <= sorted_coords[k+1];
                                sorted_coords[k+1] <= sorted_coords[k];
                            end
                        end
                    end
                    // Stage 5
                    else if (cycle_count == 8'd4) begin
                        for (integer k = 0; k < 15; k = k + 2) begin
                            if (sorted_coords[k] > sorted_coords[k+1]) begin
                                sorted_coords[k] <= sorted_coords[k+1];
                                sorted_coords[k+1] <= sorted_coords[k];
                            end
                        end
                    end
                    // Stage 6
                    else if (cycle_count == 8'd5) begin
                        for (integer k = 0; k < 14; k = k + 2) begin
                            if (sorted_coords[k] > sorted_coords[k+1]) begin
                                sorted_coords[k] <= sorted_coords[k+1];
                                sorted_coords[k+1] <= sorted_coords[k];
                            end
                        end
                    end
                    // Stage 7
                    else if (cycle_count == 8'd6) begin
                        for (integer k = 0; k < 13; k = k + 2) begin
                            if (sorted_coords[k] > sorted_coords[k+1]) begin
                                sorted_coords[k] <= sorted_coords[k+1];
                                sorted_coords[k+1] <= sorted_coords[k];
                            end
                        end
                    end
                    // Stage 8
                    else if (cycle_count == 8'd7) begin
                        for (integer k = 0; k < 12; k = k + 2) begin
                            if (sorted_coords[k] > sorted_coords[k+1]) begin
                                sorted_coords[k] <= sorted_coords[k+1];
                                sorted_coords[k+1] <= sorted_coords[k];
                            end
                        end
                    end
                    // Stage 9
                    else if (cycle_count == 8'd8) begin
                        for (integer k = 0; k < 11; k = k + 2) begin
                            if (sorted_coords[k] > sorted_coords[k+1]) begin
                                sorted_coords[k] <= sorted_coords[k+1];
                                sorted_coords[k+1] <= sorted_coords[k];
                            end
                        end
                    end
                    // Stage 10
                    else if (cycle_count == 8'd9) begin
                        for (integer k = 0; k < 10; k = k + 2) begin
                            if (sorted_coords[k] > sorted_coords[k+1]) begin
                                sorted_coords[k] <= sorted_coords[k+1];
                                sorted_coords[k+1] <= sorted_coords[k];
                            end
                        end
                    end
                    // Stage 11
                    else if (cycle_count == 8'd10) begin
                        for (integer k = 0; k < 9; k = k + 2) begin
                            if (sorted_coords[k] > sorted_coords[k+1]) begin
                                sorted_coords[k] <= sorted_coords[k+1];
                                sorted_coords[k+1] <= sorted_coords[k];
                            end
                        end
                    end
                    // Stage 12
                    else if (cycle_count == 8'd11) begin
                        for (integer k = 0; k < 8; k = k + 2) begin
                            if (sorted_coords[k] > sorted_coords[k+1]) begin
                                sorted_coords[k] <= sorted_coords[k+1];
                                sorted_coords[k+1] <= sorted_coords[k];
                            end
                        end
                    end
                    // Stage 13
                    else if (cycle_count == 8'd12) begin
                        for (integer k = 0; k < 7; k = k + 2) begin
                            if (sorted_coords[k] > sorted_coords[k+1]) begin
                                sorted_coords[k] <= sorted_coords[k+1];
                                sorted_coords[k+1] <= sorted_coords[k];
                            end
                        end
                    end
                    // Stage 14
                    else if (cycle_count == 8'd13) begin
                        for (integer k = 0; k < 6; k = k + 2) begin
                            if (sorted_coords[k] > sorted_coords[k+1]) begin
                                sorted_coords[k] <= sorted_coords[k+1];
                                sorted_coords[k+1] <= sorted_coords[k];
                            end
                        end
                    end
                    // Stage 15
                    else if (cycle_count == 8'd14) begin
                        for (integer k = 0; k < 5; k = k + 2) begin
                            if (sorted_coords[k] > sorted_coords[k+1]) begin
                                sorted_coords[k] <= sorted_coords[k+1];
                                sorted_coords[k+1] <= sorted_coords[k];
                            end
                        end
                    end
                    // Stage 16
                    else if (cycle_count == 8'd15) begin
                        for (integer k = 0; k < 4; k = k + 2) begin
                            if (sorted_coords[k] > sorted_coords[k+1]) begin
                                sorted_coords[k] <= sorted_coords[k+1];
                                sorted_coords[k+1] <= sorted_coords[k];
                            end
                        end
                    end
                    // Stage 17
                    else if (cycle_count == 8'd16) begin
                        for (integer k = 0; k < 3; k = k + 2) begin
                            if (sorted_coords[k] > sorted_coords[k+1]) begin
                                sorted_coords[k] <= sorted_coords[k+1];
                                sorted_coords[k+1] <= sorted_coords[k];
                            end
                        end
                    end
                    // Stage 18
                    else if (cycle_count == 8'd17) begin
                        for (integer k = 0; k < 2; k = k + 2) begin
                            if (sorted_coords[k] > sorted_coords[k+1]) begin
                                sorted_coords[k] <= sorted_coords[k+1];
                                sorted_coords[k+1] <= sorted_coords[k];
                            end
                        end
                    end
                    // Stage 19
                    else if (cycle_count == 8'd18) begin
                        if (sorted_coords[0] > sorted_coords[1]) begin
                            sorted_coords[0] <= sorted_coords[1];
                            sorted_coords[1] <= sorted_coords[0];
                        end
                    end
                    // Final stage
                    else if (cycle_count == 8'd19) begin
                        // Compute powers of 2
                        pow2[0] <= 32'd1;
                        for (integer k = 1; k < 19; k = k + 1) begin
                            pow2[k] <= (pow2[k-1] * 32'd2) % MOD;
                        end
                        state <= COMPUTE;
                        i_reg <= 5'd0;
                        accum <= 32'd0;
                    end
                    cycle_count <= cycle_count + 8'd1;
                end

                COMPUTE: begin
                    if (n == 5'd1) begin
                        result <= 32'd0;
                        state <= DONE_STATE;
                    end else begin
                        if (i_reg < n - 5'd2) begin
                            // Compute diff
                            diff <= (sorted_coords[i_reg + 5'd1] - sorted_coords[i_reg]) % MOD;
                            
                            // Compute term1 = (2^i - 1)
                            term1 <= (pow2[i_reg] - 32'd1) % MOD;
                            
                            // Compute term2 = (2^(n-2-i) - 1)
                            term2 <= (pow2[n - 5'd2 - i_reg] - 32'd1) % MOD;
                            
                            // Compute contribution
                            contribution <= (diff * term1) % MOD;
                            contribution <= (contribution * term2) % MOD;
                            
                            // Accumulate
                            accum <= (accum + contribution) % MOD;
                            
                            i_reg <= i_reg + 5'd1;
                        end else begin
                            result <= accum;
                            state <= DONE_STATE;
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule