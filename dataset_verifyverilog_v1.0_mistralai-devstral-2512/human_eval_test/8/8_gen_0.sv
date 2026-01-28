module ArrayProcessor(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:15],
    input [3:0] len,
    output reg [15:0] sum_out,
    output reg [15:0] prod_out,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [15:0] sum_reg;
    reg [15:0] prod_reg;
    reg [3:0] counter;
    reg [31:0] prod_temp;
    reg overflow;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sum_reg <= 16'd0;
            prod_reg <= 16'd0;
            counter <= 4'd0;
            sum_out <= 16'd0;
            prod_out <= 16'd0;
            done <= 1'b0;
            overflow <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        sum_reg <= 16'd0;
                        prod_reg <= 16'd1;
                        counter <= 4'd0;
                        overflow <= 1'b0;
                    end
                end

                COMPUTE: begin
                    if (counter < len) begin
                        // Sum computation
                        sum_reg <= sum_reg + arr[counter];

                        // Product computation with overflow check
                        prod_temp <= prod_reg * arr[counter];
                        if (prod_temp[31:16] != 16'd0 && !overflow) begin
                            overflow <= 1'b1;
                            prod_reg <= 16'hFFFF;
                        end else if (!overflow) begin
                            prod_reg <= prod_temp[15:0];
                        end

                        counter <= counter + 4'd1;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    sum_out <= sum_reg;
                    prod_out <= prod_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule