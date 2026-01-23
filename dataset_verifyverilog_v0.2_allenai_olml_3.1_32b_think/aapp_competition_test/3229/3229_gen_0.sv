module RankingSystem (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [2:0] m,
    input [7:0] scores [7][9],
    output reg [3:0] result_rank,
    output reg done
);
localparam IDLE = 3'd0;
localparam CAPTURE = 3'd1;
localparam COMPUTE_AGGREGATES = 3'd2;
localparam COMPARE_RANKS = 3'd3;
localparam DONE_STATE = 3'd4;
reg [3:0] n_val;
reg [2:0] m_val;
reg [2:0] state;
reg [2:0] current_contestant;
reg [3:0] processing_contest_index;
reg [7:0] top4 [3:0];
reg [8:0] aggregate [8];
reg [2:0] higher_count;
reg [2:0] compare_counter;
reg [3:0] result_rank;
reg done;
always @(posedge clk) begin
    if (!rst_n) begin
        n_val <= 4'b0000;
        m_val <= 3'b000;
        state <= IDLE;
        current_contestant <= 2'b00;
        processing_contest_index <= 4'b0000;
        top4 <= 8'b00000000;
        aggregate <= 9'b000000000;
        higher_count <= 3'b000;
        compare_counter <= 3'b000;
        result_rank <= 4'b0000;
        done <= 1'b0;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                state <= CAPTURE;
            end
        end else if (state == CAPTURE) begin
            n_val <= n;
            m_val <= m;
            if (m_val > 0 && n_val > 0) begin
                state <= COMPUTE_AGGREGATES;
            end else begin
                state <= IDLE;
            end
        end else if (state == COMPUTE_AGGREGATES) begin
            if (processing_contest_index < n_val) begin
                if (scores[current_contestant][processing_contest_index] > top4[0]) begin
                    top4[3] <= top4[2];
                    top4[2] <= top4[1];
                    top4[1] <= top4[0];
                    top4[0] <= scores[current_contestant][processing_contest_index];
                end else if (scores[current_contestant][processing_contest_index] > top4[1]) begin
                    top4[3] <= top4[2];
                    top4[2] <= top4[1];
                    top4[1] <= scores[current_contestant][processing_contest_index];
                end else if (scores[current_contestant][processing_contest_index] > top4[2]) begin
                    top4[3] <= top4[2];
                    top4[2] <= scores[current_contestant][processing_contest_index];
                end else if (scores[current_contestant][processing_contest_index] > top4[3]) begin
                    top4[3] <= scores[current_contestant][processing_contest_index];
                end
                processing_contest_index <= processing_contest_index + 1;
            end else begin
                aggregate[current_contestant] <= top4[0] + top4[1] + top4[2] + top4[3];
                current_contestant <= current_contestant + 1;
                processing_contest_index <= 4'b0000;
                top4 <= 8'b00000000;
                if (current_contestant < m_val) begin
                end else begin
                    state <= COMPARE_RANKS;
                    compare_counter <= 1;
                end
            end
        end else if (state == COMPARE_RANKS) begin
            if (compare_counter < m_val) begin
                if (aggregate[compare_counter] > aggregate[0]) begin
                    higher_count <= higher_count + 1;
                end
                compare_counter <= compare_counter + 1;
            end else begin
                state <= DONE_STATE;
                result_rank <= higher_count + 1;
                done <= 1;
            end
        end
    end
endmodule