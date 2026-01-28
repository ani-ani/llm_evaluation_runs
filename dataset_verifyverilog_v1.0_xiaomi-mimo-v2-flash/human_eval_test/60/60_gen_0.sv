module SumCalculator(
    input clk,
    input rst_n,
    input start,
    input [7:0] n_in,
    output reg [15:0] result,
    output reg done
);
    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALC = 2'd1;
    
    reg [1:0] state;
    reg start_dly;
    wire start_pulse;
    
    // Edge detection for start pulse
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_dly <= 1'b0;
        end else begin
            start_dly <= start;
        end
    end
    
    assign start_pulse = start && !start_dly;
    
    // Combinational calculation
    reg [15:0] n_plus_one;
    reg [15:0] n_mult_np1;
    
    always @(*) begin
        n_plus_one = n_in + 8'd1;
        n_mult_np1 = n_in * n_plus_one;
    end
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start_pulse) begin
                        result <= n_mult_np1 >> 1;  // Division by 2
                        done <= 1'b1;
                        state <= CALC;
                    end
                end
                CALC: begin
                    done <= 1'b0;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule