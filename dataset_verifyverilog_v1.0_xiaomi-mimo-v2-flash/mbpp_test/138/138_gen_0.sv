module sum_of_powers_check (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    output reg result,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    reg [1:0] state, next_state;
    reg [7:0] n_reg;
    
    // Combinatorial logic for result
    wire result_comb;
    assign result_comb = ~n[0]; // Even numbers have LSB = 0
    
    // State machine for sequential operation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            valid <= 1'b0;
            n_reg <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        n_reg <= n;
                        next_state <= CHECK;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                CHECK: begin
                    // Register the result
                    result <= ~n_reg[0];
                    valid <= 1'b1;
                    next_state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    // Stay in DONE for 1 cycle, then back to IDLE
                    next_state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule