module CheetahMinPack #(
    parameter WIDTH = 8,
    parameter STEPS = 257,
    parameter SCALE = 256
)(
    input clk,
    input rst_n,
    input start,
    input [WIDTH-1:0] t0, t1, t2,
    input [WIDTH-1:0] v0, v1, v2,
    output reg [15:0] result,
    output reg done
);

    // Declare states with explicit widths
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] INIT = 2'd1;
    localparam [1:0] LOOP = 2'd2;
    localparam [1:0] DONE_ST = 2'd3;
    
    reg [1:0] state, next_state;
    reg [31:0] T_reg;
    reg [31:0] min_pack_reg;
    reg [8:0] counter;  // 9 bits for STEPS=257
    
    // Combinational calculations
    wire [WIDTH-1:0] max_t_comb = (t0 > t1) ? ((t0 > t2) ? t0 : t2) : ((t1 > t2) ? t1 : t2);
    wire [31:0] t0_scaled = {t0, 8'd0};
    wire [31:0] t1_scaled = {t1, 8'd0};
    wire [31:0] t2_scaled = {t2, 8'd0};
    
    wire [31:0] D0 = T_reg - t0_scaled;
    wire [31:0] D1 = T_reg - t1_scaled;
    wire [31:0] D2 = T_reg - t2_scaled;
    
    wire [31:0] P0 = v0 * D0;
    wire [31:0] P1 = v1 * D1;
    wire [31:0] P2 = v2 * D2;
    
    wire [31:0] max_P = (P0 > P1) ? ((P0 > P2) ? P0 : P2) : ((P1 > P2) ? P1 : P2);
    wire [31:0] min_P = (P0 < P1) ? ((P0 < P2) ? P0 : P2) : ((P1 < P2) ? P1 : P2);
    wire [31:0] diff = max_P - min_P;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            T_reg <= 32'd0;
            min_pack_reg <= 32'hFFFF_FFFF;
            counter <= 9'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= INIT;
                    end
                end
                
                INIT: begin
                    T_reg <= {max_t_comb, 8'd0};
                    min_pack_reg <= 32'hFFFF_FFFF;
                    counter <= 9'd0;
                    next_state <= LOOP;
                end
                
                LOOP: begin
                    if (diff < min_pack_reg) begin
                        min_pack_reg <= diff;
                    end
                    
                    T_reg <= T_reg + 32'd1;
                    counter <= counter + 9'd1;
                    
                    if (counter == STEPS - 9'd1) begin
                        next_state <= DONE_ST;
                    end else begin
                        next_state <= LOOP;
                    end
                end
                
                DONE_ST: begin
                    done <= 1'b1;
                    result <= min_pack_reg[15:0];
                    next_state <= IDLE;  // Return to IDLE after completion
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
endmodule