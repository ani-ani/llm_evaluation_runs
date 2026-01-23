module ranger_strength (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] k,
    input [9:0] x,
    input [9:0] arr_0,
    input [9:0] arr_1,
    input [9:0] arr_2,
    input [9:0] arr_3,
    input [9:0] arr_4,
    input [9:0] arr_5,
    input [9:0] arr_6,
    input [9:0] arr_7,
    output reg [9:0] max_out,
    output reg [9:0] min_out,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] XOR = 3'd3;
    localparam [2:0] CHECK_K = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Registers
    reg [2:0] state;
    reg [3:0] k_count;
    reg [3:0] sort_step;
    reg [2:0] i;
    reg [9:0] arr_reg [0:7];
    reg [9:0] temp_a, temp_b;
    reg [9:0] max_val, min_val;
    reg [9:0] temp_max, temp_min;
    reg [3:0] sort_i;
    reg [3:0] calc_i;
    reg [15:0] cycle_counter;
    localparam [15:0] MAX_CYCLES = 16'd1000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            max_out <= 10'd0;
            min_out <= 10'd0;
            k_count <= 4'd0;
            sort_step <= 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
                arr_reg[i] <= 10'd0;
            end
            cycle_counter <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 16'd0;
                    if (start) begin
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    arr_reg[0] <= arr_0;
                    arr_reg[1] <= arr_1;
                    arr_reg[2] <= arr_2;
                    arr_reg[3] <= arr_3;
                    arr_reg[4] <= arr_4;
                    arr_reg[5] <= arr_5;
                    arr_reg[6] <= arr_6;
                    arr_reg[7] <= arr_7;
                    k_count <= k;
                    sort_step <= 4'd0;
                    state <= SORT;
                end

                SORT: begin
                    cycle_counter <= cycle_counter + 16'd1;
                    
                    if (cycle_counter >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        // Perform one step of odd-even transposition sort
                        // Even step
                        if (sort_step[0] == 1'b0) begin
                            // Compare (0,1)
                            if (n > 4'd1 && arr_reg[0] > arr_reg[1]) begin
                                temp_a <= arr_reg[0];
                                temp_b <= arr_reg[1];
                                arr_reg[0] <= temp_b;
                                arr_reg[1] <= temp_a;
                            end
                            // Compare (2,3)
                            if (n > 4'd3 && arr_reg[2] > arr_reg[3]) begin
                                temp_a <= arr_reg[2];
                                temp_b <= arr_reg[3];
                                arr_reg[2] <= temp_b;
                                arr_reg[3] <= temp_a;
                            end
                            // Compare (4,5)
                            if (n > 4'd5 && arr_reg[4] > arr_reg[5]) begin
                                temp_a <= arr_reg[4];
                                temp_b <= arr_reg[5];
                                arr_reg[4] <= temp_b;
                                arr_reg[5] <= temp_a;
                            end
                            // Compare (6,7)
                            if (n > 4'd7 && arr_reg[6] > arr_reg[7]) begin
                                temp_a <= arr_reg[6];
                                temp_b <= arr_reg[7];
                                arr_reg[6] <= temp_b;
                                arr_reg[7] <= temp_a;
                            end
                        end
                        // Odd step
                        else begin
                            // Compare (1,2)
                            if (n > 4'd2 && arr_reg[1] > arr_reg[2]) begin
                                temp_a <= arr_reg[1];
                                temp_b <= arr_reg[2];
                                arr_reg[1] <= temp_b;
                                arr_reg[2] <= temp_a;
                            end
                            // Compare (3,4)
                            if (n > 4'd4 && arr_reg[3] > arr_reg[4]) begin
                                temp_a <= arr_reg[3];
                                temp_b <= arr_reg[4];
                                arr_reg[3] <= temp_b;
                                arr_reg[4] <= temp_a;
                            end
                            // Compare (5,6)
                            if (n > 4'd6 && arr_reg[5] > arr_reg[6]) begin
                                temp_a <= arr_reg[5];
                                temp_b <= arr_reg[6];
                                arr_reg[5] <= temp_b;
                                arr_reg[6] <= temp_a;
                            end
                        end
                        
                        sort_step <= sort_step + 4'd1;
                        
                        if (sort_step == 4'd15) begin // 8 even + 8 odd steps = fully sorted
                            sort_step <= 4'd0;
                            state <= XOR;
                        end
                    end
                end

                XOR: begin
                    // XOR even indices < n
                    if (n > 4'd0) arr_reg[0] <= arr_reg[0] ^ x;
                    if (n > 4'd2) arr_reg[2] <= arr_reg[2] ^ x;
                    if (n > 4'd4) arr_reg[4] <= arr_reg[4] ^ x;
                    if (n > 4'd6) arr_reg[6] <= arr_reg[6] ^ x;
                    state <= CHECK_K;
                end

                CHECK_K: begin
                    if (k_count > 4'd0) begin
                        k_count <= k_count - 4'd1;
                        sort_step <= 4'd0;
                        state <= SORT;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    // Calculate min and max
                    if (n > 4'd0) begin
                        max_val <= arr_reg[0];
                        min_val <= arr_reg[0];
                        calc_i <= 4'd1;
                    end else begin
                        max_val <= 10'd0;
                        min_val <= 10'd0;
                        calc_i <= 4'd0;
                    end
                    
                    if (calc_i < n) begin
                        if (arr_reg[calc_i] > max_val) begin
                            max_val <= arr_reg[calc_i];
                        end
                        if (arr_reg[calc_i] < min_val) begin
                            min_val <= arr_reg[calc_i];
                        end
                        calc_i <= calc_i + 4'd1;
                    end else if (n > 4'd0) begin
                        max_out <= max_val;
                        min_out <= min_val;
                        done <= 1'b1;
                        state <= IDLE;
                    end else begin
                        max_out <= 10'd0;
                        min_out <= 10'd0;
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule