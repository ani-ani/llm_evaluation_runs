module sum_odd_range (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] l,
    input wire [15:0] r,
    output reg [31:0] result,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALC_SUM_R = 2'd1;
    localparam [1:0] CALC_SUM_L = 2'd2;
    localparam [1:0] FINISH = 2'd3;
    
    reg [1:0] state;
    reg [1:0] calc_step;
    reg [31:0] sum_r;
    reg [31:0] sum_l;
    reg [15:0] l_reg;
    reg [15:0] r_reg;
    reg [15:0] n_temp;
    reg [15:0] terms;
    reg [31:0] terms_sq;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            sum_r <= 32'd0;
            sum_l <= 32'd0;
            calc_step <= 2'd0;
            l_reg <= 16'd0;
            r_reg <= 16'd0;
            n_temp <= 16'd0;
            terms <= 16'd0;
            terms_sq <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        l_reg <= l;
                        r_reg <= r;
                        n_temp <= r_reg;
                        state <= CALC_SUM_R;
                        calc_step <= 2'd0;
                    end
                end
                
                CALC_SUM_R: begin
                    case (calc_step)
                        2'd0: begin
                            terms <= (n_temp + 16'd1) >> 1;
                            calc_step <= 2'd1;
                        end
                        2'd1: begin
                            terms_sq <= terms * terms;
                            calc_step <= 2'd2;
                        end
                        2'd2: begin
                            sum_r <= terms_sq;
                            if (l_reg > 16'd1) begin
                                n_temp <= l_reg - 16'd1;
                            end else begin
                                n_temp <= 16'd0;
                            end
                            state <= CALC_SUM_L;
                            calc_step <= 2'd0;
                        end
                    endcase
                end
                
                CALC_SUM_L: begin
                    case (calc_step)
                        2'd0: begin
                            if (n_temp == 16'd0) begin
                                sum_l <= 32'd0;
                                state <= FINISH;
                            end else begin
                                terms <= (n_temp + 16'd1) >> 1;
                                calc_step <= 2'd1;
                            end
                        end
                        2'd1: begin
                            terms_sq <= terms * terms;
                            calc_step <= 2'd2;
                        end
                        2'd2: begin
                            sum_l <= terms_sq;
                            state <= FINISH;
                        end
                    endcase
                end
                
                FINISH: begin
                    result <= sum_r - sum_l;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule