module beautiful_rectangle #(
    parameter MAX_DISTINCT = 8,
    parameter MAX_P = 4,
    parameter MAX_Q = 4
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] number_values [0:MAX_DISTINCT-1],
    input wire [4:0] count_values [0:MAX_DISTINCT-1],
    input wire [3:0] valid_distinct,
    output reg [15:0] area,
    output reg [3:0] p,
    output reg [3:0] q,
    output reg [31:0] matrix [0:MAX_P-1][0:MAX_Q-1],
    output reg done
);

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] COMPUTE = 3'd1;
localparam [2:0] GENERATE_SEQ = 3'd2;
localparam [2:0] FILL = 3'd3;
localparam [2:0] DONE = 3'd4;

reg [2:0] state;
reg [2:0] next_state;
reg [3:0] p_iter;
reg [15:0] total_usable;
reg [15:0] best_area;
reg [3:0] best_p;
reg [3:0] best_q;
reg [3:0] dist_index;
reg [15:0] q_temp;
reg [7:0] cells_filled;
reg [3:0] seq_len;
reg [3:0] seq_idx;
reg [31:0] seq [0:15];
reg [3:0] row_reg;
reg [3:0] col_reg;
reg [3:0] current_dist_idx;
reg [4:0] copies_left;
reg [31:0] num_reg [0:MAX_DISTINCT-1];
reg [4:0] cnt_reg [0:MAX_DISTINCT-1];
reg [3:0] valid_distinct_reg;
reg [7:0] cycle_count;

function [4:0] min5(input [4:0] a, input [4:0] b);
    min5 = (a < b) ? a : b;
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        area <= 16'd0;
        p <= 4'd0;
        q <= 4'd0;
        best_area <= 16'd0;
        best_p <= 4'd0;
        best_q <= 4'd0;
        p_iter <= 4'd4;
        total_usable <= 16'd0;
        dist_index <= 4'd0;
        q_temp <= 16'd0;
        cells_filled <= 8'd0;
        seq_len <= 4'd0;
        seq_idx <= 4'd0;
        row_reg <= 4'd0;
        col_reg <= 4'd0;
        current_dist_idx <= 4'd0;
        copies_left <= 5'd0;
        valid_distinct_reg <= 4'd0;
        cycle_count <= 8'd0;
        
        for (integer i = 0; i < MAX_P; i = i+1) begin
            for (integer j = 0; j < MAX_Q; j = j+1) begin
                matrix[i][j] <= 32'd0;
            end
        end
        
        for (integer i = 0; i < 16; i = i+1) begin
            seq[i] <= 32'd0;
        end
        
        for (integer i = 0; i < MAX_DISTINCT; i = i+1) begin
            num_reg[i] <= 32'd0;
            cnt_reg[i] <= 5'd0;
        end
    end else begin
        cycle_count <= cycle_count + 8'd1;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                cycle_count <= 8'd0;
                if (start) begin
                    valid_distinct_reg <= valid_distinct;
                    for (integer i = 0; i < MAX_DISTINCT; i = i+1) begin
                        num_reg[i] <= number_values[i];
                        cnt_reg[i] <= count_values[i];
                    end
                    p_iter <= 4'd4;
                    best_area <= 16'd0;
                    best_p <= 4'd0;
                    best_q <= 4'd0;
                    state <= COMPUTE;
                end
            end

            COMPUTE: begin
                if (cycle_count > 8'd100) begin
                    state <= DONE;
                end else if (p_iter >= 4'd1) begin
                    if (dist_index < valid_distinct_reg) begin
                        if (cnt_reg[dist_index] > p_iter) begin
                            total_usable <= total_usable + p_iter;
                        end else begin
                            total_usable <= total_usable + cnt_reg[dist_index];
                        end
                        dist_index <= dist_index + 4'd1;
                    end else begin
                        q_temp <= total_usable / p_iter;
                        if (q_temp >= p_iter && (p_iter * q_temp) > best_area) begin
                            best_area <= p_iter * q_temp;
                            best_p <= p_iter;
                            best_q <= q_temp;
                        end
                        p_iter <= p_iter - 4'd1;
                        total_usable <= 16'd0;
                        dist_index <= 4'd0;
                    end
                end else begin
                    if (best_area > 16'd0) begin
                        p <= best_p;
                        q <= best_q;
                        area <= best_area;
                        state <= GENERATE_SEQ;
                        seq_len <= 4'd0;
                        current_dist_idx <= 4'd0;
                        copies_left <= 5'd0;
                    end else begin
                        state <= DONE;
                        done <= 1'b1;
                    end
                end
            end

            GENERATE_SEQ: begin
                if (seq_len < best_area) begin
                    if (copies_left == 5'd0) begin
                        if (current_dist_idx < valid_distinct_reg) begin
                            if (cnt_reg[current_dist_idx] != 5'd0) begin
                                copies_left <= min5(cnt_reg[current_dist_idx], best_p);
                                current_dist_idx <= current_dist_idx + 4'd1;
                            end else begin
                                current_dist_idx <= current_dist_idx + 4'd1;
                            end
                        end
                    end else begin
                        seq[seq_len] <= num_reg[current_dist_idx-4'd1];
                        seq_len <= seq_len + 4'd1;
                        cnt_reg[current_dist_idx-4'd1] <= cnt_reg[current_dist_idx-4'd1] - 5'd1;
                        copies_left <= copies_left - 5'd1;
                    end
                end else begin
                    seq_idx <= 4'd0;
                    row_reg <= 4'd0;
                    col_reg <= 4'd0;
                    state <= FILL;
                end
            end

            FILL: begin
                if (seq_idx < best_area) begin
                    matrix[row_reg][(col_reg + row_reg) % best_q] <= seq[seq_idx];
                    seq_idx <= seq_idx + 4'd1;
                    
                    if (row_reg == (best_p - 4'd1)) begin
                        row_reg <= 4'd0;
                        if (col_reg == (best_q - 4'd1)) begin
                            col_reg <= 4'd0;
                        end else begin
                            col_reg <= col_reg + 4'd1;
                        end
                    end else begin
                        row_reg <= row_reg + 4'd1;
                    end
                end else begin
                    state <= DONE;
                    done <= 1'b1;
                end
            end

            DONE: begin
                done <= 1'b1;
                if (!start) begin
                    state <= IDLE;
                end
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule