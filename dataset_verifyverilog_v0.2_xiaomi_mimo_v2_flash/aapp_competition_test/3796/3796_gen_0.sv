module beautiful_rectangle(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [MAX_N-1:0][7:0] data_in,
    input wire [5:0] n_valid,
    output reg done,
    output reg [5:0] rows,
    output reg [5:0] cols,
    output reg [15:0][15:0][7:0] matrix_out
);

    parameter MAX_N = 32;
    
    typedef enum logic [3:0] {
        IDLE,
        SORT_1, SORT_2, SORT_3,
        COUNT,
        CALC_DIM_START, CALC_DIM_LOOP, CALC_DIM_UPDATE,
        FILL,
        FINISH
    } state_t;
    
    state_t current_state, next_state;
    
    reg [MAX_N-1:0][7:0] sorted_data;
    reg [7:0] freq_values [0:31];
    reg [5:0] freq_counts [0:31];
    reg [5:0] unique_count;
    
    reg [4:0] sort_idx;
    reg [5:0] count_idx;
    
    reg [3:0] p_iter;
    reg [5:0] u_iter;
    reg [31:0] current_sum;
    reg [31:0] temp_q;
    reg [31:0] area;
    
    reg [5:0] fill_u;
    reg [5:0] fill_k;
    reg [5:0] fill_rem;
    reg [3:0] fill_sub_state;
    reg [5:0] calc_r, calc_c;

    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 1'b0;
            rows <= 6'b0;
            cols <= 6'b0;
            unique_count <= 6'b0;
            for (i = 0; i < 16; i = i + 1)
                for (j = 0; j < 16; j = j + 1)
                    matrix_out[i][j] <= 8'b0;
        end else begin
            current_state <= next_state;
            
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        sorted_data <= data_in;
                        sort_idx <= 5'd0;
                        count_idx <= 6'd0;
                        unique_count <= 6'b0;
                        p_iter <= 4'd8;
                        best_p <= 6'b0;
                        best_q <= 6'b0;
                        max_area <= 32'b0;
                        fill_u <= 6'b0;
                        fill_k <= 6'b0;
                        fill_rem <= 6'b0;
                        fill_sub_state <= 4'b0;
                    end
                end

                SORT_1, SORT_2, SORT_3: begin
                    if (sort_idx < n_valid - 1) begin
                        if (sorted_data[sort_idx] > sorted_data[sort_idx + 1]) begin
                            sorted_data[sort_idx] <= sorted_data[sort_idx + 1];
                            sorted_data[sort_idx + 1] <= sorted_data[sort_idx];
                        end
                        sort_idx <= sort_idx + 1;
                    end else begin
                        sort_idx <= 5'd0;
                    end
                end

                COUNT: begin
                    if (count_idx == 0 && n_valid > 0) begin
                        freq_values[0] <= sorted_data[0];
                        freq_counts[0] <= 6'd1;
                        unique_count <= 6'd1;
                        count_idx <= 6'd1;
                    end else if (count_idx < n_valid) begin
                        if (sorted_data[count_idx] == sorted_data[count_idx - 1]) begin
                            freq_counts[unique_count - 1] <= freq_counts[unique_count - 1] + 1;
                        end else begin
                            freq_values[unique_count] <= sorted_data[count_idx];
                            freq_counts[unique_count] <= 6'd1;
                            unique_count <= unique_count + 1;
                        end
                        count_idx <= count_idx + 1;
                    end
                end

                CALC_DIM_START: begin
                    current_sum <= 32'b0;
                    u_iter <= 6'd0;
                end
                
                CALC_DIM_LOOP: begin
                    if (u_iter < unique_count) begin
                        if (freq_counts[u_iter] < p_iter)
                            current_sum <= current_sum + freq_counts[u_iter];
                        else
                            current_sum <= current_sum + p_iter;
                        u_iter <= u_iter + 1;
                    end else begin
                    end
                end
                
                CALC_DIM_UPDATE: begin
                    if (current_sum >= p_iter * p_iter) begin
                        temp_q <= (current_sum + p_iter - 1) / p_iter;
                        area <= p_iter * ((current_sum + p_iter - 1) / p_iter);
                        if (p_iter * ((current_sum + p_iter - 1) / p_iter) > max_area) begin
                            max_area <= p_iter * ((current_sum + p_iter - 1) / p_iter);
                            best_p <= p_iter;
                            best_q <= (current_sum + p_iter - 1) / p_iter;
                        end
                    end
                    if (p_iter > 1) p_iter <= p_iter - 1;
                end

                FILL: begin
                    case (fill_sub_state)
                        0: begin
                            if (fill_rem == 0) begin
                                if (fill_u < unique_count) begin
                                    fill_rem <= freq_counts[fill_u];
                                    fill_k <= 6'b0;
                                    fill_sub_state <= 1;
                                end else begin
                                end
                            end else begin
                                fill_sub_state <= 1;
                            end
                        end
                        1: begin
                            if (fill_rem > 0) begin
                                calc_r <= fill_k % best_p;
                                calc_c <= (fill_k + (fill_k / best_p)) % best_q;
                                fill_rem <= fill_rem - 1;
                                fill_k <= fill_k + 1;
                                matrix_out[calc_r][calc_c] <= freq_values[fill_u];
                            end else begin
                                fill_u <= fill_u + 1;
                                fill_sub_state <= 0;
                            end
                        end
                    endcase
                end
                
                FINISH: begin
                    done <= 1'b1;
                    rows <= best_p;
                    cols <= best_q;
                end
            endcase
        end
    end

    always @(*) begin
        case (current_state)
            IDLE: next_state = start ? SORT_1 : IDLE;
            SORT_1: next_state = (sort_idx >= n_valid - 1 && n_valid > 0) ? SORT_2 : SORT_1;
            SORT_2: next_state = (sort_idx >= n_valid - 1 && n_valid > 0) ? SORT_3 : SORT_2;
            SORT_3: next_state = (sort_idx >= n_valid - 1 && n_valid > 0) ? COUNT : SORT_3;
            COUNT: begin
                if (n_valid == 0) next_state = FINISH;
                else if (count_idx >= n_valid) next_state = CALC_DIM_START;
                else next_state = COUNT;
            end
            CALC_DIM_START: next_state = CALC_DIM_LOOP;
            CALC_DIM_LOOP: begin
                if (u_iter < unique_count) next_state = CALC_DIM_LOOP;
                else next_state = CALC_DIM_UPDATE;
            end
            CALC_DIM_UPDATE: begin
                if (p_iter > 1) next_state = CALC_DIM_START;
                else next_state = FILL;
            end
            FILL: begin
                if (fill_u >= unique_count && fill_rem == 0 && fill_sub_state == 0)
                    next_state = FINISH;
                else
                    next_state = FILL;
            end
            FINISH: next_state = FINISH;
            default: next_state = IDLE;
        endcase
    end

    reg [5:0] best_p;
    reg [5:0] best_q;
    reg [31:0] max_area;

endmodule