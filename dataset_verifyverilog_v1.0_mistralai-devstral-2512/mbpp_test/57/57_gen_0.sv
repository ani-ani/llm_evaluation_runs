module LargestNumberFromDigits(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] digits [0:7],
    input wire [3:0] len,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] SORTING   = 3'd1;
    localparam [2:0] COMBINING = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd50;

    // Internal registers for sorted digits
    reg [3:0] sorted_digits [0:7];
    reg [3:0] temp_digits [0:7];

    // Sorting network stages
    reg [3:0] stage1 [0:7];
    reg [3:0] stage2 [0:7];
    reg [3:0] stage3 [0:7];
    reg [3:0] stage4 [0:7];
    reg [3:0] stage5 [0:7];
    reg [3:0] stage6 [0:7];

    // Combinational comparator
    function automatic [3:0] max;
        input [3:0] a, b;
        begin
            max = (a > b) ? a : b;
        end
    endfunction

    function automatic [3:0] min;
        input [3:0] a, b;
        begin
            min = (a < b) ? a : b;
        end
    endfunction

    // Bitonic sort stages
    always @(*) begin
        // Stage 1: Compare and swap adjacent pairs
        stage1[0] = max(digits[0], digits[1]);
        stage1[1] = min(digits[0], digits[1]);
        stage1[2] = max(digits[2], digits[3]);
        stage1[3] = min(digits[2], digits[3]);
        stage1[4] = max(digits[4], digits[5]);
        stage1[5] = min(digits[4], digits[5]);
        stage1[6] = max(digits[6], digits[7]);
        stage1[7] = min(digits[6], digits[7]);
    end

    always @(*) begin
        // Stage 2: Compare and swap across pairs
        stage2[0] = max(stage1[0], stage1[2]);
        stage2[1] = min(stage1[0], stage1[2]);
        stage2[2] = max(stage1[1], stage1[3]);
        stage2[3] = min(stage1[1], stage1[3]);
        stage2[4] = max(stage1[4], stage1[6]);
        stage2[5] = min(stage1[4], stage1[6]);
        stage2[6] = max(stage1[5], stage1[7]);
        stage2[7] = min(stage1[5], stage1[7]);
    end

    always @(*) begin
        // Stage 3: Compare and swap within new pairs
        stage3[0] = max(stage2[0], stage2[1]);
        stage3[1] = min(stage2[0], stage2[1]);
        stage3[2] = max(stage2[2], stage2[3]);
        stage3[3] = min(stage2[2], stage2[3]);
        stage3[4] = max(stage2[4], stage2[5]);
        stage3[5] = min(stage2[4], stage2[5]);
        stage3[6] = max(stage2[6], stage2[7]);
        stage3[7] = min(stage2[6], stage2[7]);
    end

    always @(*) begin
        // Stage 4: Compare and swap across larger groups
        stage4[0] = max(stage3[0], stage3[4]);
        stage4[1] = min(stage3[0], stage3[4]);
        stage4[2] = max(stage3[1], stage3[5]);
        stage4[3] = min(stage3[1], stage3[5]);
        stage4[4] = max(stage3[2], stage3[6]);
        stage4[5] = min(stage3[2], stage3[6]);
        stage4[6] = max(stage3[3], stage3[7]);
        stage4[7] = min(stage3[3], stage3[7]);
    end

    always @(*) begin
        // Stage 5: Compare and swap within groups
        stage5[0] = max(stage4[0], stage4[2]);
        stage5[1] = min(stage4[0], stage4[2]);
        stage5[2] = max(stage4[1], stage4[3]);
        stage5[3] = min(stage4[1], stage4[3]);
        stage5[4] = max(stage4[4], stage4[6]);
        stage5[5] = min(stage4[4], stage4[6]);
        stage5[6] = max(stage4[5], stage4[7]);
        stage5[7] = min(stage4[5], stage4[7]);
    end

    always @(*) begin
        // Stage 6: Final comparisons
        stage6[0] = max(stage5[0], stage5[1]);
        stage6[1] = min(stage5[0], stage5[1]);
        stage6[2] = max(stage5[2], stage5[3]);
        stage6[3] = min(stage5[2], stage5[3]);
        stage6[4] = max(stage5[4], stage5[5]);
        stage6[5] = min(stage5[4], stage5[5]);
        stage6[6] = max(stage5[6], stage5[7]);
        stage6[7] = min(stage5[6], stage5[7]);
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize all registers
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                sorted_digits[i] <= 4'd0;
                temp_digits[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= SORTING;
                        // Load input digits
                        for (i = 0; i < 8; i = i + 1) begin
                            temp_digits[i] <= digits[i];
                        end
                    end
                end

                SORTING: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Apply sorting network stages
                    if (cycle_count == 8'd1) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            temp_digits[i] <= stage1[i];
                        end
                    end else if (cycle_count == 8'd2) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            temp_digits[i] <= stage2[i];
                        end
                    end else if (cycle_count == 8'd3) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            temp_digits[i] <= stage3[i];
                        end
                    end else if (cycle_count == 8'd4) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            temp_digits[i] <= stage4[i];
                        end
                    end else if (cycle_count == 8'd5) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            temp_digits[i] <= stage5[i];
                        end
                    end else if (cycle_count == 8'd6) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            temp_digits[i] <= stage6[i];
                        end
                        state <= COMBINING;
                    end
                end

                COMBINING: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Combine digits into result
                    if (cycle_count == 8'd7) begin
                        result <= 32'd0;
                        for (i = 0; i < len; i = i + 1) begin
                            result <= result * 10 + temp_digits[i];
                        end
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule