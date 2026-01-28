module group_photo_area (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [9:0] max_h,
    input [9:0] w0, h0, w1, h1, w2, h2, w3, h3,
    input [9:0] w4, h4, w5, h5, w6, h6, w7, h7,
    output reg [23:0] area,
    output reg done
);

    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] SORT    = 3'd3;
    localparam [2:0] CALC    = 3'd4;
    localparam [2:0] FINISH  = 3'd5;
    localparam [2:0] ERROR   = 3'd6;

    reg [2:0] state;
    reg [2:0] next_state;
    reg [2:0] friend_idx;
    reg [2:0] lies_remaining;
    reg [2:0] i;
    reg [2:0] j;
    reg signed [10:0] diff_i, diff_j;
    reg [9:0] w_arr [0:7];
    reg [9:0] h_arr [0:7];
    reg [12:0] total_width;
    reg [2:0] sort_counter;

    integer loop_idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            area <= 24'd0;
            friend_idx <= 3'd0;
            lies_remaining <= 3'd0;
            i <= 3'd0;
            j <= 3'd0;
            total_width <= 13'd0;
            sort_counter <= 3'd0;
            for (loop_idx = 0; loop_idx < 8; loop_idx = loop_idx + 1) begin
                w_arr[loop_idx] <= 10'd0;
                h_arr[loop_idx] <= 10'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        lies_remaining <= n >> 1;
                        friend_idx <= 3'd0;
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    case (friend_idx)
                        3'd0: begin w_arr[0] <= w0; h_arr[0] <= h0; end
                        3'd1: begin w_arr[1] <= w1; h_arr[1] <= h1; end
                        3'd2: begin w_arr[2] <= w2; h_arr[2] <= h2; end
                        3'd3: begin w_arr[3] <= w3; h_arr[3] <= h3; end
                        3'd4: begin w_arr[4] <= w4; h_arr[4] <= h4; end
                        3'd5: begin w_arr[5] <= w5; h_arr[5] <= h5; end
                        3'd6: begin w_arr[6] <= w6; h_arr[6] <= h6; end
                        3'd7: begin w_arr[7] <= w7; h_arr[7] <= h7; end
                    endcase
                    friend_idx <= friend_idx + 3'd1;
                    if (friend_idx == 3'd7) begin
                        i <= 3'd0;
                        state <= PROCESS;
                    end
                end

                PROCESS: begin
                    if (h_arr[i] > max_h) begin
                        if (lies_remaining > 3'd0 && w_arr[i] <= max_h) begin
                            w_arr[i] <= h_arr[i];
                            h_arr[i] <= w_arr[i];
                            lies_remaining <= lies_remaining - 3'd1;
                            state <= ERROR;
                        end else begin
                            state <= ERROR;
                        end
                    end
                    if (i == 3'd7) begin
                        i <= 3'd0;
                        j <= 3'd0;
                        sort_counter <= 3'd0;
                        state <= SORT;
                    end else begin
                        i <= i + 3'd1;
                    end
                end

                SORT: begin
                    if (i < 3'd7) begin
                        diff_i <= h_arr[i] - w_arr[i];
                        diff_j <= h_arr[i+1] - w_arr[i+1];
                        if (diff_i > diff_j) begin
                            w_arr[i] <= w_arr[i+1];
                            w_arr[i+1] <= w_arr[i];
                            h_arr[i] <= h_arr[i+1];
                            h_arr[i+1] <= h_arr[i];
                        end
                        i <= i + 3'd1;
                    end else begin
                        if (sort_counter >= 3'd6) begin
                            i <= 3'd0;
                            total_width <= 13'd0;
                            state <= CALC;
                        end else begin
                            sort_counter <= sort_counter + 3'd1;
                            i <= 3'd0;
                        end
                    end
                end

                CALC: begin
                    if (i < 3'd8) begin
                        if (lies_remaining > 3'd0 && w_arr[i] <= max_h && h_arr[i] < w_arr[i]) begin
                            total_width <= total_width + h_arr[i];
                            lies_remaining <= lies_remaining - 3'd1;
                        end else begin
                            total_width <= total_width + w_arr[i];
                        end
                        i <= i + 3'd1;
                    end else begin
                        area <= total_width * max_h;
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end

                ERROR: begin
                    area <= 24'hFFFFFF;
                    state <= FINISH;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule