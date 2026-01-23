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

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] MERGE = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] DEDUP = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state;
    reg [3:0] counter;
    reg [7:0] merged [0:11];
    reg [7:0] sorted [0:7];
    reg [7:0] final [0:7];
    reg [7:0] temp;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 4'd0;
            done <= 1'b0;
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            result_3 <= 8'd0;
            result_4 <= 8'd0;
            result_5 <= 8'd0;
            result_6 <= 8'd0;
            result_7 <= 8'd0;
            for (i = 0; i < 12; i = i + 1) merged[i] <= 8'd255;
            for (i = 0; i < 8; i = i + 1) begin
                sorted[i] <= 8'd255;
                final[i] <= 8'd255;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= MERGE;
                        counter <= 4'd0;
                    end
                end

                MERGE: begin
                    merged[0] <= arr_a_0;
                    merged[1] <= arr_a_1;
                    merged[2] <= arr_a_2;
                    merged[3] <= arr_a_3;
                    merged[4] <= arr_b_0;
                    merged[5] <= arr_b_1;
                    merged[6] <= arr_b_2;
                    merged[7] <= arr_b_3;
                    merged[8] <= 8'd255;
                    merged[9] <= 8'd255;
                    merged[10] <= 8'd255;
                    merged[11] <= 8'd255;
                    sorted[0] <= arr_a_0;
                    sorted[1] <= arr_a_1;
                    sorted[2] <= arr_a_2;
                    sorted[3] <= arr_a_3;
                    sorted[4] <= arr_b_0;
                    sorted[5] <= arr_b_1;
                    sorted[6] <= arr_b_2;
                    sorted[7] <= arr_b_3;
                    state <= SORT;
                    counter <= 4'd0;
                end

                SORT: begin
                    if (counter < 4'd8) begin
                        if (counter[0] == 1'b1) begin
                            for (i = 0; i < 7; i = i + 2) begin
                                if (sorted[i] > sorted[i+1]) begin
                                    temp <= sorted[i];
                                    sorted[i] <= sorted[i+1];
                                    sorted[i+1] <= temp;
                                end
                            end
                        end else begin
                            for (i = 1; i < 7; i = i + 2) begin
                                if (sorted[i] > sorted[i+1]) begin
                                    temp <= sorted[i];
                                    sorted[i] <= sorted[i+1];
                                    sorted[i+1] <= temp;
                                end
                            end
                        end
                        counter <= counter + 1'b1;
                    end else begin
                        state <= DEDUP;
                        counter <= 4'd0;
                        for (i = 0; i < 8; i = i + 1) final[i] <= 8'd255;
                    end
                end

                DEDUP: begin
                    if (counter < 4'd8) begin
                        if (counter == 4'd0) begin
                            final[0] <= sorted[0];
                            counter <= 4'd1;
                        end else begin
                            if (sorted[counter] != final[counter-1] && sorted[counter] != 8'd255) begin
                                final[counter] <= sorted[counter];
                            end else if (sorted[counter] == final[counter-1]) begin
                                final[counter] <= 8'd255;
                            end
                            counter <= counter + 1'b1;
                        end
                    end else begin
                        for (i = 0; i < 7; i = i + 1) begin
                            if (final[i] == 8'd255 && final[i+1] != 8'd255) begin
                                final[i] <= final[i+1];
                                final[i+1] <= 8'd255;
                            end
                        end
                        result_0 <= final[0];
                        result_1 <= final[1];
                        result_2 <= final[2];
                        result_3 <= final[3];
                        result_4 <= final[4];
                        result_5 <= final[5];
                        result_6 <= final[6];
                        result_7 <= final[7];
                        state <= DONE_STATE;
                        done <= 1'b1;
                    end
                end

                DONE_STATE: begin
                    if (!start) begin
                        done <= 1'b0;
                        state <= IDLE;
                    end
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule