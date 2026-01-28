module string_equivalence(
    input clk,
    input rst_n,
    input start,
    input [7:0] str_a_0, input [7:0] str_a_1, input [7:0] str_a_2, input [7:0] str_a_3,
    input [7:0] str_a_4, input [7:0] str_a_5, input [7:0] str_a_6, input [7:0] str_a_7,
    input [7:0] str_a_8, input [7:0] str_a_9, input [7:0] str_a_10, input [7:0] str_a_11,
    input [7:0] str_a_12, input [7:0] str_a_13, input [7:0] str_a_14, input [7:0] str_a_15,
    input [7:0] str_b_0, input [7:0] str_b_1, input [7:0] str_b_2, input [7:0] str_b_3,
    input [7:0] str_b_4, input [7:0] str_b_5, input [7:0] str_b_6, input [7:0] str_b_7,
    input [7:0] str_b_8, input [7:0] str_b_9, input [7:0] str_b_10, input [7:0] str_b_11,
    input [7:0] str_b_12, input [7:0] str_b_13, input [7:0] str_b_14, input [7:0] str_b_15,
    output reg is_equivalent,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] STAGE1 = 3'd1;
    localparam [2:0] STAGE2 = 3'd2;
    localparam [2:0] STAGE3 = 3'd3;
    localparam [2:0] STAGE4 = 3'd4;
    localparam [2:0] COMPARE = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd50;

    // Registers for canonical forms
    reg [7:0] canon_a [0:15];
    reg [7:0] canon_b [0:15];

    // Initialize canonical forms
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            is_equivalent <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            for (i = 0; i < 16; i = i + 1) begin
                canon_a[i] <= 8'd0;
                canon_b[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Initialize canonical forms with input strings
                        canon_a[0] <= str_a_0; canon_a[1] <= str_a_1; canon_a[2] <= str_a_2; canon_a[3] <= str_a_3;
                        canon_a[4] <= str_a_4; canon_a[5] <= str_a_5; canon_a[6] <= str_a_6; canon_a[7] <= str_a_7;
                        canon_a[8] <= str_a_8; canon_a[9] <= str_a_9; canon_a[10] <= str_a_10; canon_a[11] <= str_a_11;
                        canon_a[12] <= str_a_12; canon_a[13] <= str_a_13; canon_a[14] <= str_a_14; canon_a[15] <= str_a_15;
                        canon_b[0] <= str_b_0; canon_b[1] <= str_b_1; canon_b[2] <= str_b_2; canon_b[3] <= str_b_3;
                        canon_b[4] <= str_b_4; canon_b[5] <= str_b_5; canon_b[6] <= str_b_6; canon_b[7] <= str_b_7;
                        canon_b[8] <= str_b_8; canon_b[9] <= str_b_9; canon_b[10] <= str_b_10; canon_b[11] <= str_b_11;
                        canon_b[12] <= str_b_12; canon_b[13] <= str_b_13; canon_b[14] <= str_b_14; canon_b[15] <= str_b_15;
                        state <= STAGE1;
                    end
                end

                STAGE1: begin
                    // Stage 1: Compare and swap adjacent pairs (size 1 -> 2)
                    for (i = 0; i < 16; i = i + 2) begin
                        if (canon_a[i] > canon_a[i+1]) begin
                            canon_a[i] <= canon_a[i+1];
                            canon_a[i+1] <= canon_a[i];
                        end
                        if (canon_b[i] > canon_b[i+1]) begin
                            canon_b[i] <= canon_b[i+1];
                            canon_b[i+1] <= canon_b[i];
                        end
                    end
                    state <= STAGE2;
                end

                STAGE2: begin
                    // Stage 2: Compare and swap pairs of pairs (size 2 -> 4)
                    for (i = 0; i < 16; i = i + 4) begin
                        // Compare first half of each pair
                        if (canon_a[i] > canon_a[i+2]) begin
                            canon_a[i] <= canon_a[i+2];
                            canon_a[i+2] <= canon_a[i];
                        end
                        if (canon_a[i+1] > canon_a[i+3]) begin
                            canon_a[i+1] <= canon_a[i+3];
                            canon_a[i+3] <= canon_a[i+1];
                        end
                        if (canon_b[i] > canon_b[i+2]) begin
                            canon_b[i] <= canon_b[i+2];
                            canon_b[i+2] <= canon_b[i];
                        end
                        if (canon_b[i+1] > canon_b[i+3]) begin
                            canon_b[i+1] <= canon_b[i+3];
                            canon_b[i+3] <= canon_b[i+1];
                        end
                    end
                    state <= STAGE3;
                end

                STAGE3: begin
                    // Stage 3: Compare and swap pairs of 4-element blocks (size 4 -> 8)
                    for (i = 0; i < 16; i = i + 8) begin
                        // Compare first half of each 4-element block
                        if (canon_a[i] > canon_a[i+4]) begin
                            canon_a[i] <= canon_a[i+4];
                            canon_a[i+4] <= canon_a[i];
                        end
                        if (canon_a[i+1] > canon_a[i+5]) begin
                            canon_a[i+1] <= canon_a[i+5];
                            canon_a[i+5] <= canon_a[i+1];
                        end
                        if (canon_a[i+2] > canon_a[i+6]) begin
                            canon_a[i+2] <= canon_a[i+6];
                            canon_a[i+6] <= canon_a[i+2];
                        end
                        if (canon_a[i+3] > canon_a[i+7]) begin
                            canon_a[i+3] <= canon_a[i+7];
                            canon_a[i+7] <= canon_a[i+3];
                        end
                        if (canon_b[i] > canon_b[i+4]) begin
                            canon_b[i] <= canon_b[i+4];
                            canon_b[i+4] <= canon_b[i];
                        end
                        if (canon_b[i+1] > canon_b[i+5]) begin
                            canon_b[i+1] <= canon_b[i+5];
                            canon_b[i+5] <= canon_b[i+1];
                        end
                        if (canon_b[i+2] > canon_b[i+6]) begin
                            canon_b[i+2] <= canon_b[i+6];
                            canon_b[i+6] <= canon_b[i+2];
                        end
                        if (canon_b[i+3] > canon_b[i+7]) begin
                            canon_b[i+3] <= canon_b[i+7];
                            canon_b[i+7] <= canon_b[i+3];
                        end
                    end
                    state <= STAGE4;
                end

                STAGE4: begin
                    // Stage 4: Compare and swap 8-element blocks (size 8 -> 16)
                    for (i = 0; i < 8; i = i + 1) begin
                        if (canon_a[i] > canon_a[i+8]) begin
                            canon_a[i] <= canon_a[i+8];
                            canon_a[i+8] <= canon_a[i];
                        end
                        if (canon_b[i] > canon_b[i+8]) begin
                            canon_b[i] <= canon_b[i+8];
                            canon_b[i+8] <= canon_b[i];
                        end
                    end
                    state <= COMPARE;
                end

                COMPARE: begin
                    // Compare canonical forms
                    reg [1:0] comparison_result;
                    comparison_result = 2'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (canon_a[i] != canon_b[i]) begin
                            comparison_result = 2'd1;
                        end
                    end
                    if (comparison_result == 2'd0) begin
                        is_equivalent <= 1'b1;
                    end else begin
                        is_equivalent <= 1'b0;
                    end
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule