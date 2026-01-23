module bitonic_max_sum (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [2:0] array_len,
    input [7:0] array_data [0:7],
    output reg [15:0] max_sum_result,
    output reg done
);

// Define states
localparam IDLE = 3'd0,
        CALC_MSIBS = 3'd1,
        CALC_MSDBS = 3'd2,
        CALC_RESULT = 3'd3,
        DONE = 3'd4;

// Internal signals
reg [2:0] state;
reg [2:0] array_len_reg; // input is 3 bits
reg [7:0] arr_reg [0:7];
reg [15:0] msibs [0:7];
reg [15:0] msdbs [0:7];

// Counters for MSIBS
reg [2:0] i_msibs;
reg [2:0] j_msibs;

// Counters for MSDBS (i_msdb is signed)
reg signed [2:0] i_msdb;
reg [2:0] j_msdb;

// For CALC_RESULT
reg [15:0] max_sum;
reg [2:0] i_result;

// done is output reg, no internal reg needed

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        array_len_reg <= 3'b000;
        arr_reg <= 8'b0;
        msibs <= 16'd0;
        msdbs <= 16'd0;
        i_msibs <= 3'b000;
        j_msibs <= 3'b000;
        i_msdb <= 3'b000;
        j_msdb <= 3'b000;
        max_sum <= 16'd0;
        i_result <= 3'b000;
        done <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    arr_reg <= array_data;
                    array_len_reg <= array_len;
                    state <= CALC_MSIBS;
                end
            end

            CALC_MSIBS: begin
                if (i_msibs < array_len_reg) begin
                    if (j_msibs < i_msibs) begin
                        if (arr_reg[i_msibs] > arr_reg[j_msibs]) begin
                            if (msibs[j_msibs] + arr_reg[i_msibs] > msibs[i_msibs]) begin
                                msibs[i_msibs] <= msibs[j_msibs] + arr_reg[i_msibs];
                            end
                        end
                        j_msibs <= j_msibs + 1;
                    end else begin
                        i_msibs <= i_msibs + 1;
                        j_msibs <= 3'b000;
                    end
                end else begin
                    state <= CALC_MSDBS;
                    i_msdb <= array_len_reg - 1;
                    j_msdb <= array_len_reg - 1;
                end
            end

            CALC_MSDBS: begin
                if (i_msdb >= 0) begin
                    if (j_msdb > i_msdb) begin
                        if (arr_reg[i_msdb] > arr_reg[j_msdb]) begin
                            if (msdbs[j_msdb] + arr_reg[i_msdb] > msdbs[i_msdb]) begin
                                msdbs[i_msdb] <= msdbs[j_msdb] + arr_reg[i_msdb];
                            end
                        end
                        j_msdb <= j_msdb - 1;
                    end else begin
                        i_msdb <= i_msdb - 1;
                        j_msdb <= array_len_reg - 1;
                    end
                end else begin
                    state <= CALC_RESULT;
                end
            end

            CALC_RESULT: begin
                if (i_result < array_len_reg) begin
                    max_sum <= ( (msibs[i_result] + msdbs[i_result] - arr_reg[i_result]) > max_sum ) ? (msibs[i_result] + msdbs[i_result] - arr_reg[i_result]) : max_sum;
                    i_result <= i_result + 1;
                end else begin
                    state <= DONE;
                    max_sum_result <= max_sum;
                    done <= 1'b1;
                end
            end

            DONE: begin
                // No operation
            end

        endcase
    end
end
endmodule