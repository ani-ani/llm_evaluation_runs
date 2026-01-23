module color_path (
    input clk,
    input rst_n,
    input start,
    input [15:0] n_in,
    output reg [15:0] result,
    output reg done
);
    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] CHECK_DIV = 3'd2;
    localparam [2:0] POWER_LOOP= 3'd3;
    localparam [2:0] DONE_ST   = 3'd4;

    reg [2:0] state, next_state;
    reg [15:0] n_reg;
    reg [15:0] divisor_reg;
    reg [15:0] temp_power;
    wire [15:0] remainder = n_reg % divisor_reg;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            n_reg <= 16'd0;
            divisor_reg <= 16'd0;
            temp_power <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= n_in;
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    if (n_reg == 16'd1) begin
                        result <= 16'd1;
                        state <= DONE_ST;
                    end else begin
                        divisor_reg <= 16'd2;
                        state <= CHECK_DIV;
                    end
                end
                
                CHECK_DIV: begin
                    if (divisor_reg > 16'd256) begin
                        result <= n_reg;
                        state <= DONE_ST;
                    end else if (remainder == 16'd0) begin
                        temp_power <= n_reg;
                        state <= POWER_LOOP;
                    end else begin
                        divisor_reg <= divisor_reg + 16'd1;
                    end
                end
                
                POWER_LOOP: begin
                    if (temp_power % divisor_reg == 16'd0) begin
                        temp_power <= temp_power / divisor_reg;
                    end else begin
                        if (temp_power == 16'd1) begin
                            result <= divisor_reg;
                        end else begin
                            result <= 16'd1;
                        end
                        state <= DONE_ST;
                    end
                end
                
                DONE_ST: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule