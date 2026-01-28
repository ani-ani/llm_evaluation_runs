module alu_sum(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n_in,
    output reg [7:0] result,
    output reg done
);

    // Registers
    reg [7:0] A, X, Y;
    reg [7:0] stack [0:15];
    reg [3:0] sp;

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT = 4'd1;
    localparam [3:0] ST_A = 4'd2;
    localparam [3:0] ST_X = 4'd3;
    localparam [3:0] PH_A = 4'd4;
    localparam [3:0] PH_X = 4'd5;
    localparam [3:0] AD = 4'd6;
    localparam [3:0] PL_Y = 4'd7;
    localparam [3:0] PH_Y = 4'd8;
    localparam [3:0] AD2 = 4'd9;
    localparam [3:0] AD3 = 4'd10;
    localparam [3:0] PL_A = 4'd11;
    localparam [3:0] DI_A = 4'd12;
    localparam [3:0] DONE = 4'd13;

    reg [3:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd128;

    // Internal signals
    reg [7:0] temp1, temp2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            A <= 8'd0;
            X <= 8'd0;
            Y <= 8'd0;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            sp <= 4'd0;
            for (integer i = 0; i < 16; i = i + 1) begin
                stack[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    A <= 8'd1;
                    X <= 8'd1;
                    state <= ST_A;
                end

                ST_A: begin
                    A <= 8'd1;
                    state <= ST_X;
                end

                ST_X: begin
                    X <= 8'd1;
                    state <= PH_A;
                end

                PH_A: begin
                    stack[sp] <= A;
                    sp <= sp + 4'd1;
                    state <= PH_X;
                end

                PH_X: begin
                    stack[sp] <= X;
                    sp <= sp + 4'd1;
                    state <= AD;
                end

                AD: begin
                    temp1 <= stack[sp - 4'd1];
                    temp2 <= stack[sp - 4'd2];
                    stack[sp - 4'd2] <= temp1 + temp2;
                    sp <= sp - 4'd1;
                    state <= PL_Y;
                end

                PL_Y: begin
                    Y <= stack[sp - 4'd1];
                    sp <= sp - 4'd1;
                    state <= PH_Y;
                end

                PH_Y: begin
                    stack[sp] <= Y;
                    sp <= sp + 4'd1;
                    state <= AD2;
                end

                AD2: begin
                    temp1 <= stack[sp - 4'd1];
                    temp2 <= stack[sp - 4'd2];
                    stack[sp - 4'd2] <= temp1 + temp2;
                    sp <= sp - 4'd1;
                    state <= AD3;
                end

                AD3: begin
                    temp1 <= stack[sp - 4'd1];
                    temp2 <= stack[sp - 4'd2];
                    stack[sp - 4'd2] <= temp1 + temp2;
                    sp <= sp - 4'd1;
                    state <= PL_A;
                end

                PL_A: begin
                    A <= stack[sp - 4'd1];
                    sp <= sp - 4'd1;
                    state <= DI_A;
                end

                DI_A: begin
                    result <= A;
                    done <= 1'b1;
                    state <= DONE;
                end

                DONE: begin
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase

            cycle_count <= cycle_count + 8'd1;
            if (cycle_count >= MAX_CYCLES) begin
                state <= IDLE;
            end
        end
    end

endmodule