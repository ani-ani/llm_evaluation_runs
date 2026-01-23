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
localparam [2:0] DONE_STATE = 3'd4;

reg [2:0] state;
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

function [4:0] min5(input [4:0] a, input [4:0] b);
    min5 = (a < b) ? a : b;
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 0;
        area <= 0;
        p <= 0;
        q <= 0;
        best_area <= 0;
        best_p <= 0;
        best_q <= 0;
        p_iter <= 4'd4;
        total_usable <= 0;
        dist_index <= 0;
        q_temp <= 0;
        cells_filled <= 0;
        seq_len <= 0;
        seq_idx <= 0;
        row_reg <= 0;
        col_reg <= 0;
        current_dist_idx <= 0;
        copies_left <= 0;
        valid_distinct_reg <= 0;
        // Initialize matrix
        for (integer i = 0; i < MAX_P; i = i+1) begin
            for (integer j = 0; j < MAX_Q; j = j+1) begin
                matrix[i][j] <= 32'd0;
            end
        end
        // Initialize arrays
        for (integer i = 0; i < MAX_DISTINCT; i = i+1) begin
            num_reg[i] <= 32'd0;
            cnt_reg[i] <= 5'd0;
        end
        // Initialize seq array
        for (integer k = 0; k < 16; k = k+1) begin
            seq[k] <= 32'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 0;
                if (start) begin
                    valid_distinct_reg <= valid_distinct;
                    for (integer i = 0; i < MAX_DISTINCT; i = i+1) begin
                        num_reg[i] <= number_values[i];
                        cnt_reg[i] <= count_values[i];
                    end
                    p_iter <= 4'd4;
                    best_area <= 0;
                    best_p <= 0;
                    best_q <= 0;
                    state <= COMPUTE;
                    dist_index <= 0;
                    total_usable <= 0;
                end
            end

            COMPUTE: begin
                if (p_iter >= 1) begin
                    // Compute total usable for this p_iter
                    // We process one distinct number per cycle
                    if (dist_index < valid_distinct_reg) begin
                        if (cnt_reg[dist_index] > p_iter)
                            total_usable <= total_usable + p_iter;
                        else
                            total_usable <= total_usable + cnt_reg[dist_index];
                        dist_index <= dist_index + 1;
                    end else begin
                        // After processing all numbers, compute q
                        if (total_usable >= p_iter) begin
                            q_temp <= total_usable / p_iter;
                            if (q_temp >= p_iter && p_iter * q_temp > best_area) begin
                                best_area <= p_iter * q_temp;
                                best_p <= p_iter;
                                best_q <= q_temp;
                            end
                        end
                        p_iter <= p_iter - 1;
                        dist_index <= 0;
                        total_usable <= 0;
                    end
                end else begin
                    // Finished all heights
                    if (best_area > 0) begin
                        p <= best_p;
                        q <= best_q;
                        area <= best_area;
                        state <= GENERATE_SEQ;
                        seq_len <= 0;
                        current_dist_idx <= 0;
                        copies_left <= 0;
                    end else begin
                        // No rectangle possible
                        area <= 0;
                        p <= 0;
                        q <= 0;
                        state <= DONE_STATE;
                        done <= 1;
                    end
                end
            end

            GENERATE_SEQ: begin
                if (seq_len < best_area) begin
                    // If current number has no copies left, move to next
                    if (copies_left == 0) begin
                        // Skip numbers with zero count
                        if (current_dist_idx < valid_distinct_reg) begin
                            if (cnt_reg[current_dist_idx] == 0) begin
                                current_dist_idx <= current_dist_idx + 1;
                            end else begin
                                copies_left <= min5(cnt_reg[current_dist_idx], best_p);
                            end
                        end
                    end else begin
                        // Assign number to sequence
                        seq[seq_len] <= num_reg[current_dist_idx];
                        seq_len <= seq_len + 1;
                        // Decrement counters
                        cnt_reg[current_dist_idx] <= cnt_reg[current_dist_idx] - 1;
                        copies_left <= copies_left - 1;
                    end
                end else begin
                    // Sequence generation complete
                    seq_idx <= 0;
                    row_reg <= 0;
                    col_reg <= 0;
                    state <= FILL;
                end
            end

            FILL: begin
                if (seq_idx < best_area) begin
                    // Assign to matrix at diagonal position
                    matrix[row_reg][(col_reg + row_reg) % best_q] <= seq[seq_idx];
                    seq_idx <= seq_idx + 1;
                    // Move to next cell
                    if (row_reg == best_p - 1) begin
                        row_reg <= 0;
                        if (col_reg == best_q - 1) begin
                            col_reg <= 0;
                        end else begin
                            col_reg <= col_reg + 1;
                        end
                    end else begin
                        row_reg <= row_reg + 1;
                    end
                end else begin
                    state <= DONE_STATE;
                    done <= 1;
                end
            end

            DONE_STATE: begin
                // Hold done
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule