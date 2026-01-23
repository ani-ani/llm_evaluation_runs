module max_product_seq(
    input clk,
    input rst_n,
    input start,
    input [2:0] arr_len,
    input [31:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
    output reg [31:0] result,
    output reg done
);

    // States
    localparam IDLE = 2'b00;
    localparam COMPUTE = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;
    reg [2:0] i;
    reg [2:0] j;
    reg [2:0] len_reg;
    
    // MPIS array: 8 entries of 32-bit signed
    reg signed [31:0] mpis [0:7];
    
    // Internal registers for computation
    reg signed [31:0] current_prod;
    reg signed [63:0] prod_temp_reg;
    reg signed [31:0] arr_reg [0:7];
    
    // Wires for comparison
    wire signed [31:0] mpis_next;
    wire cmp_greater;
    
    // Combinational logic for next value calculation
    assign mpis_next = prod_temp_reg[31:0];
    assign cmp_greater = (mpis_next > mpis[j]);

    integer k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'sd0;
            i <= 3'd0;
            j <= 3'd0;
            current_prod <= 32'sd0;
            len_reg <= 3'd0;
            init_done <= 1'b0;
            dp_done <= 1'b0;
            dp_phase <= 1'b0;
            prod_temp_reg <= 64'sd0;
            running_max <= 32'sh80000000;
            // Reset mpis array
            for (k = 0; k < 8; k = k + 1) begin
                mpis[k] <= 32'sd0;
                arr_reg[k] <= 32'sd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        // Load array
                        arr_reg[0] <= arr_0;
                        arr_reg[1] <= arr_1;
                        arr_reg[2] <= arr_2;
                        arr_reg[3] <= arr_3;
                        arr_reg[4] <= arr_4;
                        arr_reg[5] <= arr_5;
                        arr_reg[6] <= arr_6;
                        arr_reg[7] <= arr_7;
                        len_reg <= arr_len;
                        // Reset flags
                        init_done <= 1'b0;
                        dp_done <= 1'b0;
                        i <= 3'd0;
                        j <= 3'd0;
                        dp_phase <= 1'b0;
                    end
                end

                COMPUTE: begin
                    // 1. Initialization Phase
                    if (!init_done) begin
                        if (i < 3'd8) begin
                            mpis[i] <= arr_reg[i];
                            i <= i + 1;
                        end else begin
                            init_done <= 1'b1;
                            i <= 3'd0;
                            j <= 3'd0;
                        end
                    end 
                    // 2. DP Phase
                    else if (!dp_done) begin
                        if (j < len_reg) begin
                            if (dp_phase == 0) begin // Calc/Check phase
                                if (j == i) begin
                                    current_prod <= arr_reg[i];
                                    j <= j + 1;
                                end else begin // j > i
                                    if (arr_reg[j-1] > arr_reg[j]) begin
                                        // Break inner loop
                                        j <= len_reg; // Will trigger end condition next cycle
                                    end else begin
                                        prod_temp_reg <= $signed(current_prod) * $signed(arr_reg[j]);
                                        dp_phase <= 1;
                                    end
                                end
                            end else begin // dp_phase == 1 (Update phase)
                                // Update mpis
                                if ($signed(prod_temp_reg[31:0]) > $signed(mpis[j])) begin
                                    mpis[j] <= prod_temp_reg[31:0];
                                end
                                current_prod <= prod_temp_reg[31:0];
                                j <= j + 1;
                                dp_phase <= 0;
                            end
                        end else begin
                            // Next i
                            i <= i + 1;
                            j <= i + 1; // Will be decremented to i in next cycle? No.
                            // If we set j=i+1, next cycle j!=i. 
                            // We need to set current_prod = arr[i+1].
                            // But we need to handle the start of the loop.
                            // Let's set j <= i. Then next cycle j==i.
                            j <= i;
                        end
                    end else begin // i >= len_reg
                        dp_done <= 1'b1;
                        i <= 3'd0;
                        running_max <= mpis[0];
                    end
                    // 3. Result Phase
                    else begin // dp_done is high, find max
                        if (i < len_reg) begin
                            if (mpis[i] > running_max) begin
                                running_max <= mpis[i];
                            end
                            i <= i + 1;
                        end else begin
                            result <= running_max;
                            state <= DONE;
                        end
                    end
                end // end COMPUTE

                DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end
            endcase
        end
    end
endmodule