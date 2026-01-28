module shortest_article(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] num_proofs [0:7],
    input [7:0] proof_len [0:7][0:3],
    input [7:0] proof_dep [0:7][0:3],
    output reg done,
    output reg [15:0] result
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT_DP = 4'd1;
    localparam [3:0] LOOP_MASK = 4'd2;
    localparam [3:0] LOOP_THEOREM = 4'd3;
    localparam [3:0] LOOP_PROOF = 4'd4;
    localparam [3:0] UPDATE_DP = 4'd5;
    localparam [3:0] NEXT_MASK = 4'd6;
    localparam [3:0] NEXT_THEOREM = 4'd7;
    localparam [3:0] NEXT_PROOF = 4'd8;
    localparam [3:0] DONE_STATE = 4'd9;

    // DP array (256 entries, 16-bit each)
    reg [15:0] dp [0:255];

    // State and control registers
    reg [3:0] state;
    reg [7:0] mask;
    reg [2:0] theorem_idx;
    reg [1:0] proof_idx;
    reg [15:0] current_dp;
    reg [15:0] min_cost;
    reg [15:0] new_dp;
    reg [7:0] dep_mask;
    reg dep_ok;
    reg [15:0] temp_cost;
    reg [7:0] i;

    // Initialize DP array
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            mask <= 8'd0;
            theorem_idx <= 3'd0;
            proof_idx <= 2'd0;
            current_dp <= 16'd0;
            min_cost <= 16'd0;
            new_dp <= 16'd0;
            dep_mask <= 8'd0;
            dep_ok <= 1'b0;
            temp_cost <= 16'd0;
            done <= 1'b0;
            result <= 16'd0;
            for (i = 0; i < 256; i = i + 1) begin
                dp[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT_DP;
                    end
                end

                INIT_DP: begin
                    // Initialize dp[0] = 0, others = INF
                    dp[0] <= 16'd0;
                    for (i = 1; i < 256; i = i + 1) begin
                        dp[i] <= 16'd65535;
                    end
                    mask <= 8'd0;
                    state <= LOOP_MASK;
                end

                LOOP_MASK: begin
                    if (mask < (1 << n)) begin
                        current_dp <= dp[mask];
                        if (current_dp != 16'd65535) begin
                            theorem_idx <= 3'd0;
                            state <= LOOP_THEOREM;
                        end else begin
                            state <= NEXT_MASK;
                        end
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                LOOP_THEOREM: begin
                    if (theorem_idx < n) begin
                        if (!(mask[theorem_idx])) begin
                            proof_idx <= 2'd0;
                            min_cost <= 16'd65535;
                            state <= LOOP_PROOF;
                        end else begin
                            state <= NEXT_THEOREM;
                        end
                    end else begin
                        state <= NEXT_MASK;
                    end
                end

                LOOP_PROOF: begin
                    if (proof_idx < num_proofs[theorem_idx]) begin
                        dep_mask <= proof_dep[theorem_idx][proof_idx];
                        dep_ok <= (dep_mask & ~mask) == 8'd0;
                        if (dep_ok) begin
                            temp_cost <= proof_len[theorem_idx][proof_idx];
                            if (temp_cost < min_cost) begin
                                min_cost <= temp_cost;
                            end
                        end
                        state <= NEXT_PROOF;
                    end else begin
                        if (min_cost != 16'd65535) begin
                            new_dp <= current_dp + min_cost;
                            state <= UPDATE_DP;
                        end else begin
                            state <= NEXT_THEOREM;
                        end
                    end
                end

                UPDATE_DP: begin
                    if (new_dp < dp[mask | (1 << theorem_idx)]) begin
                        dp[mask | (1 << theorem_idx)] <= new_dp;
                    end
                    state <= NEXT_THEOREM;
                end

                NEXT_MASK: begin
                    mask <= mask + 8'd1;
                    state <= LOOP_MASK;
                end

                NEXT_THEOREM: begin
                    theorem_idx <= theorem_idx + 3'd1;
                    state <= LOOP_THEOREM;
                end

                NEXT_PROOF: begin
                    proof_idx <= proof_idx + 2'd1;
                    state <= LOOP_PROOF;
                end

                DONE_STATE: begin
                    // Find minimum dp with bit 0 set
                    result <= 16'd65535;
                    for (i = 1; i < 256; i = i + 1) begin
                        if (i[0] && dp[i] < result) begin
                            result <= dp[i];
                        end
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule