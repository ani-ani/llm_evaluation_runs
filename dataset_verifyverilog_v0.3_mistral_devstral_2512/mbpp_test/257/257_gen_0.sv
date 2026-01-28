module swap_numbers(
    input clk,
    input rst_n,
    input start,
    input [7:0] a,
    input [7:0] b,
    output reg [7:0] out_first,
    output reg [7:0] out_second,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] SWAP    = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            out_first <= 8'd0;
            out_second <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= SWAP;
                    end
                end
                
                SWAP: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Perform the swap operation
                    out_first <= b;
                    out_second <= a;
                    
                    // Exit conditions
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule