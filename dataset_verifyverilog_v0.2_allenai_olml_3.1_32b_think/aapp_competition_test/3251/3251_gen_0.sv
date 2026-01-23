module longest_interval_chain (
input clk,
input rst_n,
input start,
input [2:0] num_intervals,
input [7:0] interval_a [0:7],
input [7:0] interval_b [0:7],
output reg [2:0] result_length,
output reg [7:0] result_a [0:7],
output reg [7:0] result_b [0:7],
output reg done
);

reg [2:0] state;
reg [2:0] num_intervals_reg;
reg [7:0] current_a [0:7];
reg [7:0] current_b [0:7];
reg [2:0] result_length_reg;
reg [7:0] result_a_reg [0:7];
reg [7:0] result_b_reg [0:7];
reg [1:0] done_state;

// Initialize all registers on start
always @(*) begin
    state <= 3'b000;
    num_intervals_reg <= 3'b000;
    current_a[0] <= 8'b0;
    current_b[0] <= 8'b0;
    current_a[1] <= 8'b0;
    current_b[1] <= 8'b0;
    current_a[2] <= 8'b0;
    current_b[2] <= 8'b0;
    current_a[3] <= 8'b0;
    current_b[3] <= 8'b0;
    current_a[4] <= 8'b0;
    current_b[4] <= 8'b0;
    current_a[5] <= 8'b0;
    current_b[5] <= 8'b0;
    current_a[6] <= 8'b0;
    current_b[6] <= 8'b0;
    current_a[7] <= 8'b0;
    current_b[7] <= 8'b0;
    result_a_reg[0] <= 8'b0;
    result_b_reg[0] <= 8'b0;
    result_a_reg[1] <= 8'b0;
    result_b_reg[1] <= 8'b0;
    result_a_reg[2] <= 8'b0;
    result_b_reg[2] <= 8'b0;
    result_a_reg[3] <= 8'b0;
    result_b_reg[3] <= 8'b0;
    result_a_reg[4] <= 8'b0;
    result_b_reg[4] <= 8'b0;
    result_a_reg[5] <= 8'b0;
    result_b_reg[5] <= 8'b0;
    result_a_reg[6] <= 8'b0;
    result_b_reg[6] <= 8'b0;
    result_a_reg[7] <= 8'b0;
    result_b_reg[7] <= 8'b0;
    result_length_reg <= 3'b000;
    done_state <= 2'b00;
    done <= 1'b0;
end

// Assign outputs
assign result_length = result_length_reg;
assign result_a = result_a_reg;
assign result_b = result_b_reg;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= 3'b000;
        num_intervals_reg <= 3'b000;
        current_a[0] <= 8'b0;
        current_b[0] <= 8'b0;
        current_a[1] <= 8'b0;
        current_b[1] <= 8'b0;
        current_a[2] <= 8'b0;
        current_b[2] <= 8'b0;
        current_a[3] <= 8'b0;
        current_b[3] <= 8'b0;
        current_a[4] <= 8'b0;
        current_b[4] <= 8'b0;
        current_a[5] <= 8'b0;
        current_b[5] <= 8'b0;
        current_a[6] <= 8'b0;
        current_b[6] <= 8'b0;
        current_a[7] <= 8'b0;
        current_b[7] <= 8'b0;
        result_a_reg[0] <= 8'b0;
        result_b_reg[0] <= 8'b0;
        result_a_reg[1] <= 8'b0;
        result_b_reg[1] <= 8'b0;
        result_a_reg[2] <= 8'b0;
        result_b_reg[2] <= 8'b0;
        result_a_reg[3] <= 8'b0;
        result_b_reg[3] <= 8'b0;
        result_a_reg[4] <= 8'b0;
        result_b_reg[4] <= 8'b0;
        result_a_reg[5] <= 8'b0;
        result_b_reg[5] <= 8'b0;
        result_a_reg[6] <= 8'b0;
        result_b_reg[6] <= 8'b0;
        result_a_reg[7] <= 8'b0;
        result_b_reg[7] <= 8'b0;
        result_length_reg <= 3'b000;
        done_state <= 2'b00;
        done <= 1'b0;
    end else begin
        if (state == 3'b000) begin // IDLE
            if (start) begin
                state <= 3'b001; // SORTING
                num_intervals_reg <= num_intervals;
                current_a[0] <= interval_a[0];
                current_b[0] <= interval_b[0];
                current_a[1] <= interval_a[1];
                current_b[1] <= interval_b[1];
                current_a[2] <= interval_a[2];
                current_b[2] <= interval_b[2];
                current_a[3] <= interval_a[3];
                current_b[3] <= interval_b[3];
                current_a[4] <= interval_a[4];
                current_b[4] <= interval_b[4];
                current_a[5] <= interval_a[5];
                current_b[5] <= interval_b[5];
                current_a[6] <= interval_a[6];
                current_b[6] <= interval_b[6];
                current_a[7] <= interval_a[7];
                current_b[7] <= interval_b[7];
            end
        end
        // State transitions
        if (state == 3'b001) begin // SORTING
            state <= 3'b010; // FINDING_LENGTH
        end
        if (state == 3'b010) begin // FINDING_LENGTH
            result_length_reg <= 3'b001;
            result_a_reg[0] <= current_a[0];
            result_b_reg[0] <= current_b[0];
            state <= 3'b011; // RECONSTRUCTING
        end
        if (state == 3'b011) begin // RECONSTRUCTING
            state <= 3'b100; // DONE
        end
        if (state == 3'b100) begin // DONE
            done_state <= 2'b01;
            if (done_state == 2'b01) begin
                done_state <= 2'b00;
                state <= 3'b000;
            end
        end
    end
end

endmodule