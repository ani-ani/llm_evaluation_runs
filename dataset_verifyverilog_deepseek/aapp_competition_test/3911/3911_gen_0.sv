module slime_merger(
    input clk,
    input rst_n,
    input [2:0] n,
    input start,
    output reg [2:0] elem_0,
    output reg [2:0] elem_1,
    output reg [2:0] elem_2,
    output reg [2:0] elem_3,
    output reg done
);

    localparam [1:0] IDLE   = 2'b00;
    localparam [1:0] PROCESS = 2'b01;
    localparam [1:0] DONE   = 2'b10;

    reg [1:0] state_reg, state_next;
    reg [2:0] stack_reg [0:3];
    reg [2:0] stack_next [0:3];
    reg [2:0] stack_size_reg, stack_size_next;
    reg [2:0] counter_reg, counter_next;
    integer i;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg <= IDLE;
            stack_reg[0] <= 0;
            stack_reg[1] <= 0;
            stack_reg[2] <= 0;
            stack_reg[3] <= 0;
            stack_size_reg <= 0;
            counter_reg <= 0;
            done <= 0;
            elem_0 <= 0;
            elem_1 <= 0;
            elem_2 <= 0;
            elem_3 <= 0;
        end else begin
            state_reg <= state_next;
            stack_reg[0] <= stack_next[0];
            stack_reg[1] <= stack_next[1];
            stack_reg[2] <= stack_next[2];
            stack_reg[3] <= stack_next[3];
            stack_size_reg <= stack_size_next;
            counter_reg <= counter_next;
            done <= (state_next == DONE);

            elem_0 <= (stack_size_next > 0) ? stack_next[0] : 3'b0;
            elem_1 <= (stack_size_next > 1) ? stack_next[1] : 3'b0;
            elem_2 <= (stack_size_next > 2) ? stack_next[2] : 3'b0;
            elem_3 <= (stack_size_next > 3) ? stack_next[3] : 3'b0;
        end
    end

    always_comb begin
        state_next = state_reg;
        for (i=0; i<4; i=i+1) stack_next[i] = stack_reg[i];
        stack_size_next = stack_size_reg;
        counter_next = counter_reg;

        case (state_reg)
            IDLE: begin
                if (start) begin
                    stack_next[0] = 3'b1;
                    for (i=1; i<4; i=i+1) stack_next[i] = 3'b0;
                    stack_size_next = 3'd1;
                    counter_next = 3'd1;
                    if (n == 3'd1) begin
                        state_next = DONE;
                    end else begin
                        state_next = PROCESS;
                    end
                end
            end
            PROCESS: begin
                if (counter_reg < n) begin
                    counter_next = counter_reg + 1;
                    if (stack_size_reg < 4) begin
                        stack_next[stack_size_reg] = 3'b1;
                    end
                    stack_size_next = stack_size_reg + 1;

                    for (i=0; i<3; i=i+1) begin
                        if (stack_size_next > 1 && stack_next[stack_size_next-1] == stack_next[stack_size_next-2]) begin
                            stack_next[stack_size_next-2] = stack_next[stack_size_next-2] + 1;
                            stack_size_next = stack_size_next - 1;
                            if (stack_size_next < 4) stack_next[stack_size_next] = 3'b0;
                        end
                    end
                    if (counter_next == n) state_next = DONE;
                end else begin
                    state_next = DONE;
                end
            end
            DONE: begin
                state_next = IDLE;
            end
            default: state_next = IDLE;
        endcase
    end

endmodule