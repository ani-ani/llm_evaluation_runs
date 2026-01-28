module MaxScorePartition(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [2:0] k,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    output reg [7:0] result,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PRECOMPUTE = 2'd1;
    localparam [1:0] ENUMERATE = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state;
    reg [7:0] seg_score [0:7][0:7];
    reg [7:0] arr_reg [0:7];
    reg [7:0] temp_max;
    reg [7:0] temp_min;
    reg [3:0] i, j, p, split;
    reg [7:0] current_gcd;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    integer iter_i, iter_j;

    // Helper function: GCD
    function automatic [7:0] gcd;
        input [7:0] a;
        input [7:0] b;
        reg [7:0] x, y, t;
        begin
            x = a;
            y = b;
            while (y != 8'd0) begin
                t = y;
                y = x % y;
                x = t;
            end
            gcd = x;
        end
    endfunction

    // Helper function: Largest Prime Factor
    function automatic [7:0] largest_prime_factor;
        input [7:0] n;
        reg [7:0] temp, div, max_p;
        begin
            if (n <= 8'd1) begin
                largest_prime_factor = 8'd0;
            end else begin
                temp = n;
                div = 8'd2;
                max_p = 8'd0;
                while (div * div <= temp) begin
                    if (temp % div == 8'd0) begin
                        max_p = div;
                        while (temp % div == 8'd0) begin
                            temp = temp / div;
                        end
                    end
                    div = div + 8'd1;
                end
                if (temp > 8'd1) begin
                    max_p = temp;
                end
                largest_prime_factor = max_p;
            end
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            cycle_count <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
            p <= 4'd0;
            split <= 4'd0;
            current_gcd <= 8'd0;
            temp_max <= 8'd0;
            temp_min <= 8'd0;
            for (iter_i = 0; iter_i < 8; iter_i = iter_i + 1) begin
                for (iter_j = 0; iter_j < 8; iter_j = iter_j + 1) begin
                    seg_score[iter_i][iter_j] <= 8'd0;
                end
            end
            for (iter_i = 0; iter_i < 8; iter_i = iter_i + 1) begin
                arr_reg[iter_i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                    if (start) begin
                        arr_reg[0] <= arr_0;
                        arr_reg[1] <= arr_1;
                        arr_reg[2] <= arr_2;
                        arr_reg[3] <= arr_3;
                        arr_reg[4] <= arr_4;
                        arr_reg[5] <= arr_5;
                        arr_reg[6] <= arr_6;
                        arr_reg[7] <= arr_7;
                        state <= PRECOMPUTE;
                    end
                end

                PRECOMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (i < n) begin
                        if (j >= i) begin
                            if (j == i) begin
                                current_gcd <= arr_reg[i];
                            end else begin
                                current_gcd <= gcd(current_gcd, arr_reg[j]);
                            end
                            if (j >= i) begin
                                seg_score[i][j] <= largest_prime_factor((j == i) ? arr_reg[i] : gcd(current_gcd, arr_reg[j]));
                            end
                            j <= j + 4'd1;
                        end else begin
                            j <= i;
                        end
                        if (j >= n) begin
                            j <= 4'd0;
                            i <= i + 4'd1;
                        end
                    end else begin
                        if (k == 3'd1) begin
                            temp_max <= seg_score[0][n-1];
                            state <= DONE_STATE;
                        end else if (k == 3'd2) begin
                            state <= ENUMERATE;
                            split <= 4'd1;
                            temp_max <= 8'd0;
                        end else if (k == 3'd3) begin
                            state <= ENUMERATE;
                            i <= 4'd1;
                            temp_max <= 8'd0;
                        end else begin
                            state <= DONE_STATE;
                        end
                    end
                end

                ENUMERATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (k == 3'd2) begin
                        if (split < n) begin
                            temp_min = seg_score[0][split-1];
                            if (seg_score[split][n-1] < temp_min) begin
                                temp_min = seg_score[split][n-1];
                            end
                            if (temp_min > temp_max) begin
                                temp_max <= temp_min;
                            end
                            split <= split + 4'd1;
                        end else begin
                            state <= DONE_STATE;
                        end
                    end else if (k == 3'd3) begin
                        if (i < n - 1) begin
                            if (j > i && j < n) begin
                                temp_min = seg_score[0][i-1];
                                if (seg_score[i][j-1] < temp_min) begin
                                    temp_min = seg_score[i][j-1];
                                end
                                if (seg_score[j][n-1] < temp_min) begin
                                    temp_min = seg_score[j][n-1];
                                end
                                if (temp_min > temp_max) begin
                                    temp_max <= temp_min;
                                end
                                j <= j + 4'd1;
                            end else begin
                                j <= i + 4'd2;
                            end
                            if (j >= n) begin
                                j <= 4'd0;
                                i <= i + 4'd1;
                            end
                        end else begin
                            state <= DONE_STATE;
                        end
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    result <= temp_max;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule