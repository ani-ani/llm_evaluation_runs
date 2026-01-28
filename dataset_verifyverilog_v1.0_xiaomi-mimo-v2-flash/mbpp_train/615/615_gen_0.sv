module matrix_avg (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] matrix_in,
    output reg [15:0] result_col0,
    output reg [15:0] result_col1,
    output reg [15:0] result_col2,
    output reg [15:0] result_col3,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] SUM_COL0  = 4'd1;
    localparam [3:0] SUM_COL1  = 4'd2;
    localparam [3:0] SUM_COL2  = 4'd3;
    localparam [3:0] SUM_COL3  = 4'd4;
    localparam [3:0] COMPUTE0  = 4'd5;
    localparam [3:0] COMPUTE1  = 4'd6;
    localparam [3:0] COMPUTE2  = 4'd7;
    localparam [3:0] COMPUTE3  = 4'd8;
    localparam [3:0] DONE      = 4'd9;

    reg [3:0] state, next_state;
    
    // Internal registers for sums
    reg signed [15:0] sum_col0_reg;
    reg signed [15:0] sum_col1_reg;
    reg signed [15:0] sum_col2_reg;
    reg signed [15:0] sum_col3_reg;
    
    // Cycle counter for timing (max 10 cycles)
    reg [3:0] cycle_cnt;
    localparam [3:0] MAX_CYCLES = 4'd10;

    // Extract 8-bit signed values from packed matrix
    // Packed as: {row3_col3, row3_col2, row3_col1, row3_col0,
    //             row2_col3, row2_col2, row2_col1, row2_col0,
    //             row1_col3, row1_col2, row1_col1, row1_col0,
    //             row0_col3, row0_col2, row0_col1, row0_col0}
    wire signed [7:0] val_0_0 = matrix_in[7:0];      // row0_col0
    wire signed [7:0] val_0_1 = matrix_in[15:8];     // row0_col1
    wire signed [7:0] val_0_2 = matrix_in[23:16];    // row0_col2
    wire signed [7:0] val_0_3 = matrix_in[31:24];    // row0_col3
    wire signed [7:0] val_1_0 = matrix_in[39:32];    // row1_col0
    wire signed [7:0] val_1_1 = matrix_in[47:40];    // row1_col1
    wire signed [7:0] val_1_2 = matrix_in[55:48];    // row1_col2
    wire signed [7:0] val_1_3 = matrix_in[63:56];    // row1_col3
    wire signed [7:0] val_2_0 = matrix_in[71:64];    // row2_col0
    wire signed [7:0] val_2_1 = matrix_in[79:72];    // row2_col1
    wire signed [7:0] val_2_2 = matrix_in[87:80];    // row2_col2
    wire signed [7:0] val_2_3 = matrix_in[95:88];    // row2_col3
    wire signed [7:0] val_3_0 = matrix_in[103:96];   // row3_col0
    wire signed [7:0] val_3_1 = matrix_in[111:104];  // row3_col1
    wire signed [7:0] val_3_2 = matrix_in[119:112];  // row3_col2
    wire signed [7:0] val_3_3 = matrix_in[127:120];  // row3_col3

    // State transition logic
    always @(*) begin
        case (state)
            IDLE:       next_state = start ? SUM_COL0 : IDLE;
            SUM_COL0:   next_state = SUM_COL1;
            SUM_COL1:   next_state = SUM_COL2;
            SUM_COL2:   next_state = SUM_COL3;
            SUM_COL3:   next_state = COMPUTE0;
            COMPUTE0:   next_state = COMPUTE1;
            COMPUTE1:   next_state = COMPUTE2;
            COMPUTE2:   next_state = COMPUTE3;
            COMPUTE3:   next_state = DONE;
            DONE:       next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_col0 <= 16'd0;
            result_col1 <= 16'd0;
            result_col2 <= 16'd0;
            result_col3 <= 16'd0;
            sum_col0_reg <= 16'd0;
            sum_col1_reg <= 16'd0;
            sum_col2_reg <= 16'd0;
            sum_col3_reg <= 16'd0;
            cycle_cnt <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_cnt <= 4'd0;
                end
                
                SUM_COL0: begin
                    sum_col0_reg <= val_0_0 + val_1_0 + val_2_0 + val_3_0;
                    cycle_cnt <= cycle_cnt + 4'd1;
                end
                
                SUM_COL1: begin
                    sum_col1_reg <= val_0_1 + val_1_1 + val_2_1 + val_3_1;
                    cycle_cnt <= cycle_cnt + 4'd1;
                end
                
                SUM_COL2: begin
                    sum_col2_reg <= val_0_2 + val_1_2 + val_2_2 + val_3_2;
                    cycle_cnt <= cycle_cnt + 4'd1;
                end
                
                SUM_COL3: begin
                    sum_col3_reg <= val_0_3 + val_1_3 + val_2_3 + val_3_3;
                    cycle_cnt <= cycle_cnt + 4'd1;
                end
                
                COMPUTE0: begin
                    // average = (sum * 256) / 4 = sum * 64 = sum << 6
                    result_col0 <= sum_col0_reg <<< 6;
                    cycle_cnt <= cycle_cnt + 4'd1;
                end
                
                COMPUTE1: begin
                    result_col1 <= sum_col1_reg <<< 6;
                    cycle_cnt <= cycle_cnt + 4'd1;
                end
                
                COMPUTE2: begin
                    result_col2 <= sum_col2_reg <<< 6;
                    cycle_cnt <= cycle_cnt + 4'd1;
                end
                
                COMPUTE3: begin
                    result_col3 <= sum_col3_reg <<< 6;
                    cycle_cnt <= cycle_cnt + 4'd1;
                end
                
                DONE: begin
                    done <= 1'b1;
                    cycle_cnt <= 4'd0;
                end
            endcase
        end
    end

endmodule