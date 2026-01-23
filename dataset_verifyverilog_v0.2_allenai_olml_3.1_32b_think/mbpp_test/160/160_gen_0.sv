module diophantine_solver (
    input clk,
    input rst_n, // active low
    input start,
    input [7:0] a,
    input [7:0] b,
    input [7:0] n,
    output reg [7:0] x,
    output reg [7:0] y,
    output reg valid,
    output reg done
);

reg [2:0] state;
reg [7:0] current_x;

wire [2:0] next_state;
wire [7:0] y_val;
wire increment_x;
wire [15:0] temp;
wire [15:0] rem;
wire [15:0] n_16;

assign n_16 = {16{0}} n;
assign temp = a * current_x;
assign rem = n_16 - temp;

always_comb begin
    case (state)
        3'b000: // IDLE
            if (start)
                next_state = 3'b001;
            else
                next_state = 3'b000;
        3'b001: // CHECK
            if (current_x > 15)
                next_state = 3'b100;
            else
                next_state = 3'b010;
        3'b010: // CALC
            if (rem < 0)
                next_state = 3'b100;
            else if (rem % b == 0)
                next_state = 3'b011;
            else begin
                next_state = 3'b001;
                increment_x = 1'b1;
            end
        3'b011: // FOUND
            next_state = 3'b011;
            y_val = (n_16 - temp) / b;
        3'b100: // NOT_FOUND
            next_state = 3'b100;
            y_val = 8'b0;
    endcase
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= 3'b000;
        current_x <= 8'b000;
        x <= 8'b000;
        y <= 8'b000;
        valid <= 1'b0;
        done <= 1'b0;
    end else begin
        state <= next_state;

        if (increment_x)
            current_x <= current_x + 1;
        else
            current_x <= current_x;

        x <= current_x;
        valid <= (state == 3'b011);
        done <= (state == 3'b011 || state == 3'b100);
        y <= y_val;
    end
end

endmodule