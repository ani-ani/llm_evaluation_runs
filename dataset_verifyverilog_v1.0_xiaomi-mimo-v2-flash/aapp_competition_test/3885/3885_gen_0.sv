module mst_cost_calculator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [16:0] n,
    output reg [16:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    // State register
    reg [1:0] state;
    reg [16:0] temp_result;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 17'd0;
            temp_result <= 17'd0;
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
                    // Calculate (n - 1) >> 1
                    // This implements integer division by 2
                    temp_result <= (n - 17'd1) >> 1;
                    state <= FINISH;
                end

                FINISH: begin
                    // Output the result and pulse done
                    result <= temp_result;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule