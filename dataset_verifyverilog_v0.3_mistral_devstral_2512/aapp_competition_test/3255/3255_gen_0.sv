module hopper_exploration (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [2:0] D,
    input [7:0] M,
    input [7:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
    output reg [3:0] length,
    output reg done
);

    // State definitions
    localparam [1:0] STATE_IDLE = 2'd0;
    localparam [1:0] STATE_INIT = 2'd1;
    localparam [1:0] STATE_COMPUTE = 2'd2;
    localparam [1:0] STATE_DONE = 2'd3;

    // Registers
    reg [1:0] state, next_state;
    reg [2:0] i, j;
    reg [7:0] dp [0:255];
    reg [7:0] max_len_reg;
    reg [7:0] arr_reg [0:7];
    reg [2:0] n_reg, D_reg;
    reg [7:0] M_reg;

    // Combinational logic
    wire signed [7:0] arr_val_i = arr_reg[i];
    wire signed [7:0] arr_val_j = arr_reg[j];
    wire signed [7:0] diff = arr_val_i - arr_val_j;
    wire valid_jump = (j < n_reg) && (j != i) && 
                      (($signed(diff) >= -$signed(M_reg)) && ($signed(diff) <= $signed(M_reg))) &&
                      (($signed(i) - $signed(j) >= -$signed(D_reg)) && ($signed(i) - $signed(j) <= $signed(D_reg)));

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            done <= 1'b0;
            length <= 4'd0;
            i <= 3'd0;
            j <= 3'd0;
            max_len_reg <= 8'd0;
            n_reg <= 3'd0;
            D_reg <= 3'd0;
            M_reg <= 8'd0;
            for (integer k = 0; k < 8; k = k + 1) begin
                arr_reg[k] <= 8'd0;
            end
            for (integer k = 0; k < 256; k = k + 1) begin
                dp[k] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            STATE_IDLE: if (start) next_state = STATE_INIT;
            STATE_INIT: next_state = STATE_COMPUTE;
            STATE_COMPUTE: if (i >= n_reg) next_state = STATE_DONE;
            STATE_DONE: next_state = STATE_IDLE;
            default: next_state = STATE_IDLE;
        endcase
    end

    // Main computation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already reset in state machine block
        end else begin
            case (state)
                STATE_INIT: begin
                    arr_reg[0] <= arr_0;
                    arr_reg[1] <= arr_1;
                    arr_reg[2] <= arr_2;
                    arr_reg[3] <= arr_3;
                    arr_reg[4] <= arr_4;
                    arr_reg[5] <= arr_5;
                    arr_reg[6] <= arr_6;
                    arr_reg[7] <= arr_7;
                    n_reg <= n;
                    D_reg <= D;
                    M_reg <= M;
                    
                    // Initialize DP table
                    for (integer k = 0; k < 8; k = k + 1) begin
                        if (k < n) dp[1 << k] <= 1;
                        else dp[1 << k] <= 0;
                    end
                    
                    i <= 0;
                    j <= 0;
                    max_len_reg <= 1;
                end
                
                STATE_COMPUTE: begin
                    if (i < n_reg) begin
                        if (j < n_reg) begin
                            if (valid_jump) begin
                                if (dp[(1 << i) | (1 << j)] < dp[1 << i] + 1) begin
                                    dp[(1 << i) | (1 << j)] <= dp[1 << i] + 1;
                                    if (dp[1 << i] + 1 > max_len_reg) begin
                                        max_len_reg <= dp[1 << i] + 1;
                                    end
                                end
                            end
                            j <= j + 1;
                        end else begin
                            j <= 0;
                            i <= i + 1;
                        end
                    end
                end
                
                STATE_DONE: begin
                    done <= 1'b1;
                    length <= max_len_reg[3:0];
                end
                
                STATE_IDLE: begin
                    done <= 1'b0;
                    i <= 0;
                    j <= 0;
                end
            endcase
        end
    end

endmodule