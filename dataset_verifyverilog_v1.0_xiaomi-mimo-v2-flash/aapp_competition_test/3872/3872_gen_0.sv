module StringEquivalence(
    input clk,
    input rst_n,
    input start,
    input [7:0] str_a_0, str_a_1, str_a_2, str_a_3,
    input [7:0] str_a_4, str_a_5, str_a_6, str_a_7,
    input [7:0] str_a_8, str_a_9, str_a_10, str_a_11,
    input [7:0] str_a_12, str_a_13, str_a_14, str_a_15,
    input [7:0] str_b_0, str_b_1, str_b_2, str_b_3,
    input [7:0] str_b_4, str_b_5, str_b_6, str_b_7,
    input [7:0] str_b_8, str_b_9, str_b_10, str_b_11,
    input [7:0] str_b_12, str_b_13, str_b_14, str_b_15,
    output reg is_equivalent,
    output reg done
);

    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] STAGE1    = 3'd1; // Compare size 1 blocks
    localparam [2:0] STAGE2    = 3'd2; // Compare size 2 blocks
    localparam [2:0] STAGE3    = 3'd3; // Compare size 4 blocks
    localparam [2:0] STAGE4    = 3'd4; // Compare size 8 blocks
    localparam [2:0] COMPARE   = 3'd5; // Final comparison
    localparam [2:0] FINISH    = 3'd6;

    reg [2:0] state, next_state;
    reg [3:0] i;
    
    // Internal registers for canonical forms of A and B
    reg [7:0] a_reg [0:15];
    reg [7:0] b_reg [0:15];
    
    // Temporary swap results for current stage
    reg [7:0] a_swap_left [0:7];
    reg [7:0] a_swap_right[0:7];
    reg [7:0] b_swap_left [0:7];
    reg [7:0] b_swap_right[0:7];
    
    // Combinational signals for comparison
    wire [7:0] a_temp [0:15];
    wire [7:0] b_temp [0:15];
    wire a_swap_en [0:7];
    wire b_swap_en [0:7];
    
    // Helper for swap logic: if left > right, swap to ensure sorted order
    // Size 1 comparison (individual chars)
    assign a_swap_en[0] = (str_a_0 > str_a_1);
    assign a_swap_en[1] = (str_a_2 > str_a_3);
    assign a_swap_en[2] = (str_a_4 > str_a_5);
    assign a_swap_en[3] = (str_a_6 > str_a_7);
    assign a_swap_en[4] = (str_a_8 > str_a_9);
    assign a_swap_en[5] = (str_a_10 > str_a_11);
    assign a_swap_en[6] = (str_a_12 > str_a_13);
    assign a_swap_en[7] = (str_a_14 > str_a_15);
    
    assign b_swap_en[0] = (str_b_0 > str_b_1);
    assign b_swap_en[1] = (str_b_2 > str_b_3);
    assign b_swap_en[2] = (str_b_4 > str_b_5);
    assign b_swap_en[3] = (str_b_6 > str_b_7);
    assign b_swap_en[4] = (str_b_8 > str_b_9);
    assign b_swap_en[5] = (str_b_10 > str_b_11);
    assign b_swap_en[6] = (str_b_12 > str_b_13);
    assign b_swap_en[7] = (str_b_14 > str_b_15);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            is_equivalent <= 1'b0;
            done <= 1'b0;
            // Initialize registers to 0
            for (i = 0; i < 16; i = i + 1) begin
                a_reg[i] <= 8'd0;
                b_reg[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    is_equivalent <= 1'b0;
                    if (start) begin
                        // Load input data into registers for processing
                        // Stage 1: Initial setup and swap logic for size 1
                        a_reg[0] <= a_swap_en[0] ? str_a_1 : str_a_0;
                        a_reg[1] <= a_swap_en[0] ? str_a_0 : str_a_1;
                        a_reg[2] <= a_swap_en[1] ? str_a_3 : str_a_2;
                        a_reg[3] <= a_swap_en[1] ? str_a_2 : str_a_3;
                        a_reg[4] <= a_swap_en[2] ? str_a_5 : str_a_4;
                        a_reg[5] <= a_swap_en[2] ? str_a_4 : str_a_5;
                        a_reg[6] <= a_swap_en[3] ? str_a_7 : str_a_6;
                        a_reg[7] <= a_swap_en[3] ? str_a_6 : str_a_7;
                        a_reg[8] <= a_swap_en[4] ? str_a_9 : str_a_8;
                        a_reg[9] <= a_swap_en[4] ? str_a_8 : str_a_9;
                        a_reg[10] <= a_swap_en[5] ? str_a_11 : str_a_10;
                        a_reg[11] <= a_swap_en[5] ? str_a_10 : str_a_11;
                        a_reg[12] <= a_swap_en[6] ? str_a_13 : str_a_12;
                        a_reg[13] <= a_swap_en[6] ? str_a_12 : str_a_13;
                        a_reg[14] <= a_swap_en[7] ? str_a_15 : str_a_14;
                        a_reg[15] <= a_swap_en[7] ? str_a_14 : str_a_15;
                        
                        b_reg[0] <= b_swap_en[0] ? str_b_1 : str_b_0;
                        b_reg[1] <= b_swap_en[0] ? str_b_0 : str_b_1;
                        b_reg[2] <= b_swap_en[1] ? str_b_3 : str_b_2;
                        b_reg[3] <= b_swap_en[1] ? str_b_2 : str_b_3;
                        b_reg[4] <= b_swap_en[2] ? str_b_5 : str_b_4;
                        b_reg[5] <= b_swap_en[2] ? str_b_4 : str_b_5;
                        b_reg[6] <= b_swap_en[3] ? str_b_7 : str_b_6;
                        b_reg[7] <= b_swap_en[3] ? str_b_6 : str_b_7;
                        b_reg[8] <= b_swap_en[4] ? str_b_9 : str_b_8;
                        b_reg[9] <= b_swap_en[4] ? str_b_8 : str_b_9;
                        b_reg[10] <= b_swap_en[5] ? str_b_11 : str_b_10;
                        b_reg[11] <= b_swap_en[5] ? str_b_10 : str_b_11;
                        b_reg[12] <= b_swap_en[6] ? str_b_13 : str_b_12;
                        b_reg[13] <= b_swap_en[6] ? str_b_12 : str_b_13;
                        b_reg[14] <= b_swap_en[7] ? str_b_15 : str_b_14;
                        b_reg[15] <= b_swap_en[7] ? str_b_14 : str_b_15;
                    end
                end
                
                STAGE1: begin
                    // Process size 2 blocks
                    // Compare (0,1) with (2,3) lexicographically (word-wise)
                    if ({a_reg[0], a_reg[1]} > {a_reg[2], a_reg[3]}) begin
                        // Swap block 0-1 with 2-3
                        a_reg[0] <= a_reg[2]; a_reg[1] <= a_reg[3];
                        a_reg[2] <= a_reg[0]; a_reg[3] <= a_reg[1];
                    end
                    if ({b_reg[0], b_reg[1]} > {b_reg[2], b_reg[3]}) begin
                        b_reg[0] <= b_reg[2]; b_reg[1] <= b_reg[3];
                        b_reg[2] <= b_reg[0]; b_reg[3] <= b_reg[1];
                    end
                    // Block 4-7
                    if ({a_reg[4], a_reg[5]} > {a_reg[6], a_reg[7]}) begin
                        a_reg[4] <= a_reg[6]; a_reg[5] <= a_reg[7];
                        a_reg[6] <= a_reg[4]; a_reg[7] <= a_reg[5];
                    end
                    if ({b_reg[4], b_reg[5]} > {b_reg[6], b_reg[7]}) begin
                        b_reg[4] <= b_reg[6]; b_reg[5] <= b_reg[7];
                        b_reg[6] <= b_reg[4]; b_reg[7] <= b_reg[5];
                    end
                    // Block 8-11
                    if ({a_reg[8], a_reg[9]} > {a_reg[10], a_reg[11]}) begin
                        a_reg[8] <= a_reg[10]; a_reg[9] <= a_reg[11];
                        a_reg[10] <= a_reg[8]; a_reg[11] <= a_reg[9];
                    end
                    if ({b_reg[8], b_reg[9]} > {b_reg[10], b_reg[11]}) begin
                        b_reg[8] <= b_reg[10]; b_reg[9] <= b_reg[11];
                        b_reg[10] <= b_reg[8]; b_reg[11] <= b_reg[9];
                    end
                    // Block 12-15
                    if ({a_reg[12], a_reg[13]} > {a_reg[14], a_reg[15]}) begin
                        a_reg[12] <= a_reg[14]; a_reg[13] <= a_reg[15];
                        a_reg[14] <= a_reg[12]; a_reg[15] <= a_reg[13];
                    end
                    if ({b_reg[12], b_reg[13]} > {b_reg[14], b_reg[15]}) begin
                        b_reg[12] <= b_reg[14]; b_reg[13] <= b_reg[15];
                        b_reg[14] <= b_reg[12]; b_reg[15] <= b_reg[13];
                    end
                end
                
                STAGE2: begin
                    // Process size 4 blocks
                    // Compare (0-3) with (4-7)
                    if ({a_reg[0], a_reg[1], a_reg[2], a_reg[3]} > {a_reg[4], a_reg[5], a_reg[6], a_reg[7]}) begin
                        swap_block(a_reg, 0, 4, 4);
                    end
                    if ({b_reg[0], b_reg[1], b_reg[2], b_reg[3]} > {b_reg[4], b_reg[5], b_reg[6], b_reg[7]}) begin
                        swap_block(b_reg, 0, 4, 4);
                    end
                    // Compare (8-11) with (12-15)
                    if ({a_reg[8], a_reg[9], a_reg[10], a_reg[11]} > {a_reg[12], a_reg[13], a_reg[14], a_reg[15]}) begin
                        swap_block(a_reg, 8, 12, 4);
                    end
                    if ({b_reg[8], b_reg[9], b_reg[10], b_reg[11]} > {b_reg[12], b_reg[13], b_reg[14], b_reg[15]}) begin
                        swap_block(b_reg, 8, 12, 4);
                    end
                end
                
                STAGE3: begin
                    // Process size 8 blocks
                    // Compare (0-7) with (8-15)
                    // We need to compare 8 bytes, split into chunks for Verilog
                    // Compare chunk 1 (bytes 0-3)
                    if ({a_reg[0], a_reg[1], a_reg[2], a_reg[3]} > {a_reg[8], a_reg[9], a_reg[10], a_reg[11]}) begin
                        swap_block(a_reg, 0, 8, 8);
                    end else if ({a_reg[0], a_reg[1], a_reg[2], a_reg[3]} == {a_reg[8], a_reg[9], a_reg[10], a_reg[11]}) begin
                        // Chunk 1 equal, compare chunk 2 (bytes 4-7)
                        if ({a_reg[4], a_reg[5], a_reg[6], a_reg[7]} > {a_reg[12], a_reg[13], a_reg[14], a_reg[15]}) begin
                            swap_block(a_reg, 0, 8, 8);
                        end
                    end
                    
                    if ({b_reg[0], b_reg[1], b_reg[2], b_reg[3]} > {b_reg[8], b_reg[9], b_reg[10], b_reg[11]}) begin
                        swap_block(b_reg, 0, 8, 8);
                    end else if ({b_reg[0], b_reg[1], b_reg[2], b_reg[3]} == {b_reg[8], b_reg[9], b_reg[10], b_reg[11]}) begin
                        if ({b_reg[4], b_reg[5], b_reg[6], b_reg[7]} > {b_reg[12], b_reg[13], b_reg[14], b_reg[15]}) begin
                            swap_block(b_reg, 0, 8, 8);
                        end
                    end
                end
                
                STAGE4: begin
                    // Verification pass (optional, but ensures final sorted form)
                    // Just a placeholder stage to keep pipeline balanced
                    // Logic is essentially complete after STAGE3
                end
                
                COMPARE: begin
                    // Compare canonical forms byte by byte
                    is_equivalent <= 1'b1; // Assume equal until proven otherwise
                    if (a_reg[0] != b_reg[0]) is_equivalent <= 1'b0;
                    if (a_reg[1] != b_reg[1]) is_equivalent <= 1'b0;
                    if (a_reg[2] != b_reg[2]) is_equivalent <= 1'b0;
                    if (a_reg[3] != b_reg[3]) is_equivalent <= 1'b0;
                    if (a_reg[4] != b_reg[4]) is_equivalent <= 1'b0;
                    if (a_reg[5] != b_reg[5]) is_equivalent <= 1'b0;
                    if (a_reg[6] != b_reg[6]) is_equivalent <= 1'b0;
                    if (a_reg[7] != b_reg[7]) is_equivalent <= 1'b0;
                    if (a_reg[8] != b_reg[8]) is_equivalent <= 1'b0;
                    if (a_reg[9] != b_reg[9]) is_equivalent <= 1'b0;
                    if (a_reg[10] != b_reg[10]) is_equivalent <= 1'b0;
                    if (a_reg[11] != b_reg[11]) is_equivalent <= 1'b0;
                    if (a_reg[12] != b_reg[12]) is_equivalent <= 1'b0;
                    if (a_reg[13] != b_reg[13]) is_equivalent <= 1'b0;
                    if (a_reg[14] != b_reg[14]) is_equivalent <= 1'b0;
                    if (a_reg[15] != b_reg[15]) is_equivalent <= 1'b0;
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Task for swapping blocks within the array
    task swap_block;
        inout [7:0] arr [0:15];
        input [3:0] start_idx;
        input [3:0] other_idx;
        input [3:0] len;
        integer j;
        begin
            for (j = 0; j < len; j = j + 1) begin
                arr[start_idx + j] <= arr[other_idx + j];
                arr[other_idx + j] <= arr[start_idx + j];
            end
        end
    endtask

    // Next state logic
    always @(*) begin
        case (state)
            IDLE:      next_state = start ? STAGE1 : IDLE;
            STAGE1:    next_state = STAGE2;
            STAGE2:    next_state = STAGE3;
            STAGE3:    next_state = STAGE4;
            STAGE4:    next_state = COMPARE;
            COMPARE:   next_state = FINISH;
            FINISH:    next_state = IDLE;
            default:   next_state = IDLE;
        endcase
    end

endmodule