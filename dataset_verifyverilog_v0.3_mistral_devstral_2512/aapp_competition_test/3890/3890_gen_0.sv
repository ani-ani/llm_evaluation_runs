module house_puzzle (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [9:0] n,
    input wire [3:0] k,
    output reg [29:0] result,
    output reg done
);
    
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    reg [29:0] a_result;
    reg [29:0] b_result;
    reg [29:0] exp_base;
    reg [29:0] exp_exp;
    reg [29:0] exp_result;
    reg [29:0] mul_a;
    reg [29:0] mul_b;
    
    wire [59:0] mul_product;
    wire [29:0] mul_result;
    
    assign mul_product = mul_a * mul_b;
    assign mul_result = mul_product % 1000000007;
    
    wire [29:0] k_pow;
    assign k_pow = (k == 4'd1) ? 30'd1 :
                   (k == 4'd2) ? 30'd2 :
                   (k == 4'd3) ? 30'd9 :
                   (k == 4'd4) ? 30'd64 :
                   (k == 4'd5) ? 30'd625 :
                   (k == 4'd6) ? 30'd7776 :
                   (k == 4'd7) ? 30'd117649 :
                   (k == 4'd8) ? 30'd2097152 : 30'd0;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 30'd0;
            a_result <= 30'd0;
            b_result <= 30'd0;
            exp_base <= 30'd0;
            exp_exp <= 30'd0;
            exp_result <= 30'd0;
            mul_a <= 30'd0;
            mul_b <= 30'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        if (k == 4'd0) begin
                            result <= 30'd0;
                            done <= 1'b1;
                        end else begin
                            state <= COMPUTE;
                        end
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (cycle_count == 8'd1) begin
                        a_result <= k_pow;
                        exp_base <= (n - k);
                        exp_exp <= (n - k);
                        exp_result <= 30'd1;
                    end else if (cycle_count == 8'd2) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            mul_a <= exp_result;
                            mul_b <= exp_base;
                        end else begin
                            mul_a <= exp_base;
                            mul_b <= exp_base;
                        end
                    end else if (cycle_count == 8'd3) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd4) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd5) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd6) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd7) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd8) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd9) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd10) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd11) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd12) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd13) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd14) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd15) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd16) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd17) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd18) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd19) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd20) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd21) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd22) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd23) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd24) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd25) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd26) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd27) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd28) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd29) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd30) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd31) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd32) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd33) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd34) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd35) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd36) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd37) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd38) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd39) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd40) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd41) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd42) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd43) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd44) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd45) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd46) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd47) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd48) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd49) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd50) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd51) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd52) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd53) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd54) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd55) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd56) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd57) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd58) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd59) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd60) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd61) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd62) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd63) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd64) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd65) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd66) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd67) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd68) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd69) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd70) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd71) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd72) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd73) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd74) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd75) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd76) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd77) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd78) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd79) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd80) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd81) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd82) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd83) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd84) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd85) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd86) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd87) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd88) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd89) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd90) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd91) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd92) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd93) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd94) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd95) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd96) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd97) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd98) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd99) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end else if (cycle_count == 8'd100) begin
                        if (exp_exp == 0) begin
                            b_result <= exp_result;
                        end else if (exp_exp[0]) begin
                            exp_result <= mul_result;
                        end else begin
                            exp_base <= mul_result;
                            exp_exp <= exp_exp >> 1;
                        end
                    end
                    
                    if (cycle_count >= MAX_CYCLES || (exp_exp == 0 && cycle_count > 8'd1)) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    mul_a <= a_result;
                    mul_b <= b_result;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    always @(posedge clk) begin
        if (state == FINISH) begin
            result <= mul_result;
            done <= 1'b1;
        end
    end
endmodule