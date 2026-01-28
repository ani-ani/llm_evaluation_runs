module settle_iou(
    input clk,
    input rst_n,
    input start,
    input [3:0] a,
    input [3:0] b,
    input [7:0] c,
    output reg [3:0] p,
    output reg [7:0] result_01,
    output reg [7:0] result_02,
    output reg [7:0] result_03,
    output reg [7:0] result_04,
    output reg [7:0] result_05,
    output reg [7:0] result_06,
    output reg [7:0] result_07,
    output reg [7:0] result_10,
    output reg [7:0] result_12,
    output reg [7:0] result_13,
    output reg [7:0] result_14,
    output reg [7:0] result_15,
    output reg [7:0] result_16,
    output reg [7:0] result_17,
    output reg [7:0] result_20,
    output reg [7:0] result_21,
    output reg [7:0] result_23,
    output reg [7:0] result_24,
    output reg [7:0] result_25,
    output reg [7:0] result_26,
    output reg [7:0] result_27,
    output reg [7:0] result_30,
    output reg [7:0] result_31,
    output reg [7:0] result_32,
    output reg [7:0] result_34,
    output reg [7:0] result_35,
    output reg [7:0] result_36,
    output reg [7:0] result_37,
    output reg [7:0] result_40,
    output reg [7:0] result_41,
    output reg [7:0] result_42,
    output reg [7:0] result_43,
    output reg [7:0] result_45,
    output reg [7:0] result_46,
    output reg [7:0] result_47,
    output reg [7:0] result_50,
    output reg [7:0] result_51,
    output reg [7:0] result_52,
    output reg [7:0] result_53,
    output reg [7:0] result_54,
    output reg [7:0] result_56,
    output reg [7:0] result_57,
    output reg [7:0] result_60,
    output reg [7:0] result_61,
    output reg [7:0] result_62,
    output reg [7:0] result_63,
    output reg [7:0] result_64,
    output reg [7:0] result_65,
    output reg [7:0] result_67,
    output reg [7:0] result_70,
    output reg [7:0] result_71,
    output reg [7:0] result_72,
    output reg [7:0] result_73,
    output reg [7:0] result_74,
    output reg [7:0] result_75,
    output reg [7:0] result_76,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] SETTLE = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;
    
    reg [7:0] D [0:7][0:7];
    integer i, j, k;
    reg [7:0] min_amount;
    reg cycle_found;
    reg [7:0] temp_amount;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            p <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    D[i][j] <= 8'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= LOAD;
                    end
                end
                
                LOAD: begin
                    D[a][b] <= c;
                    state <= SETTLE;
                end
                
                SETTLE: begin
                    cycle_count <= cycle_count + 8'd1;
                    cycle_found <= 1'b0;
                    
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            for (k = 0; k < 8; k = k + 1) begin
                                if (i != j && j != k && k != i) begin
                                    if (D[i][j] > 8'd0 && D[j][k] > 8'd0 && D[k][i] > 8'd0) begin
                                        min_amount <= D[i][j];
                                        if (D[j][k] < min_amount) begin
                                            min_amount <= D[j][k];
                                        end
                                        if (D[k][i] < min_amount) begin
                                            min_amount <= D[k][i];
                                        end
                                        
                                        D[i][j] <= D[i][j] - min_amount;
                                        D[j][k] <= D[j][k] - min_amount;
                                        D[k][i] <= D[k][i] - min_amount;
                                        cycle_found <= 1'b1;
                                    end
                                end
                            end
                        end
                    end
                    
                    if (!cycle_found || cycle_count >= MAX_CYCLES) begin
                        state <= OUTPUT;
                    end
                end
                
                OUTPUT: begin
                    p <= 4'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            if (i != j && D[i][j] > 8'd0) begin
                                p <= p + 4'd1;
                            end
                        end
                    end
                    
                    result_01 <= D[0][1];
                    result_02 <= D[0][2];
                    result_03 <= D[0][3];
                    result_04 <= D[0][4];
                    result_05 <= D[0][5];
                    result_06 <= D[0][6];
                    result_07 <= D[0][7];
                    result_10 <= D[1][0];
                    result_12 <= D[1][2];
                    result_13 <= D[1][3];
                    result_14 <= D[1][4];
                    result_15 <= D[1][5];
                    result_16 <= D[1][6];
                    result_17 <= D[1][7];
                    result_20 <= D[2][0];
                    result_21 <= D[2][1];
                    result_23 <= D[2][3];
                    result_24 <= D[2][4];
                    result_25 <= D[2][5];
                    result_26 <= D[2][6];
                    result_27 <= D[2][7];
                    result_30 <= D[3][0];
                    result_31 <= D[3][1];
                    result_32 <= D[3][2];
                    result_34 <= D[3][4];
                    result_35 <= D[3][5];
                    result_36 <= D[3][6];
                    result_37 <= D[3][7];
                    result_40 <= D[4][0];
                    result_41 <= D[4][1];
                    result_42 <= D[4][2];
                    result_43 <= D[4][3];
                    result_45 <= D[4][5];
                    result_46 <= D[4][6];
                    result_47 <= D[4][7];
                    result_50 <= D[5][0];
                    result_51 <= D[5][1];
                    result_52 <= D[5][2];
                    result_53 <= D[5][3];
                    result_54 <= D[5][4];
                    result_56 <= D[5][6];
                    result_57 <= D[5][7];
                    result_60 <= D[6][0];
                    result_61 <= D[6][1];
                    result_62 <= D[6][2];
                    result_63 <= D[6][3];
                    result_64 <= D[6][4];
                    result_65 <= D[6][5];
                    result_67 <= D[6][7];
                    result_70 <= D[7][0];
                    result_71 <= D[7][1];
                    result_72 <= D[7][2];
                    result_73 <= D[7][3];
                    result_74 <= D[7][4];
                    result_75 <= D[7][5];
                    result_76 <= D[7][6];
                    
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule