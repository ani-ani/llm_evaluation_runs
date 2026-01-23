module max_sub_rectangle (
    input clk,
    input rst_n,
    input start,
    input [7:0] N,
    input [7:0] M,
    input [7:0] x,
    input [7:0] y,
    input [7:0] a,
    input [7:0] b,
    output reg [7:0] x1,
    output reg [7:0] y1,
    output reg [7:0] x2,
    output reg [7:0] y2,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        CALC_S_MAX,
        FIND_RECT,
        OPTIMIZE,
        DONE
    } state_t;

    state_t state;
    reg [7:0] s;
    reg [7:0] s_max;
    reg [7:0] w;
    reg [7:0] h;
    reg [7:0] x_low;
    reg [7:0] y_low;
    reg [7:0] x_high;
    reg [7:0] y_high;
    reg [7:0] ideal_x1;
    reg [7:0] ideal_y1;
    reg [7:0] counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            x1 <= 0;
            y1 <= 0;
            x2 <= 0;
            y2 <= 0;
            s <= 0;
            s_max <= 0;
            w <= 0;
            h <= 0;
            x_low <= 0;
            y_low <= 0;
            x_high <= 0;
            y_high <= 0;
            ideal_x1 <= 0;
            ideal_y1 <= 0;
            counter <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= CALC_S_MAX;
                        counter <= 1;
                        s_max <= 0;
                    end
                end
                CALC_S_MAX: begin
                    w <= a * counter;
                    h <= b * counter;
                    if (w <= N && h <= M) begin
                        s_max <= counter;
                        counter <= counter + 1;
                    end else begin
                        if (s_max == 0) begin
                            s_max <= 1;
                        end
                        state <= FIND_RECT;
                        s <= s_max;
                    end
                end
                FIND_RECT: begin
                    w <= a * s;
                    h <= b * s;
                    x_low <= (x >= w) ? (x - w) : 0;
                    x_high <= (x <= (N - w)) ? x : (N - w);
                    y_low <= (y >= h) ? (y - h) : 0;
                    y_high <= (y <= (M - h)) ? y : (M - h);
                    if (x_low <= x_high && y_low <= y_high) begin
                        state <= OPTIMIZE;
                    end else if (s > 1) begin
                        s <= s - 1;
                    end else begin
                        state <= DONE;
                        x1 <= 0;
                        y1 <= 0;
                        x2 <= 0;
                        y2 <= 0;
                        done <= 1;
                    end
                end
                OPTIMIZE: begin
                    ideal_x1 <= x - (w >> 1);
                    ideal_y1 <= y - (h >> 1);
                    x1 <= (ideal_x1 < x_low) ? x_low : ((ideal_x1 > x_high) ? x_high : ideal_x1);
                    y1 <= (ideal_y1 < y_low) ? y_low : ((ideal_y1 > y_high) ? y_high : ideal_y1);
                    x2 <= x1 + w;
                    y2 <= y1 + h;
                    state <= DONE;
                    done <= 1;
                end
                DONE: begin
                    if (start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule