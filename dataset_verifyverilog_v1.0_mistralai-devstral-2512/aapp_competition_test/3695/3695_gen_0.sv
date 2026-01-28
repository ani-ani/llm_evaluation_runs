module max_bowls(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] n,
    input wire [15:0] T_limit,
    input wire [15:0] t_arr [0:63],
    output reg [6:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    reg [1:0] state;
    reg [5:0] i;
    reg [6:0] count;

    // Latch inputs
    reg [5:0] n_latched;
    reg [15:0] T_limit_latched;
    reg [15:0] t_arr_latched [0:63];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 6'd0;
            count <= 7'd0;
            result <= 7'd0;
            done <= 1'b0;
            n_latched <= 6'd0;
            T_limit_latched <= 16'd0;
            integer j;
            for (j = 0; j < 64; j = j + 1) begin
                t_arr_latched[j] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESS;
                        i <= 6'd0;
                        count <= 7'd0;
                        n_latched <= n;
                        T_limit_latched <= T_limit;
                        integer j;
                        for (j = 0; j < 64; j = j + 1) begin
                            t_arr_latched[j] <= t_arr[j];
                        end
                    end
                end

                PROCESS: begin
                    if (i < n_latched) begin
                        reg [15:0] pos;
                        reg [15:0] wait;
                        reg [15:0] finish;
                        pos = i + 1;
                        if (t_arr_latched[i] > pos) begin
                            wait = t_arr_latched[i] - pos;
                        end else begin
                            wait = 16'd0;
                        end
                        finish = pos + wait;
                        if (finish < T_limit_latched) begin
                            count = count + 7'd1;
                        end
                        i = i + 6'd1;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= count;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule