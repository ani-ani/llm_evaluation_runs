module coin_game (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [6:0] n,
    input wire [9:0] a [0:99],
    output reg signed [19:0] result,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COPY = 3'd1;
    localparam [2:0] COMP = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    localparam [2:0] ERROR = 3'd4;

    reg [2:0] state;
    reg signed [15:0] mem [0:99];
    reg [6:0] x;
    reg signed [19:0] total_moves;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 20'd0;
            x <= 7'd0;
            total_moves <= 20'd0;
            cycle_count <= 8'd0;
            for (i = 0; i < 100; i = i + 1) begin
                mem[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        if (n == 7'd1 || n[0] == 1'b0) begin
                            state <= ERROR;
                        end else begin
                            state <= COPY;
                            x <= n >> 1;
                            total_moves <= 20'd0;
                        end
                    end
                end

                COPY: begin
                    for (i = 0; i < 100; i = i + 1) begin
                        if (i < n)
                            mem[i] <= a[i];
                        else
                            mem[i] <= 16'd0;
                    end
                    state <= COMP;
                end

                COMP: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (x >= 7'd1 && cycle_count < MAX_CYCLES) begin
                        if (2*x <= n && 2*x + 1 <= n) begin
                            if (mem[2*x - 1] > mem[2*x]) begin
                                total_moves <= total_moves + mem[2*x - 1];
                                mem[x - 1] <= mem[x - 1] - mem[2*x - 1];
                            end else begin
                                total_moves <= total_moves + mem[2*x];
                                mem[x - 1] <= mem[x - 1] - mem[2*x];
                            end
                        end
                        x <= x - 7'd1;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    if (mem[0] > 16'd0)
                        result <= total_moves + mem[0];
                    else
                        result <= total_moves;
                    done <= 1'b1;
                    state <= IDLE;
                end

                ERROR: begin
                    result <= 20'sd-1;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule