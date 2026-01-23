module atom_explodification (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] k,
    input wire [3:0] n,
    input wire [31:0] a_1,
    input wire [31:0] a_2,
    input wire [31:0] a_3,
    input wire [31:0] a_4,
    input wire [31:0] a_5,
    input wire [31:0] a_6,
    input wire [31:0] a_7,
    input wire [31:0] a_8,
    input wire [31:0] a_9,
    input wire [31:0] a_10,
    input wire [31:0] a_11,
    input wire [31:0] a_12,
    input wire [31:0] a_13,
    input wire [31:0] a_14,
    input wire [31:0] a_15,
    input wire [31:0] a_16,
    output reg [31:0] min_energy,
    output reg done
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam SETUP_BASE = 3'b001;
    localparam COMPUTE_BASE = 3'b010;
    localparam SETUP_DP = 3'b011;
    localparam COMPUTE_DP = 3'b100;
    localparam STORE_DP = 3'b101;
    localparam FINISHED = 3'b110;

    // Registers
    reg [2:0] state;
    reg [3:0] current_k;
    reg [3:0] i;
    reg [3:0] j;
    reg [31:0] dp [1:16];
    reg [31:0] temp_min;
    reg [31:0] temp_sum;
    reg [31:0] a_mux;

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
            a_mux <= 32'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        if (k == 0) begin
                            min_energy <= 32'b0;
                            state <= FINISHED;
                        end else if (k > 16) begin
                            min_energy <= 32'hFFFFFFFF;
                            state <= FINISHED;
                        end else begin
                            // Check if direct base case
                            if (k <= n) begin
                                current_k <= k;
                                state <= SETUP_BASE;
                            end else begin
                                // DP needed
                                current_k <= 4'd1;
                                state <= SETUP_BASE;
                            end
                        end
                    end
                end

                SETUP_BASE: begin
                    // Select a value for current_k
                    case (current_k)
                        4'd1: a_mux <= a_1;
                        4'd2: a_mux <= a_2;
                        4'd3: a_mux <= a_3;
                        4'd4: a_mux <= a_4;
                        4'd5: a_mux <= a_5;
                        4'd6: a_mux <= a_6;
                        4'd7: a_mux <= a_7;
                        4'd8: a_mux <= a_8;
                        4'd9: a_mux <= a_9;
                        4'd10: a_mux <= a_10;
                        4'd11: a_mux <= a_11;
                        4'd12: a_mux <= a_12;
                        4'd13: a_mux <= a_13;
                        4'd14: a_mux <= a_14;
                        4'd15: a_mux <= a_15;
                        4'd16: a_mux <= a_16;
                        default: a_mux <= 32'hFFFFFFFF;
                    endcase
                    state <= COMPUTE_BASE;
                end

                COMPUTE_BASE: begin
                    if (current_k <= n) begin
                        dp[current_k] <= a_mux;
                    end else begin
                        // Start DP computation
                        state <= SETUP_DP;
                        current_k <= n + 1'b1;
                        i <= 4'd1;
                        j <= n;
                        temp_min <= 32'hFFFFFFFF;
                        // Done with base cases
                        state <= SETUP_DP;
                    end
                    // Increment current_k if not done with base
                    if (current_k < n && current_k < 16) begin
                        current_k <= current_k + 1'b1;
                        state <= SETUP_BASE;
                    end else if (current_k == n) begin
                        // Store the last base case
                        dp[current_k] <= a_mux;
                        current_k <= n + 1'b1;
                        state <= SETUP_DP;
                    end else if (k <= n) begin
                        // Direct base case return
                        min_energy <= a_mux;
                        state <= FINISHED;
                    end
                end

                SETUP_DP: begin
                    if (current_k > 16) begin
                        // Finished computing table
                        min_energy <= dp[k];
                        state <= FINISHED;
                    end else if (i < current_k) begin
                        // Compute sum
                        temp_sum <= dp[i] + dp[j];
                        state <= COMPUTE_DP;
                    end else begin
                        // Finished this k
                        dp[current_k] <= temp_min;
                        current_k <= current_k + 1'b1;
                        i <= 4'd1;
                        j <= current_k;
                        temp_min <= 32'hFFFFFFFF;
                        state <= SETUP_DP;
                    end
                end

                COMPUTE_DP: begin
                    if (temp_sum < temp_min) begin
                        temp_min <= temp_sum;
                    end
                    i <= i + 1'b1;
                    j <= j - 1'b1;
                    state <= SETUP_DP;
                end

                FINISHED: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule