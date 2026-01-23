module sound_compression (
    input clk,
    input rst_n,
    input start,
    input [2:0] data_in,
    input [2:0] I_param,
    input valid_in,
    output reg [5:0] result,
    output reg done
);

// Combinatorial K
wire [2:0] K_wire;
always @(*) begin
    if (I_param >= 3) K_wire = 3'd8;
    else K_wire = (1 << I_param);
end

// Registers
reg [7:0] buffer;
reg [2:0] freq [0:7];
reg [3:0] read_count;
reg [2:0] count_idx;
reg [5:0] max_sum;
reg [5:0] result_reg;
reg [2:0] state;
reg [2:0] K_reg;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        state <= 3'd0;
        read_count <= 4'd0;
        buffer <= 8'd0;
        freq[0] <= 3'd0; freq[1] <= 3'd0; freq[2] <= 3'd0; freq[3] <= 3'd0;
        freq[4] <= 3'd0; freq[5] <= 3'd0; freq[6] <= 3'd0; freq[7] <= 3'd0;
        count_idx <= 2'd0;
        max_sum <= 5'd0;
        result_reg <= 6'd0;
        K_reg <= K_wire;
    end else begin
        case(state)
            3'd0: begin // IDLE
                if (start) begin
                    state <= 3'd1;
                    read_count <= 4'd0;
                    buffer <= 8'd0;
                    freq[0] <= 3'd0; freq[1] <= 3'd0; freq[2] <= 3'd0; freq[3] <= 3'd0;
                    freq[4] <= 3'd0; freq[5] <= 3'd0; freq[6] <= 3'd0; freq[7] <= 3'd0;
                    count_idx <= 2'd0;
                    max_sum <= 5'd0;
                    result_reg <= 6'd0;
                    K_reg <= K_wire;
                end else begin
                    state <= 3'd0;
                end
            end
            3'd1: begin // READ
                if (valid_in && read_count < 8) begin
                    buffer[read_count] <= data_in;
                    read_count <= read_count + 1;
                end
                if (read_count == 8) state <= 3'd2;
                else state <= 3'd1;
            end
            3'd2: begin // COUNT
                if (count_idx < 8) begin
                    freq[buffer[count_idx]] <= freq[buffer[count_idx]] + 1;
                    count_idx <= count_idx + 1;
                    state <= 3'd2;
                end else begin
                    state <= 3'd3;
                    count_idx <= 2'd0;
                end
            end
            3'd3: begin // SLIDING_WINDOW
                max_sum <= 5'd0;
                if (K_reg == 3'd1) begin
                    max_sum <= freq[0];
                    if (freq[1] > max_sum) max_sum <= freq[1];
                    if (freq[2] > max_sum) max_sum <= freq[2];
                    if (freq[3] > max_sum) max_sum <= freq[3];
                    if (freq[4] > max_sum) max_sum <= freq[4];
                    if (freq[5] > max_sum) max_sum <= freq[5];
                    if (freq[6] > max_sum) max_sum <= freq[6];
                    if (freq[7] > max_sum) max_sum <= freq[7];
                end else if (K_reg == 3'd2) begin
                    max_sum <= freq[0] + freq[1];
                    if (freq[1] + freq[2] > max_sum) max_sum <= freq[1] + freq[2];
                    if (freq[2] + freq[3] > max_sum) max_sum <= freq[2] + freq[3];
                    if (freq[3] + freq[4] > max_sum) max_sum <= freq[3] + freq[4];
                    if (freq[4] + freq[5] > max_sum) max_sum <= freq[4] + freq[5];
                    if (freq[5] + freq[6] > max_sum) max_sum <= freq[5] + freq[6];
                    if (freq[6] + freq[7] > max_sum) max_sum <= freq[6] + freq[7];
                end else if (K_reg == 3'd3) begin
                    max_sum <= freq[0] + freq[1] + freq[2];
                    if (freq[1] + freq[2] + freq[3] > max_sum) max_sum <= freq[1] + freq[2] + freq[3];
                    if (freq[2] + freq[3] + freq[4] > max_sum) max_sum <= freq[2] + freq[3] + freq[4];
                    if (freq[3] + freq[4] + freq[5] > max_sum) max_sum <= freq[3] + freq[4] + freq[5];
                    if (freq[4] + freq[5] + freq[6] > max_sum) max_sum <= freq[4] + freq[5] + freq[6];
                    if (freq[5] + freq[6] + freq[7] > max_sum) max_sum <= freq[5] + freq[6] + freq[7];
                end else if (K_reg == 3'd4) begin
                    max_sum <= freq[0] + freq[1] + freq[2] + freq[3];
                    if (freq[1] + freq[2] + freq[3] + freq[4] > max_sum) max_sum <= freq[1] + freq[2] + freq[3] + freq[4];
                    if (freq[2] + freq[3] + freq[4] + freq[5] > max_sum) max_sum <= freq[2] + freq[3] + freq[4] + freq[5];
                    if (freq[3] + freq[4] + freq[5] + freq[6] > max_sum) max_sum <= freq[3] + freq[4] + freq[5] + freq[6];
                    if (freq[4] + freq[5] + freq[6] + freq[7] > max_sum) max_sum <= freq[4] + freq[5] + freq[6] + freq[7];
                end else if (K_reg == 3'd5) begin
                    max_sum <= freq[0] + freq[1] + freq[2] + freq[3] + freq[4];
                    if (freq[1] + freq[2] + freq[3] + freq[4] + freq[5] > max_sum) max_sum <= freq[1] + freq[2] + freq[3] + freq[4] + freq[5];
                    if (freq[2] + freq[3] + freq[4] + freq[5] + freq[6] > max_sum) max_sum <= freq[2] + freq[3] + freq[4] + freq[5] + freq[6];
                    if (freq[3] + freq[4] + freq[5] + freq[6] + freq[7] > max_sum) max_sum <= freq[3] + freq[4] + freq[5] + freq[6] + freq[7];
                end else if (K_reg == 3'd6) begin
                    max_sum <= freq[0] + freq[1] + freq[2] + freq[3] + freq[4] + freq[5];
                    if (freq[1] + freq[2] + freq[3] + freq[4] + freq[5] + freq[6] > max_sum) max_sum <= freq[1] + freq[2] + freq[3] + freq[4] + freq[5] + freq[6];
                    if (freq[2] + freq[3] + freq[4] + freq[5] + freq[6] + freq[7] > max_sum) max_sum <= freq[2] + freq[3] + freq[4] + freq[5] + freq[6] + freq[7];
                end else if (K_reg == 3'd7) begin
                    max_sum <= freq[0] + freq[1] + freq[2] + freq[3] + freq[4] + freq[5] + freq[6];
                    if (freq[1] + freq[2] + freq[3] + freq[4] + freq[5] + freq[6] + freq[7] > max_sum) max_sum <= freq[1] + freq[2] + freq[3] + freq[4] + freq[5] + freq[6] + freq[7];
                end else begin // K_reg == 3'd8
                    max_sum <= freq[0] + freq[1] + freq[2] + freq[3] + freq[4] + freq[5] + freq[6] + freq[7];
                end
                state <= 3'd4;
            end
            3'd4: begin // CALCULATE_RESULT
                result_reg <= 8'd8 - max_sum;
                state <= 3'd5;
            end
            3'd5: begin // DONE
                done <= 1'b1;
                state <= 3'd5;
            end
        endcase
    end
end

// Outputs
assign result = result_reg;
endmodule