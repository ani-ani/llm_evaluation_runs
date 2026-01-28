module unit_digit_product(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] a,
    input wire signed [7:0] b,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state;
    reg [7:0] abs_a;
    reg [7:0] abs_b;
    reg [7:0] unit_a;
    reg [7:0] unit_b;

    // Absolute value calculation
    always @(*) begin
        if (a[7]) begin
            abs_a = -a;
        end else begin
            abs_a = a;
        end

        if (b[7]) begin
            abs_b = -b;
        end else begin
            abs_b = b;
        end
    end

    // Unit digit extraction (mod 10)
    always @(*) begin
        unit_a = abs_a % 10;
        unit_b = abs_b % 10;
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    result <= unit_a * unit_b;
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