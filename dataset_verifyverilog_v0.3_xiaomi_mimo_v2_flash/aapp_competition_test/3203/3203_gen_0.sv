module bond_assignment (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [127:0] prob,
    output reg [31:0] max_product,
    output reg done
);

    // Lookup table for number of set bits in 4-bit mask
    reg [1:0] set_bits [0:15];
    integer i;

    // State machine
    reg [2:0] state;
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] INIT         = 3'd1;
    localparam [2:0] UPDATE_AGENT = 3'd2;
    localparam [2:0] UPDATE_MASK  = 3'd3;
    localparam [2:0] UPDATE_MISSION = 3'd4;
    localparam [2:0] DONE         = 3'd5;

    reg [1:0] current_agent;
    reg [3:0] current_mask;
    reg [1:0] current_mission;
    reg [31:0] dp [0:15];
    reg [31:0] prob_matrix [0:3][0:3];

    // Initialize set_bits lookup table
    always @(*) begin
        set_bits[0] = 2'd0;  set_bits[1] = 2'd1;  set_bits[2] = 2'd1;  set_bits[3] = 2'd2;
        set_bits[4] = 2'd1;  set_bits[5] = 2'd2;  set_bits[6] = 2'd2;  set_bits[7] = 2'd3;
        set_bits[8] = 2'd1;  set_bits[9] = 2'd2;  set_bits[10] = 2'd2; set_bits[11] = 2'd3;
        set_bits[12] = 2'd2; set_bits[13] = 2'd3; set_bits[14] = 2'd3; set_bits[15] = 2'd4;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            max_product <= 32'd0;
            current_agent <= 2'd0;
            current_mask <= 4'd0;
            current_mission <= 2'd0;
            for (i = 0; i < 16; i = i + 1) begin
                dp[i] <= 32'd0;
            end
            for (i = 0; i < 16; i = i + 1) begin
                prob_matrix[i/4][i%4] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Unpack probabilities into 4x4 matrix
                        prob_matrix[0][0] <= prob[7:0];
                        prob_matrix[0][1] <= prob[15:8];
                        prob_matrix[0][2] <= prob[23:16];
                        prob_matrix[0][3] <= prob[31:24];
                        prob_matrix[1][0] <= prob[39:32];
                        prob_matrix[1][1] <= prob[47:40];
                        prob_matrix[1][2] <= prob[55:48];
                        prob_matrix[1][3] <= prob[63:56];
                        prob_matrix[2][0] <= prob[71:64];
                        prob_matrix[2][1] <= prob[79:72];
                        prob_matrix[2][2] <= prob[87:80];
                        prob_matrix[2][3] <= prob[95:88];
                        prob_matrix[3][0] <= prob[103:96];
                        prob_matrix[3][1] <= prob[111:104];
                        prob_matrix[3][2] <= prob[119:112];
                        prob_matrix[3][3] <= prob[127:120];
                        state <= INIT;
                    end
                end

                INIT: begin
                    for (i = 0; i < 16; i = i + 1) begin
                        dp[i] <= 32'd0;
                    end
                    dp[0] <= 32'd1;
                    current_agent <= 2'd0;
                    state <= UPDATE_AGENT;
                end

                UPDATE_AGENT: begin
                    current_mask <= 4'd0;
                    state <= UPDATE_MASK;
                end

                UPDATE_MASK: begin
                    if (current_mask < 16) begin
                        if (set_bits[current_mask] == current_agent) begin
                            current_mission <= 2'd0;
                            state <= UPDATE_MISSION;
                        end else begin
                            current_mask <= current_mask + 4'd1;
                        end
                    end else begin
                        if (current_agent < N - 2'd1) begin
                            current_agent <= current_agent + 2'd1;
                            state <= UPDATE_AGENT;
                        end else begin
                            state <= DONE;
                        end
                    end
                end

                UPDATE_MISSION: begin
                    if (current_mission < N) begin
                        if (!current_mask[current_mission]) begin
                            reg [3:0] new_mask;
                            reg [31:0] product;
                            new_mask = current_mask | (4'd1 << current_mission);
                            product = dp[current_mask] * prob_matrix[current_agent][current_mission];
                            if (product > dp[new_mask]) begin
                                dp[new_mask] <= product;
                            end
                        end
                        current_mission <= current_mission + 2'd1;
                    end else begin
                        state <= UPDATE_MASK;
                        current_mask <= current_mask + 4'd1;
                    end
                end

                DONE: begin
                    max_product <= dp[4'd15];
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule