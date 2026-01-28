module union_arrays (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_a_0,
    input wire [7:0] arr_a_1,
    input wire [7:0] arr_a_2,
    input wire [7:0] arr_a_3,
    input wire [7:0] arr_b_0,
    input wire [7:0] arr_b_1,
    input wire [7:0] arr_b_2,
    input wire [7:0] arr_b_3,
    output reg [7:0] result_0,
    output reg [7:0] result_1,
    output reg [7:0] result_2,
    output reg [7:0] result_3,
    output reg [7:0] result_4,
    output reg [7:0] result_5,
    output reg [7:0] result_6,
    output reg [7:0] result_7,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] MERGE = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] REMOVE_DUP = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [3:0] counter;
    reg [7:0] temp_a;
    reg [7:0] temp_b;
    reg [7:0] merged_0;
    reg [7:0] merged_1;
    reg [7:0] merged_2;
    reg [7:0] merged_3;
    reg [7:0] merged_4;
    reg [7:0] merged_5;
    reg [7:0] merged_6;
    reg [7:0] merged_7;
    reg [7:0] merged_8;
    reg [7:0] merged_9;
    reg [7:0] merged_10;
    reg [7:0] merged_11;
    reg [7:0] sorted_0;
    reg [7:0] sorted_1;
    reg [7:0] sorted_2;
    reg [7:0] sorted_3;
    reg [7:0] sorted_4;
    reg [7:0] sorted_5;
    reg [7:0] sorted_6;
    reg [7:0] sorted_7;
    reg [7:0] compact_0;
    reg [7:0] compact_1;
    reg [7:0] compact_2;
    reg [7:0] compact_3;
    reg [7:0] compact_4;
    reg [7:0] compact_5;
    reg [7:0] compact_6;
    reg [7:0] compact_7;
    reg [3:0] output_idx;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd12;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            counter <= 4'd0;
            cycle_count <= 4'd0;
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            result_3 <= 8'd0;
            result_4 <= 8'd0;
            result_5 <= 8'd0;
            result_6 <= 8'd0;
            result_7 <= 8'd0;
            merged_0 <= 8'd0;
            merged_1 <= 8'd0;
            merged_2 <= 8'd0;
            merged_3 <= 8'd0;
            merged_4 <= 8'd0;
            merged_5 <= 8'd0;
            merged_6 <= 8'd0;
            merged_7 <= 8'd0;
            merged_8 <= 8'd255;
            merged_9 <= 8'd255;
            merged_10 <= 8'd255;
            merged_11 <= 8'd255;
            sorted_0 <= 8'd0;
            sorted_1 <= 8'd0;
            sorted_2 <= 8'd0;
            sorted_3 <= 8'd0;
            sorted_4 <= 8'd0;
            sorted_5 <= 8'd0;
            sorted_6 <= 8'd0;
            sorted_7 <= 8'd0;
            compact_0 <= 8'd0;
            compact_1 <= 8'd0;
            compact_2 <= 8'd0;
            compact_3 <= 8'd0;
            compact_4 <= 8'd0;
            compact_5 <= 8'd0;
            compact_6 <= 8'd0;
            compact_7 <= 8'd0;
            output_idx <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    counter <= 4'd0;
                    output_idx <= 4'd0;
                    if (start) begin
                        state <= MERGE;
                    end
                end

                MERGE: begin
                    // Copy input arrays and pad with max values
                    merged_0 <= arr_a_0;
                    merged_1 <= arr_a_1;
                    merged_2 <= arr_a_2;
                    merged_3 <= arr_a_3;
                    merged_4 <= arr_b_0;
                    merged_5 <= arr_b_1;
                    merged_6 <= arr_b_2;
                    merged_7 <= arr_b_3;
                    merged_8 <= 8'd255;
                    merged_9 <= 8'd255;
                    merged_10 <= 8'd255;
                    merged_11 <= 8'd255;
                    
                    // Initialize sorted array from merged
                    sorted_0 <= arr_a_0;
                    sorted_1 <= arr_a_1;
                    sorted_2 <= arr_a_2;
                    sorted_3 <= arr_a_3;
                    sorted_4 <= arr_b_0;
                    sorted_5 <= arr_b_1;
                    sorted_6 <= arr_b_2;
                    sorted_7 <= arr_b_3;
                    
                    state <= SORT;
                    counter <= 4'd0;
                end

                SORT: begin
                    // Odd-even transposition sort
                    if (counter < 4'd8) begin
                        if (counter[0] == 1'b1) begin
                            // Odd phase
                            if (sorted_0 > sorted_1) begin temp_a <= sorted_0; sorted_0 <= sorted_1; sorted_1 <= temp_a; end
                            if (sorted_2 > sorted_3) begin temp_a <= sorted_2; sorted_2 <= sorted_3; sorted_3 <= temp_a; end
                            if (sorted_4 > sorted_5) begin temp_a <= sorted_4; sorted_4 <= sorted_5; sorted_5 <= temp_a; end
                            if (sorted_6 > sorted_7) begin temp_a <= sorted_6; sorted_6 <= sorted_7; sorted_7 <= temp_a; end
                        end else begin
                            // Even phase
                            if (sorted_1 > sorted_2) begin temp_a <= sorted_1; sorted_1 <= sorted_2; sorted_2 <= temp_a; end
                            if (sorted_3 > sorted_4) begin temp_a <= sorted_3; sorted_3 <= sorted_4; sorted_4 <= temp_a; end
                            if (sorted_5 > sorted_6) begin temp_a <= sorted_5; sorted_5 <= sorted_6; sorted_6 <= temp_a; end
                        end
                        counter <= counter + 1'b1;
                    end else begin
                        state <= REMOVE_DUP;
                        counter <= 4'd0;
                        output_idx <= 4'd0;
                    end
                end

                REMOVE_DUP: begin
                    if (counter < 4'd8) begin
                        // Check if value is different from previous and not 255
                        if (counter == 4'd0) begin
                            // First element
                            if (sorted_0 != 8'd255) begin
                                compact_0 <= sorted_0;
                                output_idx <= output_idx + 1'b1;
                            end
                        end else if (counter == 4'd1) begin
                            if (sorted_1 != 8'd255 && sorted_1 != sorted_0 && output_idx < 4'd8) begin
                                if (output_idx == 4'd1) compact_1 <= sorted_1;
                                else compact_0 <= sorted_1;
                                output_idx <= output_idx + 1'b1;
                            end
                        end else if (counter == 4'd2) begin
                            if (sorted_2 != 8'd255 && sorted_2 != sorted_1 && sorted_2 != sorted_0 && output_idx < 4'd8) begin
                                if (output_idx == 4'd2) compact_2 <= sorted_2;
                                else if (output_idx == 4'd1) compact_1 <= sorted_2;
                                else compact_0 <= sorted_2;
                                output_idx <= output_idx + 1'b1;
                            end
                        end else if (counter == 4'd3) begin
                            if (sorted_3 != 8'd255 && sorted_3 != sorted_2 && sorted_3 != sorted_1 && sorted_3 != sorted_0 && output_idx < 4'd8) begin
                                if (output_idx == 4'd3) compact_3 <= sorted_3;
                                else if (output_idx == 4'd2) compact_2 <= sorted_3;
                                else if (output_idx == 4'd1) compact_1 <= sorted_3;
                                else compact_0 <= sorted_3;
                                output_idx <= output_idx + 1'b1;
                            end
                        end else if (counter == 4'd4) begin
                            if (sorted_4 != 8'd255 && sorted_4 != sorted_3 && sorted_4 != sorted_2 && sorted_4 != sorted_1 && sorted_4 != sorted_0 && output_idx < 4'd8) begin
                                if (output_idx == 4'd4) compact_4 <= sorted_4;
                                else if (output_idx == 4'd3) compact_3 <= sorted_4;
                                else if (output_idx == 4'd2) compact_2 <= sorted_4;
                                else if (output_idx == 4'd1) compact_1 <= sorted_4;
                                else compact_0 <= sorted_4;
                                output_idx <= output_idx + 1'b1;
                            end
                        end else if (counter == 4'd5) begin
                            if (sorted_5 != 8'd255 && sorted_5 != sorted_4 && sorted_5 != sorted_3 && sorted_5 != sorted_2 && sorted_5 != sorted_1 && sorted_5 != sorted_0 && output_idx < 4'd8) begin
                                if (output_idx == 4'd5) compact_5 <= sorted_5;
                                else if (output_idx == 4'd4) compact_4 <= sorted_5;
                                else if (output_idx == 4'd3) compact_3 <= sorted_5;
                                else if (output_idx == 4'd2) compact_2 <= sorted_5;
                                else if (output_idx == 4'd1) compact_1 <= sorted_5;
                                else compact_0 <= sorted_5;
                                output_idx <= output_idx + 1'b1;
                            end
                        end else if (counter == 4'd6) begin
                            if (sorted_6 != 8'd255 && sorted_6 != sorted_5 && sorted_6 != sorted_4 && sorted_6 != sorted_3 && sorted_6 != sorted_2 && sorted_6 != sorted_1 && sorted_6 != sorted_0 && output_idx < 4'd8) begin
                                if (output_idx == 4'd6) compact_6 <= sorted_6;
                                else if (output_idx == 4'd5) compact_5 <= sorted_6;
                                else if (output_idx == 4'd4) compact_4 <= sorted_6;
                                else if (output_idx == 4'd3) compact_3 <= sorted_6;
                                else if (output_idx == 4'd2) compact_2 <= sorted_6;
                                else if (output_idx == 4'd1) compact_1 <= sorted_6;
                                else compact_0 <= sorted_6;
                                output_idx <= output_idx + 1'b1;
                            end
                        end else begin
                            if (sorted_7 != 8'd255 && sorted_7 != sorted_6 && sorted_7 != sorted_5 && sorted_7 != sorted_4 && sorted_7 != sorted_3 && sorted_7 != sorted_2 && sorted_7 != sorted_1 && sorted_7 != sorted_0 && output_idx < 4'd8) begin
                                if (output_idx == 4'd7) compact_7 <= sorted_7;
                                else if (output_idx == 4'd6) compact_6 <= sorted_7;
                                else if (output_idx == 4'd5) compact_5 <= sorted_7;
                                else if (output_idx == 4'd4) compact_4 <= sorted_7;
                                else if (output_idx == 4'd3) compact_3 <= sorted_7;
                                else if (output_idx == 4'd2) compact_2 <= sorted_7;
                                else if (output_idx == 4'd1) compact_1 <= sorted_7;
                                else compact_0 <= sorted_7;
                                output_idx <= output_idx + 1'b1;
                            end
                        end
                        counter <= counter + 1'b1;
                    end else begin
                        // Copy compacted results to outputs
                        result_0 <= compact_0;
                        result_1 <= compact_1;
                        result_2 <= compact_2;
                        result_3 <= compact_3;
                        result_4 <= compact_4;
                        result_5 <= compact_5;
                        result_6 <= compact_6;
                        result_7 <= compact_7;
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    if (!start) begin
                        done <= 1'b0;
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule