module PathCount(
    input clk,
    input rst_n,
    input start,
    input [2:0] x_init,
    input [2:0] grid_0_0, input [2:0] grid_0_1, input [2:0] grid_0_2, input [2:0] grid_0_3,
    input [2:0] grid_0_4, input [2:0] grid_0_5, input [2:0] grid_0_6, input [2:0] grid_0_7,
    input [2:0] grid_1_0, input [2:0] grid_1_1, input [2:0] grid_1_2, input [2:0] grid_1_3,
    input [2:0] grid_1_4, input [2:0] grid_1_5, input [2:0] grid_1_6, input [2:0] grid_1_7,
    input [2:0] grid_2_0, input [2:0] grid_2_1, input [2:0] grid_2_2, input [2:0] grid_2_3,
    input [2:0] grid_2_4, input [2:0] grid_2_5, input [2:0] grid_2_6, input [2:0] grid_2_7,
    input [2:0] grid_3_0, input [2:0] grid_3_1, input [2:0] grid_3_2, input [2:0] grid_3_3,
    input [2:0] grid_3_4, input [2:0] grid_3_5, input [2:0] grid_3_6, input [2:0] grid_3_7,
    input [2:0] grid_4_0, input [2:0] grid_4_1, input [2:0] grid_4_2, input [2:0] grid_4_3,
    input [2:0] grid_4_4, input [2:0] grid_4_5, input [2:0] grid_4_6, input [2:0] grid_4_7,
    input [2:0] grid_5_0, input [2:0] grid_5_1, input [2:0] grid_5_2, input [2:0] grid_5_3,
    input [2:0] grid_5_4, input [2:0] grid_5_5, input [2:0] grid_5_6, input [2:0] grid_5_7,
    input [2:0] grid_6_0, input [2:0] grid_6_1, input [2:0] grid_6_2, input [2:0] grid_6_3,
    input [2:0] grid_6_4, input [2:0] grid_6_5, input [2:0] grid_6_6, input [2:0] grid_6_7,
    input [2:0] grid_7_0, input [2:0] grid_7_1, input [2:0] grid_7_2, input [2:0] grid_7_3,
    input [2:0] grid_7_4, input [2:0] grid_7_5, input [2:0] grid_7_6, input [2:0] grid_7_7,
    output reg [19:0] result,
    output reg done,
    output reg begin_repairs
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] LOAD_GRID  = 3'd1;
    localparam [2:0] COMPUTE    = 3'd2;
    localparam [2:0] DONE       = 3'd3;

    // Cell type definitions
    localparam [2:0] CELL_OPEN  = 3'd0; // ~
    localparam [2:0] CELL_BLOCK = 3'd1; // #
    localparam [2:0] CELL_GT    = 3'd2; // >
    localparam [2:0] CELL_LT    = 3'd3; // <
    localparam [2:0] CELL_CASTLE = 3'd4; // @

    localparam [19:0] MOD = 20'd1000003;

    // Internal state
    reg [2:0] state, next_state;
    reg [2:0] y_curr, y_next;
    reg [2:0] x_curr, x_next;
    reg [2:0] x_init_reg;
    
    // Grid storage (64 cells, 3-bit each)
    reg [2:0] grid_mem [0:63];
    
    // DP storage (64 cells, 20-bit each)
    reg [19:0] dp [0:63];
    
    // Computation registers
    reg [19:0] sum_val;
    reg [19:0] temp_val;
    reg [2:0] cell_type;
    reg [5:0] idx; // y * 8 + x
    reg [5:0] src_idx;
    reg [1:0] counter; // 0, 1, 2 for adding sources
    
    // Grid load counter
    reg [5:0] load_cnt;
    reg load_done;

    // Helper signals
    wire [5:0] idx_north;
    wire [5:0] idx_east;
    wire [5:0] idx_west;
    wire [5:0] idx_gt_src;
    wire [5:0] idx_lt_src;
    
    // Index calculations
    assign idx_north = {y_curr, x_curr} - 8'd8; // (y-1, x)
    assign idx_east  = {y_curr, x_curr} + 8'd1;  // (y, x+1)
    assign idx_west  = {y_curr, x_curr} - 8'd1;  // (y, x-1)
    // Src for '>' at (y, x) is (y, x-1)
    assign idx_gt_src = {y_curr, x_curr} - 8'd1;
    // Src for '<' at (y, x) is (y, x+1)
    assign idx_lt_src = {y_curr, x_curr} + 8'd1;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? LOAD_GRID : IDLE;
            LOAD_GRID: next_state = load_done ? COMPUTE : LOAD_GRID;
            COMPUTE: next_state = (y_curr == 3'd0 && x_curr == 3'd0) ? DONE : COMPUTE;
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            y_curr <= 3'd0;
            x_curr <= 3'd0;
            x_init_reg <= 3'd0;
            load_cnt <= 6'd0;
            load_done <= 1'b0;
            sum_val <= 20'd0;
            temp_val <= 20'd0;
            cell_type <= 3'd0;
            counter <= 2'd0;
            idx <= 6'd0;
            src_idx <= 6'd0;
            result <= 20'd0;
            done <= 1'b0;
            begin_repairs <= 1'b0;
            // Initialize grid and dp arrays to 0
            grid_mem[0] <= 3'd0; grid_mem[1] <= 3'd0; grid_mem[2] <= 3'd0; grid_mem[3] <= 3'd0;
            grid_mem[4] <= 3'd0; grid_mem[5] <= 3'd0; grid_mem[6] <= 3'd0; grid_mem[7] <= 3'd0;
            grid_mem[8] <= 3'd0; grid_mem[9] <= 3'd0; grid_mem[10] <= 3'd0; grid_mem[11] <= 3'd0;
            grid_mem[12] <= 3'd0; grid_mem[13] <= 3'd0; grid_mem[14] <= 3'd0; grid_mem[15] <= 3'd0;
            grid_mem[16] <= 3'd0; grid_mem[17] <= 3'd0; grid_mem[18] <= 3'd0; grid_mem[19] <= 3'd0;
            grid_mem[20] <= 3'd0; grid_mem[21] <= 3'd0; grid_mem[22] <= 3'd0; grid_mem[23] <= 3'd0;
            grid_mem[24] <= 3'd0; grid_mem[25] <= 3'd0; grid_mem[26] <= 3'd0; grid_mem[27] <= 3'd0;
            grid_mem[28] <= 3'd0; grid_mem[29] <= 3'd0; grid_mem[30] <= 3'd0; grid_mem[31] <= 3'd0;
            grid_mem[32] <= 3'd0; grid_mem[33] <= 3'd0; grid_mem[34] <= 3'd0; grid_mem[35] <= 3'd0;
            grid_mem[36] <= 3'd0; grid_mem[37] <= 3'd0; grid_mem[38] <= 3'd0; grid_mem[39] <= 3'd0;
            grid_mem[40] <= 3'd0; grid_mem[41] <= 3'd0; grid_mem[42] <= 3'd0; grid_mem[43] <= 3'd0;
            grid_mem[44] <= 3'd0; grid_mem[45] <= 3'd0; grid_mem[46] <= 3'd0; grid_mem[47] <= 3'd0;
            grid_mem[48] <= 3'd0; grid_mem[49] <= 3'd0; grid_mem[50] <= 3'd0; grid_mem[51] <= 3'd0;
            grid_mem[52] <= 3'd0; grid_mem[53] <= 3'd0; grid_mem[54] <= 3'd0; grid_mem[55] <= 3'd0;
            grid_mem[56] <= 3'd0; grid_mem[57] <= 3'd0; grid_mem[58] <= 3'd0; grid_mem[59] <= 3'd0;
            grid_mem[60] <= 3'd0; grid_mem[61] <= 3'd0; grid_mem[62] <= 3'd0; grid_mem[63] <= 3'd0;
            dp[0] <= 20'd0; dp[1] <= 20'd0; dp[2] <= 20'd0; dp[3] <= 20'd0;
            dp[4] <= 20'd0; dp[5] <= 20'd0; dp[6] <= 20'd0; dp[7] <= 20'd0;
            dp[8] <= 20'd0; dp[9] <= 20'd0; dp[10] <= 20'd0; dp[11] <= 20'd0;
            dp[12] <= 20'd0; dp[13] <= 20'd0; dp[14] <= 20'd0; dp[15] <= 20'd0;
            dp[16] <= 20'd0; dp[17] <= 20'd0; dp[18] <= 20'd0; dp[19] <= 20'd0;
            dp[20] <= 20'd0; dp[21] <= 20'd0; dp[22] <= 20'd0; dp[23] <= 20'd0;
            dp[24] <= 20'd0; dp[25] <= 20'd0; dp[26] <= 20'd0; dp[27] <= 20'd0;
            dp[28] <= 20'd0; dp[29] <= 20'd0; dp[30] <= 20'd0; dp[31] <= 20'd0;
            dp[32] <= 20'd0; dp[33] <= 20'd0; dp[34] <= 20'd0; dp[35] <= 20'd0;
            dp[36] <= 20'd0; dp[37] <= 20'd0; dp[38] <= 20'd0; dp[39] <= 20'd0;
            dp[40] <= 20'd0; dp[41] <= 20'd0; dp[42] <= 20'd0; dp[43] <= 20'd0;
            dp[44] <= 20'd0; dp[45] <= 20'd0; dp[46] <= 20'd0; dp[47] <= 20'd0;
            dp[48] <= 20'd0; dp[49] <= 20'd0; dp[50] <= 20'd0; dp[51] <= 20'd0;
            dp[52] <= 20'd0; dp[53] <= 20'd0; dp[54] <= 20'd0; dp[55] <= 20'd0;
            dp[56] <= 20'd0; dp[57] <= 20'd0; dp[58] <= 20'd0; dp[59] <= 20'd0;
            dp[60] <= 20'd0; dp[61] <= 20'd0; dp[62] <= 20'd0; dp[63] <= 20'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        x_init_reg <= x_init;
                    end
                end

                LOAD_GRID: begin
                    load_cnt <= load_cnt + 6'd1;
                    // Map load_cnt to grid inputs and store
                    case (load_cnt)
                        6'd0:  grid_mem[0]  <= grid_0_0;
                        6'd1:  grid_mem[1]  <= grid_0_1;
                        6'd2:  grid_mem[2]  <= grid_0_2;
                        6'd3:  grid_mem[3]  <= grid_0_3;
                        6'd4:  grid_mem[4]  <= grid_0_4;
                        6'd5:  grid_mem[5]  <= grid_0_5;
                        6'd6:  grid_mem[6]  <= grid_0_6;
                        6'd7:  grid_mem[7]  <= grid_0_7;
                        6'd8:  grid_mem[8]  <= grid_1_0;
                        6'd9:  grid_mem[9]  <= grid_1_1;
                        6'd10: grid_mem[10] <= grid_1_2;
                        6'd11: grid_mem[11] <= grid_1_3;
                        6'd12: grid_mem[12] <= grid_1_4;
                        6'd13: grid_mem[13] <= grid_1_5;
                        6'd14: grid_mem[14] <= grid_1_6;
                        6'd15: grid_mem[15] <= grid_1_7;
                        6'd16: grid_mem[16] <= grid_2_0;
                        6'd17: grid_mem[17] <= grid_2_1;
                        6'd18: grid_mem[18] <= grid_2_2;
                        6'd19: grid_mem[19] <= grid_2_3;
                        6'd20: grid_mem[20] <= grid_2_4;
                        6'd21: grid_mem[21] <= grid_2_5;
                        6'd22: grid_mem[22] <= grid_2_6;
                        6'd23: grid_mem[23] <= grid_2_7;
                        6'd24: grid_mem[24] <= grid_3_0;
                        6'd25: grid_mem[25] <= grid_3_1;
                        6'd26: grid_mem[26] <= grid_3_2;
                        6'd27: grid_mem[27] <= grid_3_3;
                        6'd28: grid_mem[28] <= grid_3_4;
                        6'd29: grid_mem[29] <= grid_3_5;
                        6'd30: grid_mem[30] <= grid_3_6;
                        6'd31: grid_mem[31] <= grid_3_7;
                        6'd32: grid_mem[32] <= grid_4_0;
                        6'd33: grid_mem[33] <= grid_4_1;
                        6'd34: grid_mem[34] <= grid_4_2;
                        6'd35: grid_mem[35] <= grid_4_3;
                        6'd36: grid_mem[36] <= grid_4_4;
                        6'd37: grid_mem[37] <= grid_4_5;
                        6'd38: grid_mem[38] <= grid_4_6;
                        6'd39: grid_mem[39] <= grid_4_7;
                        6'd40: grid_mem[40] <= grid_5_0;
                        6'd41: grid_mem[41] <= grid_5_1;
                        6'd42: grid_mem[42] <= grid_5_2;
                        6'd43: grid_mem[43] <= grid_5_3;
                        6'd44: grid_mem[44] <= grid_5_4;
                        6'd45: grid_mem[45] <= grid_5_5;
                        6'd46: grid_mem[46] <= grid_5_6;
                        6'd47: grid_mem[47] <= grid_5_7;
                        6'd48: grid_mem[48] <= grid_6_0;
                        6'd49: grid_mem[49] <= grid_6_1;
                        6'd50: grid_mem[50] <= grid_6_2;
                        6'd51: grid_mem[51] <= grid_6_3;
                        6'd52: grid_mem[52] <= grid_6_4;
                        6'd53: grid_mem[53] <= grid_6_5;
                        6'd54: grid_mem[54] <= grid_6_6;
                        6'd55: grid_mem[55] <= grid_6_7;
                        6'd56: grid_mem[56] <= grid_7_0;
                        6'd57: grid_mem[57] <= grid_7_1;
                        6'd58: grid_mem[58] <= grid_7_2;
                        6'd59: grid_mem[59] <= grid_7_3;
                        6'd60: grid_mem[60] <= grid_7_4;
                        6'd61: grid_mem[61] <= grid_7_5;
                        6'd62: grid_mem[62] <= grid_7_6;
                        6'd63: grid_mem[63] <= grid_7_7;
                    endcase
                    if (load_cnt == 6'd63) begin
                        load_done <= 1'b1;
                        y_curr <= 3'd7;
                        x_curr <= 3'd7;
                    end
                end

                COMPUTE: begin
                    // Cell traversal: (7,7) -> ... -> (7,0) -> (6,7) -> ... -> (0,0)
                    
                    cell_type <= grid_mem[{y_curr, x_curr}];
                    
                    case (counter)
                        2'd0: begin
                            // Step 1: Initialize sum based on cell type
                            if (grid_mem[{y_curr, x_curr}] == CELL_CASTLE) begin
                                sum_val <= 20'd1; // Base case: 1 path at castle
                            end else begin
                                sum_val <= 20'd0;
                            end
                            counter <= 2'd1;
                            // Check for immediate invalid cell (BLOCK)
                            if (grid_mem[{y_curr, x_curr}] == CELL_BLOCK) begin
                                dp[{y_curr, x_curr}] <= 20'd0;
                                // Advance index immediately if blocked
                                if (x_curr == 3'd0) begin
                                    if (y_curr != 3'd0) begin
                                        y_curr <= y_curr - 3'd1;
                                        x_curr <= 3'd7;
                                    end
                                end else begin
                                    x_curr <= x_curr - 3'd1;
                                end
                                counter <= 2'd0;
                            end
                        end
                        
                        2'd1: begin
                            // Step 2: Add source from North (Lower Sails)
                            // Valid if current is OPEN, GT, LT, or CASTLE (and not BLOCK)
                            if (cell_type != CELL_BLOCK) begin
                                // Check if in bounds (not top row)
                                if (y_curr != 3'd0) begin
                                    src_idx <= idx_north;
                                    if (grid_mem[idx_north] != CELL_BLOCK) begin
                                        sum_val <= (sum_val + dp[idx_north]) % MOD;
                                    end
                                end
                            end
                            counter <= 2'd2;
                        end
                        
                        2'd2: begin
                            // Step 3: Add source from West or East (Retract Sails)
                            // Check currents: '>' at (y, x) pulls from (y, x-1)
                            // '<' at (y, x) pulls from (y, x+1)
                            if (grid_mem[{y_curr, x_curr}] == CELL_GT) begin
                                // > moves to x+1. Source is x-1 (West)
                                // Only valid if x > 0
                                if (x_curr != 3'd0) begin
                                    src_idx <= idx_gt_src;
                                    if (grid_mem[idx_gt_src] != CELL_BLOCK) begin
                                        sum_val <= (sum_val + dp[idx_gt_src]) % MOD;
                                    end
                                end
                            end else if (grid_mem[{y_curr, x_curr}] == CELL_LT) begin
                                // < moves to x-1. Source is x+1 (East)
                                // Only valid if x < 7
                                if (x_curr != 3'd7) begin
                                    src_idx <= idx_lt_src;
                                    if (grid_mem[idx_lt_src] != CELL_BLOCK) begin
                                        sum_val <= (sum_val + dp[idx_lt_src]) % MOD;
                                    end
                                end
                            end
                            
                            // Finalize cell value
                            dp[{y_curr, x_curr}] <= sum_val;
                            
                            // Advance index
                            if (x_curr == 3'd0) begin
                                if (y_curr != 3'd0) begin
                                    y_curr <= y_curr - 3'd1;
                                    x_curr <= 3'd7;
                                end
                            end else begin
                                x_curr <= x_curr - 3'd1;
                            end
                            counter <= 2'd0;
                        end
                    endcase
                end

                DONE: begin
                    // Result is at start position: dp[{3'd7, x_init_reg}]
                    result <= dp[{3'd7, x_init_reg}];
                    if (dp[{3'd7, x_init_reg}] == 20'd0) begin
                        begin_repairs <= 1'b1;
                    end else begin
                        begin_repairs <= 1'b0;
                    end
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule