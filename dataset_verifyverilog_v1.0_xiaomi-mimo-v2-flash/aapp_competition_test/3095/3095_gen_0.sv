module MongeMaxSubmatrix (
    input clk,
    input rst_n,
    input start,
    input [511:0] matrix_flat,
    input [2:0] rows,
    input [2:0] cols,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] LATCH       = 3'd1;
    localparam [2:0] CHECK_VALID = 3'd2;
    localparam [2:0] CALC_AREA   = 3'd3;
    localparam [2:0] UPDATE_MAX  = 3'd4;
    localparam [2:0] NEXT_CONFIG = 3'd5;
    localparam [2:0] FINISH      = 3'd6;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg signed [7:0] matrix_reg [63:0];  // Unpacked array for easier access
    reg [2:0] latch_rows;
    reg [2:0] latch_cols;
    reg [2:0] r1, r2, c1, c2;  // Submatrix boundaries
    reg [7:0] current_area;
    reg [7:0] max_area;
    reg is_valid_submatrix;
    reg [2:0] check_r, check_c;  // For checking internal 2x2 blocks
    reg [2:0] i, j;  // Loop counters
    reg start_latched;
    reg [13:0] cycle_count;  // Safety counter
    localparam [13:0] MAX_CYCLES = 14'd5000;

    // Wire declarations for matrix elements
    wire signed [7:0] elem [63:0];
    assign elem[0] = matrix_flat[7:0];
    assign elem[1] = matrix_flat[15:8];
    assign elem[2] = matrix_flat[23:16];
    assign elem[3] = matrix_flat[31:24];
    assign elem[4] = matrix_flat[39:32];
    assign elem[5] = matrix_flat[47:40];
    assign elem[6] = matrix_flat[55:48];
    assign elem[7] = matrix_flat[63:56];
    assign elem[8] = matrix_flat[71:64];
    assign elem[9] = matrix_flat[79:72];
    assign elem[10] = matrix_flat[87:80];
    assign elem[11] = matrix_flat[95:88];
    assign elem[12] = matrix_flat[103:96];
    assign elem[13] = matrix_flat[111:104];
    assign elem[14] = matrix_flat[119:112];
    assign elem[15] = matrix_flat[127:120];
    assign elem[16] = matrix_flat[135:128];
    assign elem[17] = matrix_flat[143:136];
    assign elem[18] = matrix_flat[151:144];
    assign elem[19] = matrix_flat[159:152];
    assign elem[20] = matrix_flat[167:160];
    assign elem[21] = matrix_flat[175:168];
    assign elem[22] = matrix_flat[183:176];
    assign elem[23] = matrix_flat[191:184];
    assign elem[24] = matrix_flat[199:192];
    assign elem[25] = matrix_flat[207:200];
    assign elem[26] = matrix_flat[215:208];
    assign elem[27] = matrix_flat[223:216];
    assign elem[28] = matrix_flat[231:224];
    assign elem[29] = matrix_flat[239:232];
    assign elem[30] = matrix_flat[247:240];
    assign elem[31] = matrix_flat[255:248];
    assign elem[32] = matrix_flat[263:256];
    assign elem[33] = matrix_flat[271:264];
    assign elem[34] = matrix_flat[279:272];
    assign elem[35] = matrix_flat[287:280];
    assign elem[36] = matrix_flat[295:288];
    assign elem[37] = matrix_flat[303:296];
    assign elem[38] = matrix_flat[311:304];
    assign elem[39] = matrix_flat[319:312];
    assign elem[40] = matrix_flat[327:320];
    assign elem[41] = matrix_flat[335:328];
    assign elem[42] = matrix_flat[343:336];
    assign elem[43] = matrix_flat[351:344];
    assign elem[44] = matrix_flat[359:352];
    assign elem[45] = matrix_flat[367:360];
    assign elem[46] = matrix_flat[375:368];
    assign elem[47] = matrix_flat[383:376];
    assign elem[48] = matrix_flat[391:384];
    assign elem[49] = matrix_flat[399:392];
    assign elem[50] = matrix_flat[407:400];
    assign elem[51] = matrix_flat[415:408];
    assign elem[52] = matrix_flat[423:416];
    assign elem[53] = matrix_flat[431:424];
    assign elem[54] = matrix_flat[439:432];
    assign elem[55] = matrix_flat[447:440];
    assign elem[56] = matrix_flat[455:448];
    assign elem[57] = matrix_flat[463:456];
    assign elem[58] = matrix_flat[471:464];
    assign elem[59] = matrix_flat[479:472];
    assign elem[60] = matrix_flat[487:480];
    assign elem[61] = matrix_flat[495:488];
    assign elem[62] = matrix_flat[503:496];
    assign elem[63] = matrix_flat[511:504];

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = (start_latched) ? LATCH : IDLE;
            LATCH: next_state = CHECK_VALID;
            CHECK_VALID: begin
                if (!is_valid_submatrix) begin
                    next_state = NEXT_CONFIG;
                end else begin
                    next_state = CALC_AREA;
                end
            end
            CALC_AREA: next_state = UPDATE_MAX;
            UPDATE_MAX: next_state = NEXT_CONFIG;
            NEXT_CONFIG: begin
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end else if (r1 >= latch_rows) begin
                    next_state = FINISH;
                end else if (r2 >= latch_rows) begin
                    next_state = FINISH;
                end else if (c1 >= latch_cols) begin
                    next_state = FINISH;
                end else if (c2 >= latch_cols) begin
                    next_state = FINISH;
                end else begin
                    next_state = CHECK_VALID;
                end
            end
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // State transition and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            start_latched <= 1'b0;
            cycle_count <= 14'd0;
            r1 <= 3'd0;
            r2 <= 3'd0;
            c1 <= 3'd0;
            c2 <= 3'd0;
            latch_rows <= 3'd0;
            latch_cols <= 3'd0;
            max_area <= 8'd0;
            is_valid_submatrix <= 1'b0;
            check_r <= 3'd0;
            check_c <= 3'd0;
            current_area <= 8'd0;
        end else begin
            state <= next_state;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    cycle_count <= 14'd0;
                    if (start) begin
                        start_latched <= 1'b1;
                    end
                end
                
                LATCH: begin
                    start_latched <= 1'b0;
                    r1 <= 3'd0;
                    r2 <= 3'd1;
                    c1 <= 3'd0;
                    c2 <= 3'd1;
                    latch_rows <= rows;
                    latch_cols <= cols;
                    max_area <= 8'd0;
                    // Unpack matrix
                    matrix_reg[0] <= elem[0];
                    matrix_reg[1] <= elem[1];
                    matrix_reg[2] <= elem[2];
                    matrix_reg[3] <= elem[3];
                    matrix_reg[4] <= elem[4];
                    matrix_reg[5] <= elem[5];
                    matrix_reg[6] <= elem[6];
                    matrix_reg[7] <= elem[7];
                    matrix_reg[8] <= elem[8];
                    matrix_reg[9] <= elem[9];
                    matrix_reg[10] <= elem[10];
                    matrix_reg[11] <= elem[11];
                    matrix_reg[12] <= elem[12];
                    matrix_reg[13] <= elem[13];
                    matrix_reg[14] <= elem[14];
                    matrix_reg[15] <= elem[15];
                    matrix_reg[16] <= elem[16];
                    matrix_reg[17] <= elem[17];
                    matrix_reg[18] <= elem[18];
                    matrix_reg[19] <= elem[19];
                    matrix_reg[20] <= elem[20];
                    matrix_reg[21] <= elem[21];
                    matrix_reg[22] <= elem[22];
                    matrix_reg[23] <= elem[23];
                    matrix_reg[24] <= elem[24];
                    matrix_reg[25] <= elem[25];
                    matrix_reg[26] <= elem[26];
                    matrix_reg[27] <= elem[27];
                    matrix_reg[28] <= elem[28];
                    matrix_reg[29] <= elem[29];
                    matrix_reg[30] <= elem[30];
                    matrix_reg[31] <= elem[31];
                    matrix_reg[32] <= elem[32];
                    matrix_reg[33] <= elem[33];
                    matrix_reg[34] <= elem[34];
                    matrix_reg[35] <= elem[35];
                    matrix_reg[36] <= elem[36];
                    matrix_reg[37] <= elem[37];
                    matrix_reg[38] <= elem[38];
                    matrix_reg[39] <= elem[39];
                    matrix_reg[40] <= elem[40];
                    matrix_reg[41] <= elem[41];
                    matrix_reg[42] <= elem[42];
                    matrix_reg[43] <= elem[43];
                    matrix_reg[44] <= elem[44];
                    matrix_reg[45] <= elem[45];
                    matrix_reg[46] <= elem[46];
                    matrix_reg[47] <= elem[47];
                    matrix_reg[48] <= elem[48];
                    matrix_reg[49] <= elem[49];
                    matrix_reg[50] <= elem[50];
                    matrix_reg[51] <= elem[51];
                    matrix_reg[52] <= elem[52];
                    matrix_reg[53] <= elem[53];
                    matrix_reg[54] <= elem[54];
                    matrix_reg[55] <= elem[55];
                    matrix_reg[56] <= elem[56];
                    matrix_reg[57] <= elem[57];
                    matrix_reg[58] <= elem[58];
                    matrix_reg[59] <= elem[59];
                    matrix_reg[60] <= elem[60];
                    matrix_reg[61] <= elem[61];
                    matrix_reg[62] <= elem[62];
                    matrix_reg[63] <= elem[63];
                end
                
                CHECK_VALID: begin
                    // Check Monge property for internal 2x2 blocks
                    // Initialize check counters
                    if (r1 < r2 && c1 < c2) begin
                        check_r <= r1;
                        check_c <= c1;
                        is_valid_submatrix <= 1'b1;
                    end else begin
                        is_valid_submatrix <= 1'b0;
                    end
                end
                
                CALC_AREA: begin
                    // Update check_r and check_c in previous state
                    // Verify Monge property for current 2x2 block
                    if (check_r < r2 && check_c < c2) begin
                        if (matrix_reg[check_r*8 + check_c] + matrix_reg[(check_r+1)*8 + check_c+1] > 
                            matrix_reg[check_r*8 + check_c+1] + matrix_reg[(check_r+1)*8 + check_c]) begin
                            is_valid_submatrix <= 1'b0;
                        end
                    end
                end
                
                UPDATE_MAX: begin
                    // Check all internal blocks (iterate)
                    if (check_r < r2 && check_c < c2) begin
                        if (check_c < c2 - 1) begin
                            check_c <= check_c + 3'd1;
                        end else begin
                            check_c <= c1;
                            check_r <= check_r + 3'd1;
                        end
                        // If not finished checking, go back to check
                    end
                    
                    if (is_valid_submatrix) begin
                        // Calculate area
                        current_area <= (r2 - r1 + 3'd1) * (c2 - c1 + 3'd1);
                    end
                end
                
                NEXT_CONFIG: begin
                    cycle_count <= cycle_count + 14'd1;
                    
                    // Update max area
                    if (is_valid_submatrix && current_area > max_area) begin
                        max_area <= current_area;
                    end
                    
                    // Find next submatrix configuration
                    // Increment c2 first
                    if (c2 < latch_cols - 3'd1) begin
                        c2 <= c2 + 3'd1;
                    end else begin
                        c2 <= c1 + 3'd1;
                        if (c1 < latch_cols - 3'd2) begin
                            c1 <= c1 + 3'd1;
                        end else begin
                            c1 <= 3'd0;
                            if (r2 < latch_rows - 3'd1) begin
                                r2 <= r2 + 3'd1;
                            end else begin
                                r2 <= r1 + 3'd1;
                                if (r1 < latch_rows - 3'd2) begin
                                    r1 <= r1 + 3'd1;
                                end else begin
                                    r1 <= 3'd7; // Force to end
                                end
                            end
                        end
                    end
                end
                
                FINISH: begin
                    result <= max_area;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule