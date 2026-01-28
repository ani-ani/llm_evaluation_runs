module cookie_distribution(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [9:0] N,
    input wire [9:0] A,
    input wire [9:0] B,
    input wire [9:0] C,
    output reg [21:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALC = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state;
    reg [21:0] Sum;
    reg [9:0] MaxVal;
    reg [11:0] Rest;
    reg [11:0] Threshold;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 22'd0;
            done <= 1'b0;
            Sum <= 22'd0;
            MaxVal <= 10'd0;
            Rest <= 12'd0;
            Threshold <= 12'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CALC;
                    end
                end

                CALC: begin
                    // Calculate Sum = A + B + C
                    Sum <= {12'd0, A} + {12'd0, B} + {12'd0, C};

                    // Find MaxVal = max(A, max(B, C))
                    MaxVal <= (A > B) ? ((A > C) ? A : C) : ((B > C) ? B : C);

                    // Calculate Rest = Sum - MaxVal
                    Rest <= Sum - {12'd0, MaxVal};

                    // Calculate Threshold = Rest + N
                    Threshold <= Rest + {12'd0, N};

                    // Determine result
                    if (MaxVal > Threshold) begin
                        result <= (Rest * 2'd2) + {22'd0, N};
                    end else begin
                        result <= Sum;
                    end

                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule