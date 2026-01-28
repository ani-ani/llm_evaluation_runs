module k_color_tree_FSM(
    input clk,
    input rst_n,
    input start,
    input [2:0] N,
    input [15:0] k,
    input [15:0] P,
    output reg [15:0] result,
    output reg done
);
    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] START    = 3'd1;
    localparam [2:0] EXP_LOOP = 3'd2;
    localparam [2:0] MULT_LOOP= 3'd3;
    localparam [2:0] MOD_OP   = 3'd4;
    localparam [2:0] DONE_ST  = 3'd5;
    
    reg [2:0] state, next_state;
    
    // Internal registers
    reg [15:0] T;
    reg [15:0] exp_counter;
    reg final_mult;
    reg [15:0] multiplicand;
    reg [15:0] multiplier;
    reg [31:0] product;
    reg [31:0] mod_remainder;
    reg [5:0] mod_cycles;
    reg [2:0] N_reg;
    reg [15:0] k_reg;
    reg [15:0] P_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            T <= 16'd0;
            exp_counter <= 16'd0;
            final_mult <= 1'b0;
            multiplicand <= 16'd0;
            multiplier <= 16'd0;
            product <= 32'd0;
            mod_remainder <= 32'd0;
            mod_cycles <= 6'd0;
            N_reg <= 3'd0;
            k_reg <= 16'd0;
            P_reg <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= START;
                    end
                end
                
                START: begin
                    N_reg <= N;
                    k_reg <= k;
                    P_reg <= P;
                    T <= 16'd1;
                    exp_counter <= {13'd0, N} - 16'd1;
                    if (N == 3'd1) begin
                        final_mult <= 1'b1;
                        multiplicand <= k;
                        multiplier <= 16'd1;
                        state <= MULT_LOOP;
                    end else begin
                        final_mult <= 1'b0;
                        state <= EXP_LOOP;
                    end
                end
                
                EXP_LOOP: begin
                    multiplicand <= k_reg - 16'd1;
                    multiplier <= T;
                    state <= MULT_LOOP;
                end
                
                MULT_LOOP: begin
                    product <= multiplicand * multiplier;
                    mod_remainder <= multiplicand * multiplier;
                    mod_cycles <= 6'd0;
                    state <= MOD_OP;
                end
                
                MOD_OP: begin
                    if (mod_cycles < 6'd32) begin
                        if (mod_remainder >= ( {16'd0, P_reg} << (5'd31 - mod_cycles[4:0]) )) begin
                            mod_remainder <= mod_remainder - ( {16'd0, P_reg} << (5'd31 - mod_cycles[4:0]) );
                        end
                        mod_cycles <= mod_cycles + 6'd1;
                    end else begin
                        if (final_mult == 1'b0) begin
                            T <= mod_remainder[15:0];
                            exp_counter <= exp_counter - 16'd1;
                            if (exp_counter == 16'd1) begin
                                final_mult <= 1'b1;
                                multiplicand <= k_reg;
                                multiplier <= mod_remainder[15:0];
                                state <= MULT_LOOP;
                            end else begin
                                state <= EXP_LOOP;
                            end
                        end else begin
                            result <= mod_remainder[15:0];
                            state <= DONE_ST;
                        end
                    end
                end
                
                DONE_ST: begin
                    done <= 1'b1;
                    if (start) begin
                        done <= 1'b0;
                        state <= START;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule