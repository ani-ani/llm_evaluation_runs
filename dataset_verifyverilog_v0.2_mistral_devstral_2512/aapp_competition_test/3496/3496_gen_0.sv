module atom_explodification (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] k,  // neutron count (1-15)
    input wire [3:0] n,  // threshold (1-15)
    input wire [31:0] a_1,  // energy for 1 neutron
    input wire [31:0] a_2,  // energy for 2 neutrons
    input wire [31:0] a_3,  // energy for 3 neutrons
    input wire [31:0] a_4,  // energy for 4 neutrons
    input wire [31:0] a_5,  // energy for 5 neutrons
    input wire [31:0] a_6,  // energy for 6 neutrons
    input wire [31:0] a_7,  // energy for 7 neutrons
    input wire [31:0] a_8,  // energy for 8 neutrons
    input wire [31:0] a_9,  // energy for 9 neutrons
    input wire [31:0] a_10, // energy for 10 neutrons
    input wire [31:0] a_11, // energy for 11 neutrons
    input wire [31:0] a_12, // energy for 12 neutrons
    input wire [31:0] a_13, // energy for 13 neutrons
    input wire [31:0] a_14, // energy for 14 neutrons
    input wire [31:0] a_15, // energy for 15 neutrons
    input wire [31:0] a_16, // energy for 16 neutrons
    output reg [31:0] min_energy,
    output reg done
);

    // State definitions
    localparam IDLE = 2'b00;
    localparam COMPUTE_BASE = 2'b01;
    localparam COMPUTE_DP = 2'b10;
    localparam FINISHED = 2'b11;

    // Registers
    reg [1:0] state;
    reg [3:0] current_k;
    reg [3:0] i;
    reg [3:0] j;
    reg [31:0] dp [1:16];  // DP table for k=1 to 16
    reg [31:0] temp_min;
    reg [31:0] temp_sum;

    // Helper function to get base energy
    function [31:0] get_base_energy;
        input [3:0] idx;
        case(idx)
            4'd1: get_base_energy = a_1;
            4'd2: get_base_energy = a_2;
            4'd3: get_base_energy = a_3;
            4'd4: get_base_energy = a_4;
            4'd5: get_base_energy = a_5;
            4'd6: get_base_energy = a_6;
            4'd7: get_base_energy = a_7;
            4'd8: get_base_energy = a_8;
            4'd9: get_base_energy = a_9;
            4'd10: get_base_energy = a_10;
            4'd11: get_base_energy = a_11;
            4'd12: get_base_energy = a_12;
            4'd13: get_base_energy = a_13;
            4'd14: get_base_energy = a_14;
            4'd15: get_base_energy = a_15;
            4'd16: get_base_energy = a_16;
            default: get_base_energy = 32'hFFFFFFFF;
        endcase
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            min_energy <= 32'b0;
            current_k <= 4'b0;
            i <= 4'b0;
            j <= 4'b0;
            temp_min <= 32'hFFFFFFFF;
            temp_sum <= 32'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current_k <= k;
                        if (k <= n && k >= 1 && k <= 16) begin
                            // Direct base case
                            min_energy <= get_base_energy(k);
                            state <= FINISHED;
                        end else if (k > n && k <= 16) begin
                            // Need DP computation
                            i <= 4'd1;
                            j <= k - 4'd1;
                            temp_min <= 32'hFFFFFFFF;
                            state <= COMPUTE_DP;
                        end else if (k == 0) begin
                            min_energy <= 32'b0;
                            state <= FINISHED;
                        end else begin
                            // k > 16, unsupported
                            min_energy <= 32'hFFFFFFFF;
                            state <= FINISHED;
                        end
                    end
                end

                COMPUTE_DP: begin
                    // Compute DP table iteratively
                    // First, compute base cases
                    if (current_k <= 16) begin
                        if (current_k >= 1 && current_k <= n) begin
                            dp[current_k] <= get_base_energy(current_k);
                            current_k <= current_k + 1'b1;
                            if (current_k == n) begin
                                current_k <= n + 1'b1;
                            end
                        end else if (current_k > n && current_k <= 16) begin
                            // Compute dp[current_k] = min over i+j=current_k of dp[i]+dp[j]
                            if (i < current_k) begin
                                if (i >= 1 && j >= 1 && i <= 16 && j <= 16) begin
                                    temp_sum <= dp[i] + dp[j];
                                    if (dp[i] + dp[j] < temp_min) begin
                                        temp_min <= dp[i] + dp[j];
                                    end
                                end
                                i <= i + 1'b1;
                                j <= j - 1'b1;
                            end else begin
                                dp[current_k] <= temp_min;
                                current_k <= current_k + 1'b1;
                                i <= 4'd1;
                                j <= current_k;  // for next iteration
                                temp_min <= 32'hFFFFFFFF;
                                if (current_k == 16) begin
                                    // Done computing table, now get answer
                                    if (k <= 16) begin
                                        min_energy <= dp[k];
                                        state <= FINISHED;
                                    end else begin
                                        state <= FINISHED;
                                    end
                                end
                            end
                        end else begin
                            current_k <= current_k + 1'b1;
                        end
                    end
                end

                FINISHED: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule