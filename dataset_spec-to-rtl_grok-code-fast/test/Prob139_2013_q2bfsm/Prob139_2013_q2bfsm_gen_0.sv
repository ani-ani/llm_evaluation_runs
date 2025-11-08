typedef enum reg [2:0] {S_A, S_F_SET, S_MONITOR_X, S_G_SET, S_MONITOR_Y, S_PERM_G1, S_PERM_G0} state_t;
module TopModule(
    input clk,
    input resetn,
    input x,
    input y,
    output reg f,
    output reg g
);
    state_t state;
    reg [2:0] x_shift;
    reg [1:0] y_counter;
    
    always @(posedge clk) begin
        if (!resetn) begin
            state <= S_A;
            x_shift <= 3'b000;
            y_counter <= 2'b00;
            f <= 1'b0;
            g <= 1'b0;
        end else begin
            case (state)
                S_A: begin
                    state <= S_F_SET;
                    f <= 1'b0;
                    g <= 1'b0;
                end
                S_F_SET: begin
                    state <= S_MONITOR_X;
                    f <= 1'b1;
                    g <= 1'b0;
                    x_shift <= 3'b000;
                end
                S_MONITOR_X: begin
                    wire [2:0] new_shift = {x_shift[1:0], x};
                    x_shift <= new_shift;
                    if (new_shift == 3'b101) begin
                        state <= S_G_SET;
                    end else begin
                        state <= S_MONITOR_X;
                    end
                    f <= 1'b0;
                    g <= 1'b0;
                end
                S_G_SET: begin
                    state <= S_MONITOR_Y;
                    f <= 1'b0;
                    g <= 1'b1;
                    y_counter <= 2'b00;
                end
                S_MONITOR_Y: begin
                    f <= 1'b0;
                    g <= 1'b1;
                    if (y) begin
                        state <= S_PERM_G1;
                    end else begin
                        if (y_counter < 2) begin
                            y_counter <= y_counter + 1;
                            state <= S_MONITOR_Y;
                        end else begin
                            state <= S_PERM_G0;
                        end
                    end
                end
                S_PERM_G1: begin
                    f <= 1'b0;
                    g <= 1'b1;
                end
                S_PERM_G0: begin
                    f <= 1'b0;
                    g <= 1'b0;
                end
            endcase
        end
    end
endmodule