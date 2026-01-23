module compare_one(
    input clk,
    input rst_n,
    input start,
    input [15:0] a,
    input [15:0] b,
    input a_is_string,
    input b_is_string,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] DONE = 2'd2;
    
    reg [1:0] state;
    reg [15:0] a_reg;
    reg [15:0] b_reg;
    reg [1:0] cycle_count;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            a_reg <= 16'd0;
            b_reg <= 16'd0;
            cycle_count <= 2'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPARE;
                        a_reg <= a;
                        b_reg <= b;
                        cycle_count <= 2'd0;
                    end
                end
                
                COMPARE: begin
                    cycle_count <= cycle_count + 2'd1;
                    
                    if (cycle_count == 2'd1) begin
                        // Perform comparison
                        if (a_reg > b_reg) begin
                            result <= a_reg;
                        end else if (b_reg > a_reg) begin
                            result <= b_reg;
                        end else begin
                            result <= 16'h8000;
                        end
                    end
                    
                    if (cycle_count == 2'd1) begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule