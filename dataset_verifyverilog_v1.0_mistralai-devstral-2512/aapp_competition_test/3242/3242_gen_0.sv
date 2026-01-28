module polly_finder (
    input clk,
    input rst_n,
    input start,
    input [7:0] e_0, e_1, e_2, e_3, e_4, e_5, e_6, e_7,
    input [7:0] p_0, p_1, p_2, p_3, p_4, p_5, p_6, p_7,
    input [7:0] P_target,
    output reg [10:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] CALC_BOXES = 3'd2;
    localparam [2:0] FIND_RESULT = 3'd3;

    // DP memory: 2048 entries of 8-bit probabilities
    reg [7:0] dp_mem [0:2047];

    // Control registers
    reg [2:0] state, next_state;
    reg [2:0] box_idx;
    reg [10:0] energy_idx;
    reg [10:0] result_idx;

    // Registered inputs
    reg [7:0] e_reg [0:7];
    reg [7:0] p_reg [0:7];
    reg [7:0] P_target_reg;

    // Temporary registers for DP update
    reg [7:0] current_prob;
    reg [7:0] new_prob;
    reg [10:0] new_energy;

    // Initialize DP memory
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset state machine
            state <= IDLE;
            next_state <= IDLE;
            box_idx <= 3'd0;
            energy_idx <= 11'd0;
            result_idx <= 11'd0;
            result <= 11'd0;
            done <= 1'b0;

            // Reset DP memory
            for (i = 0; i < 2048; i = i + 1) begin
                dp_mem[i] <= 8'd0;
            end
            dp_mem[0] <= 8'd0; // Base case: 0 energy gives 0 probability

            // Reset registered inputs
            for (i = 0; i < 8; i = i + 1) begin
                e_reg[i] <= 8'd0;
                p_reg[i] <= 8'd0;
            end
            P_target_reg <= 8'd0;
        end else begin
            // State transition
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Register inputs
                        e_reg[0] <= e_0;
                        e_reg[1] <= e_1;
                        e_reg[2] <= e_2;
                        e_reg[3] <= e_3;
                        e_reg[4] <= e_4;
                        e_reg[5] <= e_5;
                        e_reg[6] <= e_6;
                        e_reg[7] <= e_7;

                        p_reg[0] <= p_0;
                        p_reg[1] <= p_1;
                        p_reg[2] <= p_2;
                        p_reg[3] <= p_3;
                        p_reg[4] <= p_4;
                        p_reg[5] <= p_5;
                        p_reg[6] <= p_6;
                        p_reg[7] <= p_7;

                        P_target_reg <= P_target;

                        // Reset DP memory for new calculation
                        for (i = 0; i < 2048; i = i + 1) begin
                            dp_mem[i] <= 8'd0;
                        end
                        dp_mem[0] <= 8'd0;

                        // Initialize counters
                        box_idx <= 3'd0;
                        energy_idx <= 11'd0;
                        result_idx <= 11'd0;

                        next_state <= LOAD;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD: begin
                    // Initialize first box
                    box_idx <= 3'd0;
                    energy_idx <= 11'd0;
                    next_state <= CALC_BOXES;
                end

                CALC_BOXES: begin
                    // Process current box
                    if (energy_idx < 2048) begin
                        current_prob <= dp_mem[energy_idx];
                        new_energy <= energy_idx + e_reg[box_idx];
                        if (new_energy < 2048) begin
                            new_prob <= current_prob + p_reg[box_idx];
                            if (new_prob > dp_mem[new_energy]) begin
                                dp_mem[new_energy] <= new_prob;
                            end
                        end
                        energy_idx <= energy_idx + 11'd1;
                    end else begin
                        // Move to next box
                        box_idx <= box_idx + 3'd1;
                        if (box_idx < 8) begin
                            energy_idx <= 11'd0;
                        end else begin
                            // All boxes processed, find result
                            result_idx <= 11'd0;
                            next_state <= FIND_RESULT;
                        end
                    end
                end

                FIND_RESULT: begin
                    if (result_idx < 2048) begin
                        if (dp_mem[result_idx] >= P_target_reg) begin
                            result <= result_idx;
                            done <= 1'b1;
                            next_state <= IDLE;
                        end else begin
                            result_idx <= result_idx + 11'd1;
                        end
                    end else begin
                        // No solution found, return max energy
                        result <= 11'd2047;
                        done <= 1'b1;
                        next_state <= IDLE;
                    end
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule