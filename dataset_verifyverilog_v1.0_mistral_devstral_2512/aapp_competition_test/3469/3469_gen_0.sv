module gon_probability_generic #(
    parameter MAX_STATES = 16,
    parameter STATE_BITS = 4,
    parameter ITERATIONS = 256
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] p,
    input wire [3:0] num_states,
    input wire [3:0] next_H [0:MAX_STATES-1],
    input wire [3:0] next_T [0:MAX_STATES-1],
    output reg [31:0] result,
    output reg done
);

    localparam [31:0] ONE = 32'h00010000;
    reg [31:0] p_inv;
    reg [31:0] state_val [0:MAX_STATES-1];
    reg [31:0] new_val [0:MAX_STATES-1];
    reg [STATE_BITS-1:0] idx;
    reg [7:0] iter;
    reg busy;

    function automatic [31:0] mul(input [31:0] a, input [31:0] b);
        reg [63:0] tmp;
        tmp = a * b;
        mul = tmp[47:16];
    endfunction

    function automatic [31:0] next_val(input [3:0] nxt);
        case (nxt)
            4'd8:  next_val = ONE;
            4'd9:  next_val = 32'd0;
            4'd10: next_val = 32'd0;
            default: next_val = state_val[nxt];
        endcase
    endfunction

    assign p_inv = ONE - p;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 0;
            done <= 0;
            result <= 0;
            iter <= 0;
            idx <= 0;
            for (integer i = 0; i < MAX_STATES; i = i + 1) begin
                state_val[i] <= 0;
            end
        end else begin
            if (start && !busy) begin
                for (integer i = 0; i < MAX_STATES; i = i + 1) begin
                    state_val[i] <= 0;
                end
                iter <= 0;
                idx <= 0;
                busy <= 1;
                done <= 0;
            end else if (busy) begin
                if (iter < ITERATIONS) begin
                    if (idx < num_states) begin
                        new_val[idx] <= mul(p, next_val(next_H[idx])) + mul(p_inv, next_val(next_T[idx]));
                        idx <= idx + 1;
                    end else begin
                        for (integer i = 0; i < MAX_STATES; i = i + 1) begin
                            state_val[i] <= new_val[i];
                        end
                        idx <= 0;
                        iter <= iter + 1;
                    end
                end else begin
                    result <= state_val[0];
                    done <= 1;
                    busy <= 0;
                end
            end else begin
                done <= 0;
            end
        end
    end
endmodule