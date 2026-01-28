module BubbleSortNetwork (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] in_name [0:7],
    input wire [7:0] in_marks [0:7],
    input wire [7:0] valid_in [0:7],
    output reg [3:0] out_name [0:7],
    output reg [7:0] out_marks [0:7],
    output reg [7:0] out_valid [0:7],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] LOAD     = 3'd1;
    localparam [2:0] STAGE_1  = 3'd2;
    localparam [2:0] STAGE_2  = 3'd3;
    localparam [2:0] STAGE_3  = 3'd4;
    localparam [2:0] STAGE_4  = 3'd5;
    localparam [2:0] STAGE_5  = 3'd6;
    localparam [2:0] FINISH   = 3'd7;

    reg [2:0] state;
    reg [3:0] stage_counter;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Internal registers for data and valid bits
    reg [3:0] name_reg [0:7];
    reg [7:0] marks_reg [0:7];
    reg [7:0] valid_reg [0:7];

    // Stage registers for comparator network (stages 0-13)
    reg [3:0] stage_name [0:13];
    reg [7:0] stage_marks [0:13];
    reg [7:0] stage_valid [0:13];

    integer i;
    integer j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            stage_counter <= 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
                out_name[i] <= 4'd0;
                out_marks[i] <= 8'd0;
                out_valid[i] <= 8'd0;
                name_reg[i] <= 4'd0;
                marks_reg[i] <= 8'd0;
                valid_reg[i] <= 8'd0;
            end
            for (i = 0; i < 14; i = i + 1) begin
                stage_name[i] <= 4'd0;
                stage_marks[i] <= 8'd0;
                stage_valid[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    stage_counter <= 4'd0;
                    if (start) begin
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    // Load input data into registers
                    for (i = 0; i < 8; i = i + 1) begin
                        name_reg[i] <= in_name[i];
                        marks_reg[i] <= in_marks[i];
                        valid_reg[i] <= valid_in[i];
                    end
                    state <= STAGE_1;
                end

                STAGE_1: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Stage 1: Comparators (0-1, 2-3, 4-5, 6-7)
                    // Compare 0,1
                    if (marks_reg[0] > marks_reg[1]) begin
                        stage_name[0] <= name_reg[1];
                        stage_marks[0] <= marks_reg[1];
                        stage_valid[0] <= valid_reg[1];
                        stage_name[1] <= name_reg[0];
                        stage_marks[1] <= marks_reg[0];
                        stage_valid[1] <= valid_reg[0];
                    end else begin
                        stage_name[0] <= name_reg[0];
                        stage_marks[0] <= marks_reg[0];
                        stage_valid[0] <= valid_reg[0];
                        stage_name[1] <= name_reg[1];
                        stage_marks[1] <= marks_reg[1];
                        stage_valid[1] <= valid_reg[1];
                    end
                    // Compare 2,3
                    if (marks_reg[2] > marks_reg[3]) begin
                        stage_name[2] <= name_reg[3];
                        stage_marks[2] <= marks_reg[3];
                        stage_valid[2] <= valid_reg[3];
                        stage_name[3] <= name_reg[2];
                        stage_marks[3] <= marks_reg[2];
                        stage_valid[3] <= valid_reg[2];
                    end else begin
                        stage_name[2] <= name_reg[2];
                        stage_marks[2] <= marks_reg[2];
                        stage_valid[2] <= valid_reg[2];
                        stage_name[3] <= name_reg[3];
                        stage_marks[3] <= marks_reg[3];
                        stage_valid[3] <= valid_reg[3];
                    end
                    // Compare 4,5
                    if (marks_reg[4] > marks_reg[5]) begin
                        stage_name[4] <= name_reg[5];
                        stage_marks[4] <= marks_reg[5];
                        stage_valid[4] <= valid_reg[5];
                        stage_name[5] <= name_reg[4];
                        stage_marks[5] <= marks_reg[4];
                        stage_valid[5] <= valid_reg[4];
                    end else begin
                        stage_name[4] <= name_reg[4];
                        stage_marks[4] <= marks_reg[4];
                        stage_valid[4] <= valid_reg[4];
                        stage_name[5] <= name_reg[5];
                        stage_marks[5] <= marks_reg[5];
                        stage_valid[5] <= valid_reg[5];
                    end
                    // Compare 6,7
                    if (marks_reg[6] > marks_reg[7]) begin
                        stage_name[6] <= name_reg[7];
                        stage_marks[6] <= marks_reg[7];
                        stage_valid[6] <= valid_reg[7];
                        stage_name[7] <= name_reg[6];
                        stage_marks[7] <= marks_reg[6];
                        stage_valid[7] <= valid_reg[6];
                    end else begin
                        stage_name[6] <= name_reg[6];
                        stage_marks[6] <= marks_reg[6];
                        stage_valid[6] <= valid_reg[6];
                        stage_name[7] <= name_reg[7];
                        stage_marks[7] <= marks_reg[7];
                        stage_valid[7] <= valid_reg[7];
                    end
                    state <= STAGE_2;
                end

                STAGE_2: begin
                    // Stage 2: Comparators (1-2, 3-4, 5-6)
                    // Compare 1,2
                    if (stage_marks[1] > stage_marks[2]) begin
                        stage_name[8] <= stage_name[2];
                        stage_marks[8] <= stage_marks[2];
                        stage_valid[8] <= stage_valid[2];
                        stage_name[9] <= stage_name[1];
                        stage_marks[9] <= stage_marks[1];
                        stage_valid[9] <= stage_valid[1];
                    end else begin
                        stage_name[8] <= stage_name[1];
                        stage_marks[8] <= stage_marks[1];
                        stage_valid[8] <= stage_valid[1];
                        stage_name[9] <= stage_name[2];
                        stage_marks[9] <= stage_marks[2];
                        stage_valid[9] <= stage_valid[2];
                    end
                    // Compare 3,4
                    if (stage_marks[3] > stage_marks[4]) begin
                        stage_name[10] <= stage_name[4];
                        stage_marks[10] <= stage_marks[4];
                        stage_valid[10] <= stage_valid[4];
                        stage_name[11] <= stage_name[3];
                        stage_marks[11] <= stage_marks[3];
                        stage_valid[11] <= stage_valid[3];
                    end else begin
                        stage_name[10] <= stage_name[3];
                        stage_marks[10] <= stage_marks[3];
                        stage_valid[10] <= stage_valid[3];
                        stage_name[11] <= stage_name[4];
                        stage_marks[11] <= stage_marks[4];
                        stage_valid[11] <= stage_valid[4];
                    end
                    // Compare 5,6
                    if (stage_marks[5] > stage_marks[6]) begin
                        stage_name[12] <= stage_name[6];
                        stage_marks[12] <= stage_marks[6];
                        stage_valid[12] <= stage_valid[6];
                        stage_name[13] <= stage_name[5];
                        stage_marks[13] <= stage_marks[5];
                        stage_valid[13] <= stage_valid[5];
                    end else begin
                        stage_name[12] <= stage_name[5];
                        stage_marks[12] <= stage_marks[5];
                        stage_valid[12] <= stage_valid[5];
                        stage_name[13] <= stage_name[6];
                        stage_marks[13] <= stage_marks[6];
                        stage_valid[13] <= stage_valid[6];
                    end
                    state <= STAGE_3;
                end

                STAGE_3: begin
                    // Stage 3: Comparators (0-1, 2-3, 4-5, 6-7)
                    // Use name_reg[0-7] as temp storage for next stages
                    // Compare 0,1
                    if (stage_marks[0] > stage_marks[8]) begin
                        name_reg[0] <= stage_name[8];
                        marks_reg[0] <= stage_marks[8];
                        valid_reg[0] <= stage_valid[8];
                        name_reg[1] <= stage_name[0];
                        marks_reg[1] <= stage_marks[0];
                        valid_reg[1] <= stage_valid[0];
                    end else begin
                        name_reg[0] <= stage_name[0];
                        marks_reg[0] <= stage_marks[0];
                        valid_reg[0] <= stage_valid[0];
                        name_reg[1] <= stage_name[8];
                        marks_reg[1] <= stage_marks[8];
                        valid_reg[1] <= stage_valid[8];
                    end
                    // Compare 2,3
                    if (stage_marks[9] > stage_marks[10]) begin
                        name_reg[2] <= stage_name[10];
                        marks_reg[2] <= stage_marks[10];
                        valid_reg[2] <= stage_valid[10];
                        name_reg[3] <= stage_name[9];
                        marks_reg[3] <= stage_marks[9];
                        valid_reg[3] <= stage_valid[9];
                    end else begin
                        name_reg[2] <= stage_name[9];
                        marks_reg[2] <= stage_marks[9];
                        valid_reg[2] <= stage_valid[9];
                        name_reg[3] <= stage_name[10];
                        marks_reg[3] <= stage_marks[10];
                        valid_reg[3] <= stage_valid[10];
                    end
                    // Compare 4,5
                    if (stage_marks[11] > stage_marks[12]) begin
                        name_reg[4] <= stage_name[12];
                        marks_reg[4] <= stage_marks[12];
                        valid_reg[4] <= stage_valid[12];
                        name_reg[5] <= stage_name[11];
                        marks_reg[5] <= stage_marks[11];
                        valid_reg[5] <= stage_valid[11];
                    end else begin
                        name_reg[4] <= stage_name[11];
                        marks_reg[4] <= stage_marks[11];
                        valid_reg[4] <= stage_valid[11];
                        name_reg[5] <= stage_name[12];
                        marks_reg[5] <= stage_marks[12];
                        valid_reg[5] <= stage_valid[12];
                    end
                    // Compare 6,7
                    if (stage_marks[13] > stage_marks[7]) begin
                        name_reg[6] <= stage_name[7];
                        marks_reg[6] <= stage_marks[7];
                        valid_reg[6] <= stage_valid[7];
                        name_reg[7] <= stage_name[13];
                        marks_reg[7] <= stage_marks[13];
                        valid_reg[7] <= stage_valid[13];
                    end else begin
                        name_reg[6] <= stage_name[13];
                        marks_reg[6] <= stage_marks[13];
                        valid_reg[6] <= stage_valid[13];
                        name_reg[7] <= stage_name[7];
                        marks_reg[7] <= stage_marks[7];
                        valid_reg[7] <= stage_valid[7];
                    end
                    state <= STAGE_4;
                end

                STAGE_4: begin
                    // Stage 4: Comparators (1-2, 3-4, 5-6)
                    // Using stage_name as temp storage for cross-stage connections
                    // Compare 1,2
                    if (marks_reg[1] > marks_reg[2]) begin
                        stage_name[0] <= name_reg[2];
                        stage_marks[0] <= marks_reg[2];
                        stage_valid[0] <= valid_reg[2];
                        stage_name[1] <= name_reg[1];
                        stage_marks[1] <= marks_reg[1];
                        stage_valid[1] <= valid_reg[1];
                    end else begin
                        stage_name[0] <= name_reg[1];
                        stage_marks[0] <= marks_reg[1];
                        stage_valid[0] <= valid_reg[1];
                        stage_name[1] <= name_reg[2];
                        stage_marks[1] <= marks_reg[2];
                        stage_valid[1] <= valid_reg[2];
                    end
                    // Compare 3,4
                    if (marks_reg[3] > marks_reg[4]) begin
                        stage_name[2] <= name_reg[4];
                        stage_marks[2] <= marks_reg[4];
                        stage_valid[2] <= valid_reg[4];
                        stage_name[3] <= name_reg[3];
                        stage_marks[3] <= marks_reg[3];
                        stage_valid[3] <= valid_reg[3];
                    end else begin
                        stage_name[2] <= name_reg[3];
                        stage_marks[2] <= marks_reg[3];
                        stage_valid[2] <= valid_reg[3];
                        stage_name[3] <= name_reg[4];
                        stage_marks[3] <= marks_reg[4];
                        stage_valid[3] <= valid_reg[4];
                    end
                    // Compare 5,6
                    if (marks_reg[5] > marks_reg[6]) begin
                        stage_name[4] <= name_reg[6];
                        stage_marks[4] <= marks_reg[6];
                        stage_valid[4] <= valid_reg[6];
                        stage_name[5] <= name_reg[5];
                        stage_marks[5] <= marks_reg[5];
                        stage_valid[5] <= valid_reg[5];
                    end else begin
                        stage_name[4] <= name_reg[5];
                        stage_marks[4] <= marks_reg[5];
                        stage_valid[4] <= valid_reg[5];
                        stage_name[5] <= name_reg[6];
                        stage_marks[5] <= marks_reg[6];
                        stage_valid[5] <= valid_reg[6];
                    end
                    state <= STAGE_5;
                end

                STAGE_5: begin
                    // Stage 5: Comparators (0-1, 2-3, 4-5, 6-7) - Final sort stage
                    // Compare 0,1
                    if (name_reg[0] > stage_name[0]) begin
                        name_reg[0] <= stage_name[0];
                        marks_reg[0] <= stage_marks[0];
                        valid_reg[0] <= stage_valid[0];
                        name_reg[1] <= name_reg[0];
                        marks_reg[1] <= marks_reg[0];
                        valid_reg[1] <= valid_reg[0];
                    end else begin
                        name_reg[0] <= name_reg[0];
                        marks_reg[0] <= marks_reg[0];
                        valid_reg[0] <= valid_reg[0];
                        name_reg[1] <= stage_name[0];
                        marks_reg[1] <= stage_marks[0];
                        valid_reg[1] <= stage_valid[0];
                    end
                    // Compare 2,3
                    if (marks_reg[2] > stage_marks[2]) begin
                        name_reg[2] <= stage_name[2];
                        marks_reg[2] <= stage_marks[2];
                        valid_reg[2] <= stage_valid[2];
                        name_reg[3] <= name_reg[2];
                        marks_reg[3] <= marks_reg[2];
                        valid_reg[3] <= valid_reg[2];
                    end else begin
                        name_reg[2] <= name_reg[2];
                        marks_reg[2] <= marks_reg[2];
                        valid_reg[2] <= valid_reg[2];
                        name_reg[3] <= stage_name[2];
                        marks_reg[3] <= stage_marks[2];
                        valid_reg[3] <= stage_valid[2];
                    end
                    // Compare 4,5
                    if (marks_reg[4] > stage_marks[4]) begin
                        name_reg[4] <= stage_name[4];
                        marks_reg[4] <= stage_marks[4];
                        valid_reg[4] <= stage_valid[4];
                        name_reg[5] <= name_reg[4];
                        marks_reg[5] <= marks_reg[4];
                        valid_reg[5] <= valid_reg[4];
                    end else begin
                        name_reg[4] <= name_reg[4];
                        marks_reg[4] <= marks_reg[4];
                        valid_reg[4] <= valid_reg[4];
                        name_reg[5] <= stage_name[4];
                        marks_reg[5] <= stage_marks[4];
                        valid_reg[5] <= stage_valid[4];
                    end
                    // Compare 6,7
                    if (marks_reg[6] > stage_name[6]) begin
                        name_reg[6] <= stage_name[6];
                        marks_reg[6] <= stage_marks[6];
                        valid_reg[6] <= stage_valid[6];
                        name_reg[7] <= name_reg[6];
                        marks_reg[7] <= marks_reg[6];
                        valid_reg[7] <= valid_reg[6];
                    end else begin
                        name_reg[6] <= name_reg[6];
                        marks_reg[6] <= marks_reg[6];
                        valid_reg[6] <= valid_reg[6];
                        name_reg[7] <= stage_name[6];
                        marks_reg[7] <= stage_marks[6];
                        valid_reg[7] <= stage_valid[6];
                    end
                    // Additional cross-stage comparators (1-2, 3-4, 5-6) to fully sort
                    if (marks_reg[1] > marks_reg[2]) begin
                        // Swap 1 and 2
                        marks_reg[1] <= marks_reg[2];
                        marks_reg[2] <= marks_reg[1];
                        name_reg[1] <= name_reg[2];
                        name_reg[2] <= name_reg[1];
                        valid_reg[1] <= valid_reg[2];
                        valid_reg[2] <= valid_reg[1];
                    end
                    if (marks_reg[3] > marks_reg[4]) begin
                        // Swap 3 and 4
                        marks_reg[3] <= marks_reg[4];
                        marks_reg[4] <= marks_reg[3];
                        name_reg[3] <= name_reg[4];
                        name_reg[4] <= name_reg[3];
                        valid_reg[3] <= valid_reg[4];
                        valid_reg[4] <= valid_reg[3];
                    end
                    if (marks_reg[5] > marks_reg[6]) begin
                        // Swap 5 and 6
                        marks_reg[5] <= marks_reg[6];
                        marks_reg[6] <= marks_reg[5];
                        name_reg[5] <= name_reg[6];
                        name_reg[6] <= name_reg[5];
                        valid_reg[5] <= valid_reg[6];
                        valid_reg[6] <= valid_reg[5];
                    end
                    state <= FINISH;
                end

                FINISH: begin
                    // Copy results to output
                    for (i = 0; i < 8; i = i + 1) begin
                        out_name[i] <= name_reg[i];
                        out_marks[i] <= marks_reg[i];
                        out_valid[i] <= valid_reg[i];
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule