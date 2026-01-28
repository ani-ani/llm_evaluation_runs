module quotations_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] n,
    input wire [1:0] a_0,
    input wire [1:0] a_1,
    input wire [1:0] a_2,
    output reg [1:0] max_k,
    output reg done
);

    // State declarations
    localparam [1:0] S_IDLE    = 2'd0;
    localparam [1:0] S_CHECK   = 2'd1;
    localparam [1:0] S_DONE    = 2'd2;

    // Registers
    reg [1:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_k <= 2'b00;
            done <= 1'b0;
            state <= S_IDLE;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        max_k <= 2'b00;
                        state <= S_CHECK;
                    end
                end

                S_CHECK: begin
                    // Check for k=2 (2-quotation)
                    // Conditions: n == 3, a_0 >= 2, a_2 >= 2, a_1 == 1
                    if ((n == 2'd3) && (a_0 >= 2'd2) && (a_2 >= 2'd2) && (a_1 == 2'd1)) begin
                        max_k <= 2'd2;
                    end
                    // Check for k=1 (1-quotation)
                    // Conditions: n == 2, a_0 == 1, a_1 == 1
                    else if ((n == 2'd2) && (a_0 == 2'd1) && (a_1 == 2'd1)) begin
                        max_k <= 2'd1;
                    end
                    // else max_k remains 00
                    state <= S_DONE;
                end

                S_DONE: begin
                    done <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule