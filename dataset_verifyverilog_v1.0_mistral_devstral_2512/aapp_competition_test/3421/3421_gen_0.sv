module max_density_subsequence (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] k,
    input wire [3:0] L,
    input wire [15:0] str,
    output reg [4:0] start_index,
    output reg [4:0] length,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] LOOP_I = 3'd2;
    localparam [2:0] LOOP_J = 3'd3;
    localparam [2:0] UPDATE = 3'd4;
    localparam [2:0] DONE = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [3:0] i, j;
    reg [4:0] count;
    reg [4:0] best_start, best_len, best_ones;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            start_index <= 5'd0;
            length <= 5'd0;
            i <= 4'd0;
            j <= 4'd0;
            count <= 5'd0;
            best_start <= 5'd0;
            best_len <= 5'd0;
            best_ones <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    i <= 4'd0;
                    j <= 4'd0;
                    count <= 5'd0;
                    best_start <= 5'd0;
                    best_len <= 5'd0;
                    best_ones <= 5'd0;
                    state <= LOOP_I;
                end

                LOOP_I: begin
                    if (i >= L) begin
                        state <= DONE;
                    end else begin
                        j <= i;
                        count <= 5'd0;
                        state <= LOOP_J;
                    end
                end

                LOOP_J: begin
                    count <= count + str[j];
                    if (j - i + 1 >= k) begin
                        state <= UPDATE;
                    end else begin
                        j <= j + 1'b1;
                        if (j >= L) begin
                            i <= i + 1'b1;
                            state <= LOOP_I;
                        end else begin
                            state <= LOOP_J;
                        end
                    end
                end

                UPDATE: begin
                    if (best_len == 5'd0) begin
                        best_start <= i;
                        best_len <= j - i + 1'b1;
                        best_ones <= count;
                    end else if (count * best_len > best_ones * (j - i + 1'b1)) begin
                        best_start <= i;
                        best_len <= j - i + 1'b1;
                        best_ones <= count;
                    end
                    j <= j + 1'b1;
                    if (j >= L) begin
                        i <= i + 1'b1;
                        state <= LOOP_I;
                    end else begin
                        state <= LOOP_J;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    start_index <= best_start + 1'b1;
                    length <= best_len;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule