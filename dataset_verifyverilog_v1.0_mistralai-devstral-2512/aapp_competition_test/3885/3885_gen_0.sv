module SchoolCostCalculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [16:0] n,
    output reg [16:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [16:0] temp_result;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 17'd0;
            done <= 1'b0;
            temp_result <= 17'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Calculate (n - 1) / 2 using right shift
                    if (n == 17'd0) begin
                        temp_result <= 17'd0;
                    end else begin
                        temp_result <= (n - 17'd1) >> 1;
                    end
                    state <= FINISH;
                end
                
                FINISH: begin
                    result <= temp_result;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule