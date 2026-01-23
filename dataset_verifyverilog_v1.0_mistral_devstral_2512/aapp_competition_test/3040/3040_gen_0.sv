module longest_repeated_substring(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:15],
    input wire [4:0] len,
    output reg [7:0] result [0:15],
    output reg [4:0] out_len,
    output reg done
);

    // State machine states
    localparam [2:0] IDLE = 3'b000;
    localparam [2:0] CHECK_L = 3'b001;
    localparam [2:0] COMPARE = 3'b010;
    localparam [2:0] NEXT_J = 3'b011;
    localparam [2:0] NEXT_I = 3'b100;
    localparam [2:0] UPDATE_BEST = 3'b101;
    localparam [2:0] FINISHED = 3'b110;

    reg [2:0] state;
    reg [4:0] L;
    reg [4:0] i, j, k;
    reg [7:0] best_substring [0:15];
    reg [4:0] best_len;
    reg found_repeated;
    reg [7:0] temp_char1, temp_char2;
    reg [4:0] valid_len;
    integer m;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            out_len <= 5'd0;
            L <= 5'd0;
            i <= 5'd0;
            j <= 5'd0;
            k <= 5'd0;
            found_repeated <= 1'b0;
            best_len <= 5'd0;
            for (m = 0; m < 16; m = m + 1) begin
                result[m] <= 8'd0;
                best_substring[m] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start && len > 1) begin
                        valid_len <= (len > 16) ? 16 : len;
                        L <= (len > 16) ? 16 : len;
                        i <= 5'd0;
                        j <= 5'd0;
                        k <= 5'd0;
                        found_repeated <= 1'b0;
                        best_len <= 5'd0;
                        done <= 1'b0;
                        state <= CHECK_L;
                    end else if (start && len <= 1) begin
                        for (m = 0; m < 16; m = m + 1) begin
                            result[m] <= (m == 0 && len == 1) ? arr[0] : 8'd0;
                        end
                        out_len <= (len == 1) ? 1 : 0;
                        done <= 1'b1;
                        state <= FINISHED;
                    end
                end
                
                CHECK_L: begin
                    if (L >= 2) begin
                        i <= 5'd0;
                        j <= 5'd1;
                        found_repeated <= 1'b0;
                        state <= COMPARE;
                    end else if (best_len == 0) begin
                        for (m = 0; m < 16; m = m + 1) begin
                            result[m] <= (m == 0) ? arr[0] : 8'd0;
                        end
                        out_len <= 1;
                        done <= 1'b1;
                        state <= FINISHED;
                    end else begin
                        for (m = 0; m < 16; m = m + 1) begin
                            result[m] <= (m < best_len) ? best_substring[m] : 8'd0;
                        end
                        out_len <= best_len;
                        done <= 1'b1;
                        state <= FINISHED;
                    end
                end
                
                COMPARE: begin
                    if (k < L && i + k < valid_len && j + k < valid_len) begin
                        temp_char1 <= arr[i + k];
                        temp_char2 <= arr[j + k];
                        k <= k + 1;
                        state <= COMPARE;
                    end else if (k == L) begin
                        if (temp_char1 == temp_char2 && found_repeated == 0) begin
                            k <= 5'd0;
                            state <= COMPARE;
                        end else if (temp_char1 == temp_char2 && found_repeated == 1) begin
                            state <= UPDATE_BEST;
                        end else begin
                            state <= NEXT_J;
                        end
                    end else begin
                        if (k == L) begin
                            if (found_repeated) begin
                                state <= UPDATE_BEST;
                            end else begin
                                state <= NEXT_J;
                            end
                        end else begin
                            state <= NEXT_J;
                        end
                    end
                end
                
                NEXT_J: begin
                    if (j + 1 < valid_len - L + 1 && i + L <= valid_len && j + L <= valid_len) begin
                        j <= j + 1;
                        k <= 5'd0;
                        state <= COMPARE;
                    end else begin
                        state <= NEXT_I;
                    end
                end
                
                NEXT_I: begin
                    if (i + 1 < valid_len - L + 1) begin
                        i <= i + 1;
                        j <= i + 2;
                        k <= 5'd0;
                        state <= COMPARE;
                    end else begin
                        L <= L - 1;
                        state <= CHECK_L;
                    end
                end
                
                UPDATE_BEST: begin
                    if (L > best_len || (L == best_len && substring_smaller(i, L))) begin
                        best_len <= L;
                        for (m = 0; m < 16; m = m + 1) begin
                            if (m < L) begin
                                best_substring[m] <= arr[i + m];
                            end else begin
                                best_substring[m] <= 8'd0;
                            end
                        end
                    end
                    found_repeated <= 1'b1;
                    state <= NEXT_J;
                end
                
                FINISHED: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    function automatic integer substring_smaller;
        input [4:0] start_idx;
        input [4:0] length;
        integer idx;
        begin
            substring_smaller = 0;
            for (idx = 0; idx < length; idx = idx + 1) begin
                if (arr[start_idx + idx] < best_substring[idx]) begin
                    substring_smaller = 1;
                    idx = length;
                end else if (arr[start_idx + idx] > best_substring[idx]) begin
                    idx = length;
                end
            end
        end
    endfunction

endmodule