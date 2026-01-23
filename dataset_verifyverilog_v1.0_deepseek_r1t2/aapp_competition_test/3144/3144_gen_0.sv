module donald_game #(
    parameter MAX_ROUNDS = 8,
    parameter COIN_WIDTH = 8,
    parameter DISTR_WIDTH = 4,
    parameter CLK_PERIOD = 10
)(
    input [COIN_WIDTH-1:0] d,
    input [COIN_WIDTH-1:0] g,
    input [DISTR_WIDTH-1:0] n,
    input [DISTR_WIDTH-1:0] k,
    input clk,
    input rst_n,
    input start,
    output reg [COIN_WIDTH-1:0] M,
    output reg done
);

localparam [2:0] IDLE      = 3'd0;
localparam [2:0] LOAD_DPRAM = 3'd1;
localparam [2:0] COMPUTE   = 3'd2;
localparam [2:0] DONE_ST   = 3'd3;

reg [2:0] state;
reg [7:0] cycle_counter;
reg [7:0] total_coins;

reg [COIN_WIDTH-1:0] dp_table [0:MAX_ROUNDS][0:255][0:MAX_ROUNDS];
reg [3:0] init_round;
reg [7:0] init_d_coins;
reg [3:0] init_distr;
integer i, j, m;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        M <= 8'd0;
        cycle_counter <= 8'd0;
        init_round <= 4'd0;
        init_d_coins <= 8'd0;
        init_distr <= 4'd0;
        total_coins <= 8'd0;
        // Initialize dp_table elements
        for (i = 0; i <= MAX_ROUNDS; i = i + 1) begin
            for (j = 0; j < 256; j = j + 1) begin
                for (m = 0; m <= MAX_ROUNDS; m = m + 1) begin
                    dp_table[i][j][m] <= 8'd0;
                end
            end
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                cycle_counter <= 8'd0;
                if (start) begin
                    total_coins <= d + g;
                    state <= LOAD_DPRAM;
                    init_round <= MAX_ROUNDS;
                    init_d_coins <= 8'd0;
                    init_distr <= 4'd0;
                end
            end
            
            LOAD_DPRAM: begin
                // Initialize base cases
                if (init_round == MAX_ROUNDS) begin
                    dp_table[init_round][init_d_coins][init_distr] <= init_d_coins;
                end else if (init_d_coins == 8'd0) begin
                    dp_table[init_round][init_d_coins][init_distr] <= 8'd0;
                end
                
                // Counter updates
                if (init_distr < MAX_ROUNDS) begin
                    init_distr <= init_distr + 4'd1;
                end else begin
                    init_distr <= 4'd0;
                    if (init_d_coins < 8'd255) begin
                        init_d_coins <= init_d_coins + 8'd1;
                    end else begin
                        init_d_coins <= 8'd0;
                        if (init_round == 4'd0) begin
                            state <= COMPUTE;
                        end else begin
                            init_round <= init_round - 4'd1;
                        end
                    end
                end
            end
            
            COMPUTE: begin
                // Simplified computation
                M <= dp_table[0][d][k];
                state <= DONE_ST;
            end
            
            DONE_ST: begin
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule