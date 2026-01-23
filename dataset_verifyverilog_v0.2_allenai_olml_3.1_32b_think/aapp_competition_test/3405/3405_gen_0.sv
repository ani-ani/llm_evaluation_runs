module digit_rotate_multiplier (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [31:0] x_fixed,
    output reg [31:0] result,
    output reg valid,
    output reg done
);

// Internal registers
reg [31:0] n_current;
reg [31:0] temp_product;
reg [31:0] temp_rotated;
reg [2:0] state;

parameter IDLE = 3'b000,
                CHECK = 3'b001,
                ROTATE = 3'b010,
                VERIFY = 3'b011,
                NEXT = 3'b100,
                DONE = 3'b101;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        n_current <= 100;
        temp_product <= 0;
        temp_rotated <=0;
        state <= IDLE;
        result <=0;
        valid <=0;
        done <=0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= CHECK;
                end else begin
                    state <= IDLE;
                end
            end
            CHECK: begin
                temp_product <= n_current * x_fixed >> 16;
                state <= ROTATE;
            end
            ROTATE: begin
                if (n_current < 1000) begin
                    temp_rotated <= (n_current % 100) * 10 + (n_current / 100);
                end else begin
                    temp_rotated <= (n_current % 1000) * 10 + (n_current / 1000);
                end
                state <= VERIFY;
            end
            VERIFY: begin
                if (temp_product == temp_rotated) begin
                    result <= n_current;
                    valid <=1;
                end
                state <= NEXT;
            end
            NEXT: begin
                n_current <= n_current + 1;
                if (n_current < 10000) begin
                    state <= CHECK;
                end else begin
                    state <= DONE;
                    done <=1;
                end
            end
            DONE: begin
                state <= DONE;
            end
        endcase
    end
end
endmodule