module count_ones (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [7:0] l,
    input [7:0] r,
    output reg [15:0] count,
    output reg done
);

    // State encoding
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] DONE = 2'd3;

    reg [1:0] state;
    reg [7:0] n_reg, l_reg, r_reg, current_i;
    reg [3:0] msb_index;  // 0-based from LSB
    wire [3:0] ctz;
    wire [3:0] pos;
    wire bit;

    // Compute number of trailing zeros for current_i
    function [3:0] ctz_func;
        input [7:0] val;
        begin
            ctz_func = 0;
            if (val[0]) ctz_func = 0;
            else if (val[1]) ctz_func = 1;
            else if (val[2]) ctz_func = 2;
            else if (val[3]) ctz_func = 3;
            else if (val[4]) ctz_func = 4;
            else if (val[5]) ctz_func = 5;
            else if (val[6]) ctz_func = 6;
            else if (val[7]) ctz_func = 7;
        end
    endfunction

    assign ctz = ctz_func(current_i);
    assign pos = msb_index - ctz;  // will be >=0 when n!=0
    assign bit = n_reg[pos];  // pos is between 0 and 7 when n!=0

    // Find msb index of n
    always @(*) begin
        msb_index = 0;
        if (n[7]) msb_index = 7;
        else if (n[6]) msb_index = 6;
        else if (n[5]) msb_index = 5;
        else if (n[4]) msb_index = 4;
        else if (n[3]) msb_index = 3;
        else if (n[2]) msb_index = 2;
        else if (n[1]) msb_index = 1;
        else if (n[0]) msb_index = 0;
        // for n==0, msb_index remains 0, but we handle separately
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            count <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        n_reg <= n;
                        l_reg <= l;
                        r_reg <= r;
                        if (n == 8'd0) begin
                            count <= 0;
                            state <= DONE;
                        end else begin
                            count <= 0;
                            current_i <= l;
                            state <= CHECK;
                        end
                    end
                end

                CHECK: begin
                    if (current_i <= r_reg) begin
                        state <= COMPUTE;
                    end else begin
                        state <= DONE;
                    end
                end

                COMPUTE: begin
                    // Add bit if n!=0 (already ensured here)
                    count <= count + {15'd0, bit};
                    current_i <= current_i + 1;
                    state <= CHECK;
                end

                DONE: begin
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule