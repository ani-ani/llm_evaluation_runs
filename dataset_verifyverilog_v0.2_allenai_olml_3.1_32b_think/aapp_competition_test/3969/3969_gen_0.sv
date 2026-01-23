module replant_solver (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [3:0] N,
    input [4:0] M, // unused
    input [3:0] species_in,
    input load_species,
    output reg [3:0] result,
    output reg done
);

    // Registers
    reg [3:0] species_buffer [7:0];
    reg [2:0] load_count;
    reg [3:0] N_reg;
    reg [3:0] dp [7:0];
    reg [3:0] max_len;
    reg [3:0] result_reg;
    reg [2:0] state; // 3 bits: 000=IDLE, 001=LOAD, 010=COMPUTE_DP, 011=FIND_MAX, 100=CALCULATE_RESULT, 101=DONE
    reg done_reg;

    // State machine and control logic
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            // Reset all registers
            species_buffer <= 8'b0;
            load_count <= 3'b0;
            N_reg <= 4'b0;
            dp <= 8*4'b0;
            max_len <= 4'b0;
            result_reg <= 4'b0;
            state <= 3'b0; // IDLE
            done_reg <= 1'b0;
        end else begin
            case (state)
                3'b000: // IDLE
                    if (start) begin
                        if (load_count == N_reg && N_reg > 0) begin
                            // Move to LOAD state (dummy)
                            state <= 3'b001; // LOAD
                        end
                    end
                    // Handle loading species_in when load_species is high and not done
                    if (load_species && load_count < N_reg) begin
                        species_buffer[load_count] <= species_in;
                        load_count <= load_count + 1;
                    end
                    done_reg <= 1'b0;
                    // Stay in IDLE
                end
                3'b001: // LOAD - dummy state, transition to COMPUTE
                    state <= 3'b010; // COMPUTE_DP
                end
                3'b010: // COMPUTE_DP: calculate dp array
                    // Initialize dp to 1 for all valid entries
                    dp[0] = 1;
                    if (N_reg > 1) dp[1] = 1;
                    if (N_reg > 2) dp[2] = 1;
                    if (N_reg > 3) dp[3] = 1;
                    if (N_reg > 4) dp[4] = 1;
                    if (N_reg > 5) dp[5] = 1;
                    if (N_reg > 6) dp[6] = 1;
                    if (N_reg > 7) dp[7] = 1;

                    // Compute dp values
                    if (N_reg > 1) begin
                        if (species_buffer[0] <= species_buffer[1])
                            dp[1] = dp[0] + 1;
                    end
                    if (N_reg > 2) begin
                        dp[2] = 1;
                        if (species_buffer[0] <= species_buffer[2])
                            dp[2] = max(dp[2], dp[0] + 1);
                        if (species_buffer[1] <= species_buffer[2])
                            dp[2] = max(dp[2], dp[1] + 1);
                    end
                    if (N_reg > 3) begin
                        dp[3] = 1;
                        if (species_buffer[0] <= species_buffer[3])
                            dp[3] = max(dp[3], dp[0] + 1);
                        if (species_buffer[1] <= species_buffer[3])
                            dp[3] = max(dp[3], dp[1] + 1);
                        if (species_buffer[2] <= species_buffer[3])
                            dp[3] = max(dp[3], dp[2] + 1);
                    end
                    if (N_reg > 4) begin
                        dp[4] = 1;
                        if (species_buffer[0] <= species_buffer[4])
                            dp[4] = max(dp[4], dp[0] + 1);
                        if (species_buffer[1] <= species_buffer[4])
                            dp[4] = max(dp[4], dp[1] + 1);
                        if (species_buffer[2] <= species_buffer[4])
                            dp[4] = max(dp[4], dp[2] + 1);
                        if (species_buffer[3] <= species_buffer[4])
                            dp[4] = max(dp[4], dp[3] + 1);
                    end
                    if (N_reg > 5) begin
                        dp[5] = 1;
                        if (species_buffer[0] <= species_buffer[5])
                            dp[5] = max(dp[5], dp[0] + 1);
                        if (species_buffer[1] <= species_buffer[5])
                            dp[5] = max(dp[5], dp[1] + 1);
                        if (species_buffer[2] <= species_buffer[5])
                            dp[5] = max(dp[5], dp[2] + 1);
                        if (species_buffer[3] <= species_buffer[5])
                            dp[5] = max(dp[5], dp[3] + 1);
                        if (species_buffer[4] <= species_buffer[5])
                            dp[5] = max(dp[5], dp[4] + 1);
                    end
                    if (N_reg > 6) begin
                        dp[6] = 1;
                        if (species_buffer[0] <= species_buffer[6])
                            dp[6] = max(dp[6], dp[0] + 1);
                        if (species_buffer[1] <= species_buffer[6])
                            dp[6] = max(dp[6], dp[1] + 1);
                        if (species_buffer[2] <= species_buffer[6])
                            dp[6] = max(dp[6], dp[2] + 1);
                        if (species_buffer[3] <= species_buffer[6])
                            dp[6] = max(dp[6], dp[3] + 1);
                        if (species_buffer[4] <= species_buffer[6])
                            dp[6] = max(dp[6], dp[4] + 1);
                        if (species_buffer[5] <= species_buffer[6])
                            dp[6] = max(dp[6], dp[5] + 1);
                    end
                    if (N_reg > 7) begin
                        dp[7] = 1;
                        if (species_buffer[0] <= species_buffer[7])
                            dp[7] = max(dp[7], dp[0] + 1);
                        if (species_buffer[1] <= species_buffer[7])
                            dp[7] = max(dp[7], dp[1] + 1);
                        if (species_buffer[2] <= species_buffer[7])
                            dp[7] = max(dp[7], dp[2] + 1);
                        if (species_buffer[3] <= species_buffer[7])
                            dp[7] = max(dp[7], dp[3] + 1);
                        if (species_buffer[4] <= species_buffer[7])
                            dp[7] = max(dp[7], dp[4] + 1);
                        if (species_buffer[5] <= species_buffer[7])
                            dp[7] = max(dp[7], dp[5] + 1);
                        if (species_buffer[6] <= species_buffer[7])
                            dp[7] = max(dp[7], dp[6] + 1);
                    end

                    // Move to FIND_MAX state
                    state <= 3'b011; // FIND_MAX
                end
                3'b011: // FIND_MAX: find maximum dp value
                    max_len = 1;
                    if (N_reg > 1) max_len = max(max_len, dp[1]);
                    if (N_reg > 2) max_len = max(max_len, dp[2]);
                    if (N_reg > 3) max_len = max(max_len, dp[3]);
                    if (N_reg > 4) max_len = max(max_len, dp[4]);
                    if (N_reg > 5) max_len = max(max_len, dp[5]);
                    if (N_reg > 6) max_len = max(max_len, dp[6]);
                    if (N_reg > 7) max_len = max(max_len, dp[7]);

                    // Move to CALCULATE_RESULT
                    state <= 3'b100; // CALCULATE_RESULT
                end
                3'b100: // CALCULATE_RESULT: compute result and done
                    result_reg = N_reg - max_len;
                    done_reg = 1'b1;
                    state <= 3'b101; // DONE
                end
                3'b101: // DONE: assert done and keep result
                    done_reg = 1'b1;
                    // result_reg is already computed
                    state <= 3'b101; // stay in DONE
                end
            endcase
        end
    end
endmodule